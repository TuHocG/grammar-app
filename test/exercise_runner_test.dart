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
