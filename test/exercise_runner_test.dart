// Grading rules of ExerciseRunner against real rows of dist/grammar.db (skipped if absent).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/app/providers.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/user_db.dart';
import 'package:grammar/platform/tts.dart';
import 'package:grammar/ui/exercises/exercise_runner.dart';

void main() {
  group('grammar drills (real DB)', () {
    final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? r'D:\code\personal\grammar\dist';
    final has = File('$dir/grammar.db').existsSync();
    test('drills belong to lessons by data.Muc position; type 3 is scramble', () {
      final db = ContentDb.open(dir);
      expect(db.exercisesForLessons([3]).length, 46);     // Chia Ðộng Từ To Be
      expect(db.exercisesForLessons([48]).length, 54);    // Passive Voice: 0 before the fix
      final simple = db.exercisesForLessons([37]);       // Câu Ðơn: its single record is a scramble drill
      expect(simple.length, 1);
      expect(simple.first.kind, 'scramble');
      expect(simple.first.text, startsWith('Lan is a pupil.'));
      expect(db.grammarLesson(48)!.drills, isTrue);
      expect(db.grammarLesson(37)!.drills, isTrue);
      expect(db.grammarLesson(2)!.drills, isFalse);        // Chia Ðộng Từ: empty record
      expect(db.raw.select('SELECT count(*) AS n FROM exercise WHERE menu IS NULL AND lesson_ref IS NULL').first['n'], 0);
      expect(db.raw.select("SELECT count(*) AS n FROM exercise WHERE kind = 'sentences'").first['n'], 0);
      db.close();
    }, skip: !has);
  });

  final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? r'D:\code\personal\grammar\dist';
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
        overrides: [
          contentDbProvider.overrideWithValue(db),
          userDbProvider.overrideWithValue(user),
          ttsProvider.overrideWithValue(TtsService()),
        ],
        child: MaterialApp(home: child),
      );

  testWidgets('fill: "an" is right, "a" is wrong, score shows 1/1', (tester) async {
    final ex = db.exercisesInRange(0, 1);   // "Do you usually eat {0} egg for breakfast?" -> an
    expect(ex.single.blanks.single.answer, 'an');
    await tester.pumpWidget(wrap(ExerciseRunner(title: 't', exercises: ex)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' AN ');
    await tester.tap(find.text('Chấm (Enter)'));
    await tester.pumpAndSettle();
    expect(find.text('Đúng 1 / 1'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
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
    final ex = db.exercisesInRange(2032, 2033);   // answer d = found
    expect(ex.single.answer, 'd');
    await tester.pumpWidget(wrap(ExerciseRunner(title: 't', exercises: ex)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('find'));
    await tester.pumpAndSettle();
    expect(find.text('Đúng 0 / 0'), findsOneWidget);   // not graded yet
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
}
