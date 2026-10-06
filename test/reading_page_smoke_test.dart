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
import 'package:grammar/data/reading_loader.dart';
import 'package:grammar/data/user_db.dart';
import 'package:grammar/platform/tts.dart';
import 'package:grammar/ui/dialogs/dialog_pages.dart';
import 'package:grammar/ui/home/home_page.dart';
import 'package:grammar/ui/pictures/picture_pages.dart';
import 'package:grammar/ui/readings/ipa_lesson_page.dart';
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

  testWidgets('IPA lesson: symbols reveal "Ðọc là", example words reveal their respelling', (tester) async {
    tester.view.physicalSize = const Size(1100, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const IpaLessonPage()));
    await tester.pump();
    expect(find.text('ʃ'), findsOneWidget);          // a symbol chip, not "î  ."
    await tester.scrollUntilVisible(find.text('ʃ'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('ʃ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sờ (uốn cong lưỡi)'), findsOneWidget);
    // Symbols whose line is not "Ðọc là:" (j, ":", "'") are chips too, in one Wrap.
    expect(find.text(':'), findsOneWidget);
    expect(find.text("'"), findsOneWidget);
    expect(find.text('j'), findsOneWidget);
    expect(find.text('Chạm một ký hiệu để xem cách đọc.'), findsOneWidget);
    // Chips are not stretched to the full width.
    expect(tester.getSize(find.ancestor(of: find.text('ʃ'), matching: find.byType(InkWell)).first).width, lessThan(120));
    await tester.scrollUntilVisible(find.text('fruticulum'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('fruticulum'));
    await tester.pumpAndSettle();
    expect(find.text('frù thí kìu lờm'), findsOneWidget);
    expect(find.text("[fru:'tikjuləm]"), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: !has);

  testWidgets('analysed unit: tap a word -> analysis card with quick meaning and lesson titles', (tester) async {
    tester.view.physicalSize = const Size(1100, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const ReadingPage(id: 365, fromAnalysis: true)));   // Unit 5
    await tester.pump();
    expect(find.text('Nghe toàn bài'), findsOneWidget);
    expect(find.text('Xếp từ'), findsOneWidget);
    final rich = find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('swallowed'));
    expect(rich, findsOneWidget);
    final rp = tester.renderObject<RenderParagraph>(rich);
    final plain = rp.text.toPlainText();
    expect(plain.contains('|'), isFalse);
    final idx = plain.indexOf('doctor');
    final caret = rp.getOffsetForCaret(TextPosition(offset: idx + 2), Rect.zero);
    await tester.tapAt(rp.localToGlobal(caret + const Offset(0, 12)));
    await tester.pumpAndSettle();
    expect(find.text('Chức năng'), findsOneWidget);
    expect(find.text('Lưu từ'), findsOneWidget);
    // Lesson links sit lower in the card's lazy list: scroll the sheet to them.
    await tester.scrollUntilVisible(find.textContaining('Simple Sentence'), 150, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('Simple Sentence'), findsOneWidget);
    expect(find.text('Bài 37'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: !has);

  testWidgets('Luyện Nói page: reading toolbar, topic nav, bookmark explains Ôn tập', (tester) async {
    tester.view.physicalSize = const Size(1100, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const DialogPage(id: 1)));
    await tester.pump();
    for (final t in ['Nghe toàn bài', 'Xếp từ', 'Đàm thoại', 'Nghe viết', 'Đổi ảnh', 'Ôn tập cả chủ đề']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('A:'), findsNWidgets(4));
    await tester.tap(find.byIcon(Icons.bookmark_border).first);
    await tester.pump();
    expect(find.textContaining('Đã chọn 1 cặp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: !has);

  testWidgets('Từ Vựng (Tranh): breadcrumb, left nav of all pictures, picture still fills the page', (tester) async {
    tester.view.physicalSize = const Size(1100, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const PictureTopicPage(id: 12)));
    await tester.pumpAndSettle();
    expect(find.text('Từ Vựng (Tranh)'), findsWidgets);
    expect(find.byType(TocRow), findsWidgets);
    expect(find.textContaining('Tranh kế'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(wrap(const PictureTopicsPage()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, skip: !has);

  test('a dialog opens as a reading for the practice pages (A1, B1, A2 …)', () {
    final c = ProviderContainer(overrides: [contentDbProvider.overrideWithValue(db), userDbProvider.overrideWithValue(user)]);
    addTearDown(c.dispose);
    final r = loadReadingFrom(c, dialogReadingBase + 1)!;
    expect(r.sentences.length, 8);
    expect(r.sentences[0].en, 'What do you buy?');
    expect(r.sentences[1].en, 'A bar of Chocolate.');
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
