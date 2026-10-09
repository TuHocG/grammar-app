import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/config.dart';
import 'app/providers.dart';
import 'app/restart.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/content_db.dart';
import 'data/user_db.dart';
import 'platform/tts.dart';
import 'ui/setup/data_dir_page.dart';
import 'ui/widgets/type_to_search.dart';

/// Development default; override with `--dart-define=GRAMMAR_DATA_DIR=...`.
const _envDataDir = String.fromEnvironment('GRAMMAR_DATA_DIR');

/// Development fallback: the repo's `content/` folder (cwd is the repo root under `flutter run`),
/// once `python3 tool/content/pack.py` has built `content/grammar.db`.
String? _localDataDir() {
  final d = p.join(Directory.current.path, 'content');
  return File(p.join(d, 'grammar.db')).existsSync() ? d : null;
}


late UserDb _userDb;

/// The open lesson database; closed shortly after the bootstrap reopens another one.
ContentDb? _content;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  _userDb = UserDb.open(p.join(support.path, 'user.db'));
  restartApp = () => _start();
  await _start();
}

Future<void> _start({String? error}) async {
  final dir = _userDb.setting('data_dir') ?? (_envDataDir.isNotEmpty ? _envDataDir : null) ?? _localDataDir();
  if (error != null || dir == null || !File(p.join(dir, 'grammar.db')).existsSync()) {
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
  final previous = _content;
  if (previous != null) {
    // Pages of the old tree may still read it during the frame that swaps the app.
    Future.delayed(const Duration(seconds: 2), previous.close);
    _content = null;
  }
  final ContentDb content;
  try {
    content = ContentDb.open(dir, key: grammarDbKey);
  } catch (e) {
    await _start(error: 'Không mở được grammar.db: $e'
        '${grammarDbKey.isEmpty ? '\nNếu đây là grammar.db của bản phát hành (đã mã hoá), bản app này không có khoá để đọc — chọn thư mục content/ của repo.' : ''}');
    return;
  }
  if (content.schemaVersion > ContentDb.supportedSchema) {
    final v = content.schemaVersion;
    content.close();
    await _start(error: 'Dữ liệu nội dung dùng lược đồ $v, bản app này chỉ đọc được tới lược đồ ${ContentDb.supportedSchema}. Hãy cập nhật app.');
    return;
  }
  _content = content;
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
      title: 'Grammar 4.0',
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
