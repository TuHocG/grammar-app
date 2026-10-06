// Smoke test: the reading page and the home page lay out without exceptions at a desktop size
// (uses dist/grammar.db when present).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets('reading page: tapping a word opens the quick definition, a sentence number opens its translation', (tester) async {
    tester.view.physicalSize = const Size(1100, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const ReadingPage(id: 4)));   // "2. Barking Dog."
    await tester.pump();
    // Sentence numbers are InkWells inside the article; tap the first one.
    final number = find.widgetWithText(InkWell, '1');
    expect(number, findsOneWidget);
    await tester.tap(number);
    await tester.pumpAndSettle();
    expect(find.text('Câu 1'), findsOneWidget);
    // Tapping inside the paragraph text (a word span) opens the quick-definition sheet,
    // even though the article sits in a SelectionArea.
    final para = find.byType(SelectionArea);
    expect(para, findsOneWidget);
    // The paragraph is the longest RichText in the article; its first line starts with
    // the 26 px sentence number, then the first word.
    final riches = find.descendant(of: para, matching: find.byType(RichText)).evaluate().toList()
      ..sort((a, b) => (b.widget as RichText).text.toPlainText().length.compareTo((a.widget as RichText).text.toPlainText().length));
    final rich = find.byWidget(riches.first.widget);
    final rp = tester.renderObject<RenderParagraph>(rich);
    final plain = rp.text.toPlainText();
    final idx = plain.indexOf('Bobby');
    expect(idx, greaterThanOrEqualTo(0));
    final caret = rp.getOffsetForCaret(TextPosition(offset: idx + 2), Rect.zero);
    // The sentence number sits inline: the first word is still on the first line.
    expect(caret.dy, lessThan(20));
    await tester.tapAt(rp.localToGlobal(caret + const Offset(0, 12)));
    await tester.pumpAndSettle();
    // The 24 px number box must not stretch its line: line pitch stays the passage's 33 px.
    final tops = rp.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: plain.length)).map((b) => b.top.roundToDouble()).toSet().toList()..sort();
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i] - tops[i - 1], lessThanOrEqualTo(34));
    }
    expect(find.text('Lưu từ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: !has);

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
