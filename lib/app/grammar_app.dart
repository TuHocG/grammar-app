/// The app proper, once the databases are open: TTS, providers, router, theme.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content_db.dart';
import '../data/user_db.dart';
import '../platform/tts.dart';
import '../ui/widgets/type_to_search.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';

/// Initialises the voice from the user's settings and runs [GrammarApp] on [content] and [user].
Future<void> startApp({required ContentDb content, required UserDb user}) async {
  final settings = user.allSettings();
  final tts = TtsService();
  await tts.init(speed: int.tryParse(settings['tts_speed'] ?? '') ?? 4, voiceName: (settings['tts_voice'] ?? '').isEmpty ? null : settings['tts_voice']);
  runApp(ProviderScope(overrides: [contentDbProvider.overrideWithValue(content), userDbProvider.overrideWithValue(user), ttsProvider.overrideWithValue(tts)], child: const GrammarApp()));
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
