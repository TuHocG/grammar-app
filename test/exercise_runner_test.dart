// Grading rules of ExerciseRunner against real rows of dist/grammar.db (skipped if absent).
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/app/providers.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/models.dart';
import 'package:grammar/data/user_db.dart';
import 'package:grammar/platform/tts.dart';
import 'package:grammar/ui/exercises/exercise_runner.dart';
import 'package:grammar/ui/listening/listening_page.dart';
import 'package:grammar/ui/widgets/shell.dart';

void main() {
  group('grammar drills (real DB)', () {
    final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
    final has = File('$dir/grammar.db').existsSync();
    test('drills belong to lessons by data.Muc position; type 3 is scramble', () {
      final db = ContentDb.open(dir);
      expect(db.exercisesForLessons([3]).length, 46); // Chia Ðộng Từ To Be
      expect(db.exercisesForLessons([48]).length, 54); // Passive Voice: 0 before the fix
      final simple = db.exercisesForLessons([37]); // Câu Ðơn: its single record is a scramble drill
      expect(simple.length, 1);
      expect(simple.first.kind, 'scramble');
      expect(simple.first.text, startsWith('Lan is a pupil.'));
      expect(db.grammarLesson(48)!.drills, isTrue);
      expect(db.grammarLesson(37)!.drills, isTrue);
      expect(db.grammarLesson(2)!.drills, isFalse); // Chia Ðộng Từ: empty record
      expect(db.raw.select('SELECT count(*) AS n FROM exercise WHERE menu IS NULL AND lesson_ref IS NULL').first['n'], 0);
      expect(db.raw.select("SELECT count(*) AS n FROM exercise WHERE kind = 'sentences'").first['n'], 0);
      db.close();
    }, skip: !has);
  });

  final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
  final has = File('$dir/grammar.db').existsSync();
  late ContentDb db;
  late UserDb user;
  late Directory tmp;

  setUpAll(() {
    if (!has) return;
    db = ContentDb.open(dir);
    tmp = Directory.systemTemp.createTempSync('grammar_test');
    user = UserDb.open('${tmp.path}/user.db');
  });
  tearDownAll(() {
    if (!has) return;
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  });

  Widget wrap(Widget child) => ProviderScope(
    overrides: [contentDbProvider.overrideWithValue(db), userDbProvider.overrideWithValue(user), ttsProvider.overrideWithValue(TtsService())],
    child: MaterialApp(home: child),
  );

  testWidgets('fill: "an" is right, "a" is wrong, score shows 1/1', (tester) async {
    final ex = db.exercisesInRange(0, 1); // "Do you usually eat {0} egg for breakfast?" -> an
    expect(ex.single.blanks.single.answer, 'an');
    await tester.pumpWidget(wrap(ExerciseRunner(title: 't', exercises: ex)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' AN ');
    await tester.tap(find.text('Chấm (Enter)'));
    await tester.pumpAndSettle();
    expect(find.text('Đúng 1 / 1'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  }, skip: !has);

  testWidgets('fill on a phone: the keyboard action moves through the blanks, the last one grades', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final ex = [db.exercisesInRange(0, 2000).firstWhere((x) => x.kind == 'fill' && x.blanks.length >= 2)];
    final n = ex.single.blanks.length;
    await tester.pumpWidget(wrap(ExerciseRunner(title: 't', exercises: ex)));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(n));
    await tester.showKeyboard(fields.first);
    for (var k = 0; k < n - 1; k++) {
      expect(tester.testTextInput.setClientArgs?['inputAction'], 'TextInputAction.next');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(find.text('Đúng 0 / 1'), findsNothing); // not graded yet
    }
    expect(tester.testTextInput.setClientArgs?['inputAction'], 'TextInputAction.done');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Đúng 0 / 1'), findsOneWidget); // empty blanks: graded, wrong
    debugDefaultTargetPlatformOverride = null;
  }, skip: !has);

  testWidgets('fill on a phone: a question with more blanks after a one-blank one offers Next at once', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final all = db.exercisesInRange(0, 2000);
    final ex = [all.firstWhere((x) => x.kind == 'fill' && x.blanks.length == 1), all.firstWhere((x) => x.kind == 'fill' && x.blanks.length >= 2)];
    await tester.pumpWidget(wrap(ExerciseRunner(title: 't', exercises: ex)));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    expect(tester.testTextInput.setClientArgs?['inputAction'], 'TextInputAction.done');
    // Grade and move on with the buttons, the keyboard staying up on the reused field.
    await tester.tap(find.text('Chấm (Enter)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(ex[1].blanks.length));
    expect(tester.testTextInput.setClientArgs?['inputAction'], 'TextInputAction.next');
    debugDefaultTargetPlatformOverride = null;
  }, skip: !has);

  testWidgets('fill: wrong answer is marked and scores 0', (tester) async {
    final ex = db.exercisesInRange(0, 1);
    await tester.pumpWidget(wrap(ExerciseRunner(title: 't', exercises: ex)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a');
    await tester.tap(find.text('Chấm (Enter)'));
    await tester.pumpAndSettle();
    expect(find.text('Đúng 0 / 1'), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  }, skip: !has);

  testWidgets('choice: wrong pick first then right = graded but no point', (tester) async {
    final ex = db.exercisesInRange(2032, 2033); // answer d = found
    expect(ex.single.answer, 'd');
    await tester.pumpWidget(wrap(ExerciseRunner(title: 't', exercises: ex)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('find'));
    await tester.pumpAndSettle();
    expect(find.text('Đúng 0 / 0'), findsOneWidget); // not graded yet
    await tester.tap(find.text('found'));
    await tester.pumpAndSettle();
    expect(find.text('Đúng 0 / 1'), findsOneWidget);
  }, skip: !has);

  testWidgets('choice: right pick first scores', (tester) async {
    final ex = db.exercisesInRange(2032, 2033);
    await tester.pumpWidget(wrap(ExerciseRunner(title: 't', exercises: ex)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('found'));
    await tester.pumpAndSettle();
    expect(find.text('Đúng 1 / 1'), findsOneWidget);
  }, skip: !has);

  test('menus, groups of 25, Word Forms root ranges', () {
    final menus = db.exerciseMenus();
    expect(menus.length, 9);
    expect(menus[0].count, 203);
    expect((menus[0].count / 25).ceil(), 9);
    final roots = db.wordformRoots();
    expect(roots.length, 3901);
    final abandon = roots.first;
    final items = db.exercisesInRange(menus[8].start + abandon.start - 1, menus[8].start + abandon.start - 1 + abandon.count);
    expect(items.length, abandon.count);
    expect(items.every((e) => e.blanks.any((b) => b.answer.toLowerCase().startsWith('abandon'))), isTrue);
  }, skip: !has);

  /// A full group (25, so the map has several rows of numbers) whose first item is a fill
  /// exercise with three blanks or more.
  List<Exercise> manyBlanks() {
    for (var i = 0; i < 3000; i++) {
      final e = db.exercisesInRange(i, i + 1);
      if (e.isNotEmpty && e.single.kind == 'fill' && e.single.blanks.length >= 3) return db.exercisesInRange(i, i + 25);
    }
    throw StateError('no fill exercise with three blanks');
  }

  testWidgets('wide: Tab goes blank to blank, through the buttons, then the question map', (tester) async {
    // Just wide enough for the side map: its second row of numbers sits beside the blanks,
    // where the old reading-order Tab went from the first blank.
    tester.view.physicalSize = const Size(920, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(ExerciseRunner(title: 't', exercises: manyBlanks())));
    await tester.pumpAndSettle();
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(fields[1].focusNode!.hasFocus, isTrue);
    final order = await tabOrder(tester, {'next': find.text('Next'), 'dot': find.byType(LetterDot)});
    expect(order.indexOf('next'), greaterThanOrEqualTo(0));
    expect(order.indexOf('dot'), greaterThan(order.indexOf('next')));
  }, skip: !has);

  testWidgets('narrow: the question map is shown below the question', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(ExerciseRunner(title: 'map title', exercises: manyBlanks())));
    await tester.pumpAndSettle();
    expect(find.text('chưa làm', skipOffstage: false), findsOneWidget);
  }, skip: !has);

  testWidgets('Luyện Nghe, wide: Tab goes through the question and its buttons before the map', (tester) async {
    tester.view.physicalSize = const Size(920, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const ListeningUnitPage(unit: 1)));
    await tester.pumpAndSettle();
    final order = await tabOrder(tester, {'listen': find.text('Nghe lại'), 'next': find.text('Next'), 'dot': find.byType(LetterDot).at(4)});
    expect(order, ['listen', 'next', 'dot']);
  }, skip: !has);

  String counter(WidgetTester tester) => find.textContaining(RegExp(r'Câu \d+ /'), findRichText: true).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).single;

  testWidgets('Tab to Next, Enter: moves on instead of grading', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(ExerciseRunner(title: 't', exercises: db.exercisesInRange(0, 5))));
    await tester.pumpAndSettle();
    await tabTo(tester, find.text('Next'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(counter(tester), 'Câu 2 / 5');
    expect(find.text('Đúng 0 / 0'), findsOneWidget);
  }, skip: !has);

  testWidgets('Luyện Nghe: Space / Enter press the option or button Tab is on', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const ListeningUnitPage(unit: 1)));
    await tester.pumpAndSettle();
    await tabTo(tester, find.byType(LetterDot).first); // option a
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    // Picked (options are shuffled, so a may be right ✓ or wrong ✗), not "Nghe lại".
    expect(find.byIcon(Icons.check).evaluate().length + find.byIcon(Icons.close).evaluate().length, 1);
    await tabTo(tester, find.text('Next'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(counter(tester), startsWith('Câu 2 /'));
  }, skip: !has);

  testWidgets('arrow keys in a blank: ↑ / ↓ jump to its start / end, no caret assertion', (tester) async {
    await tester.pumpWidget(wrap(ExerciseRunner(title: 't', exercises: db.exercisesInRange(0, 5))));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'abc');
    await tester.pump();
    final ctl = tester.widget<TextField>(field).controller!;
    for (final (key, offset) in [
      (LogicalKeyboardKey.arrowUp, 0),
      (LogicalKeyboardKey.arrowRight, 1),
      (LogicalKeyboardKey.arrowDown, 3),
      (LogicalKeyboardKey.arrowLeft, 2),
      (LogicalKeyboardKey.arrowUp, 0),
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(ctl.selection.baseOffset, offset, reason: '$key');
    }
    expect(tester.takeException(), isNull);
  }, skip: !has);
}

/// Presses Tab up to [max] times and returns the labels of [targets] in the order the
/// focus first lands inside them.
Future<List<String>> tabOrder(WidgetTester tester, Map<String, Finder> targets, {int max = 30}) async {
  final out = <String>[];
  for (var i = 0; i < max; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final ctx = FocusManager.instance.primaryFocus?.context as Element?;
    if (ctx == null) continue;
    final under = <Element>{};
    void walk(Element e) {
      under.add(e);
      e.visitChildElements(walk);
    }

    walk(ctx);
    for (final t in targets.entries) {
      if (!out.contains(t.key) && t.value.evaluate().any(under.contains)) out.add(t.key);
    }
  }
  return out;
}

/// Presses Tab until the focus is inside [target].
Future<void> tabTo(WidgetTester tester, Finder target, {int max = 30}) async {
  for (var i = 0; i < max; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final ctx = FocusManager.instance.primaryFocus?.context as Element?;
    if (ctx == null) continue;
    final under = <Element>{};
    void walk(Element e) {
      under.add(e);
      e.visitChildElements(walk);
    }

    walk(ctx);
    if (target.evaluate().any(under.contains)) return;
  }
  fail('Tab never reached $target');
}
