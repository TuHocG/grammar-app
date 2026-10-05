import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/content_db.dart';
import 'data/user_db.dart';
import 'platform/tts.dart';
import 'ui/setup/data_dir_page.dart';
import 'ui/widgets/type_to_search.dart';

/// Development default; override with `--dart-define=GRAMMAR_DATA_DIR=...`.
const _envDataDir = String.fromEnvironment('GRAMMAR_DATA_DIR');

/// Key of the encrypted content database in release builds (`--dart-define=GRAMMAR_DB_KEY=...`,
/// build with `--obfuscate`). Empty in development, where the database is plain.
const _dbKey = String.fromEnvironment('GRAMMAR_DB_KEY');

late UserDb _userDb;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  _userDb = UserDb.open(p.join(support.path, 'user.db'));
  await _start();
}

Future<void> _start({String? error}) async {
  final dir = _userDb.setting('data_dir') ?? (_envDataDir.isNotEmpty ? _envDataDir : null);
  if (dir == null || !File(p.join(dir, 'grammar.db')).existsSync()) {
    runApp(MaterialApp(
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: DataDirPage(
        initial: dir ?? _envDataDir,
        error: error,
        onChosen: (d) {
          _userDb.setSetting('data_dir', d);
          _start();
        },
      ),
    ));
    return;
  }
  final ContentDb content;
  try {
    content = ContentDb.open(dir, key: _dbKey);
  } catch (e) {
    await _start(error: 'Không mở được grammar.db: $e');
    return;
  }
  final settings = _userDb.allSettings();
  final tts = TtsService();
  await tts.init(
    speed: int.tryParse(settings['tts_speed'] ?? '') ?? 4,
    voiceName: (settings['tts_voice'] ?? '').isEmpty ? null : settings['tts_voice'],
  );
  runApp(ProviderScope(
    overrides: [
      contentDbProvider.overrideWithValue(content),
      userDbProvider.overrideWithValue(_userDb),
      ttsProvider.overrideWithValue(tts),
    ],
    child: const GrammarApp(),
  ));
}

class GrammarApp extends ConsumerWidget {
  const GrammarApp({super.key});

  static final _router = buildRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'Grammar',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: s.themeMode,
      routerConfig: _router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(s.fontScale)),
        child: TypeToSearch(router: _router, child: child!),
      ),
    );
  }
}
