// Smoke test: the reading page and the home page lay out without exceptions at a desktop size
// (uses dist/grammar.db when present).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/app/providers.dart';
import 'package:grammar/app/theme.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/user_db.dart';
import 'package:grammar/platform/tts.dart';
import 'package:grammar/ui/home/home_page.dart';
import 'package:grammar/ui/readings/reading_page.dart';

void main() {
  final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? r'D:\code\personal\grammar\dist';
  final has = File('$dir/grammar.db').existsSync();
  late ContentDb db;
  late UserDb user;
  late Directory tmp;

  setUpAll(() {
    if (!has) return;
    db = ContentDb.open(dir);
    tmp = Directory.systemTemp.createTempSync('grammar_smoke');
    user = UserDb.open('${tmp.path}/user.db');
  });
  tearDownAll(() {
    if (!has) return;
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  });

  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          contentDbProvider.overrideWithValue(db),
          userDbProvider.overrideWithValue(user),
          ttsProvider.overrideWithValue(TtsService()),
        ],
        child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
      );

  for (final (name, widget) in [('reading', const ReadingPage(id: 1)), ('home', const HomePage())]) {
    testWidgets('$name page lays out at 1100x720', (tester) async {
      tester.view.physicalSize = const Size(1100, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(widget));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);
    }, skip: !has);
  }
}
