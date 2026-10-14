// Ngữ Pháp Của Bạn: "Lưu bài" on a lesson bookmarks it; the saved page lists only bookmarked
// lessons. Runs against content/grammar.db when it exists (skipped otherwise).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/app/providers.dart';
import 'package:grammar/app/theme.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/user_db.dart';
import 'package:grammar/data/user_db_more.dart';
import 'package:grammar/platform/tts.dart';
import 'package:grammar/ui/grammar/grammar_page.dart';

void main() {
  final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
  final has = File('$dir/grammar.db').existsSync();
  late ContentDb db;
  late UserDb user;
  late Directory tmp;

  setUpAll(() {
    if (!has) return;
    db = ContentDb.open(dir);
    tmp = Directory.systemTemp.createTempSync('grammar_marks');
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

  testWidgets('Lưu bài bookmarks the lesson; the saved page lists only it', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final lesson = db.grammarLessons().firstWhere((l) => !l.chapter);
    final other = db.grammarLessons().lastWhere((l) => !l.chapter);

    await tester.pumpWidget(wrap(GrammarLessonPage(ref: lesson.ref)));
    await tester.tap(find.text('Lưu bài'));
    await tester.pump();
    expect(find.text('Đã lưu'), findsOneWidget);
    expect(user.grammarMarks(), {lesson.ref});

    await tester.pumpWidget(wrap(const GrammarPage(savedOnly: true)));
    await tester.pump();
    expect(find.text(lesson.title), findsWidgets);
    expect(find.text(other.title), findsNothing);

    user.setGrammarMark(lesson.ref, false);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(wrap(const GrammarPage(savedOnly: true)));
    await tester.pump();
    expect(find.textContaining('Chưa lưu bài nào'), findsOneWidget);
  }, skip: !has);

  testWidgets('un-bookmarking the open lesson keeps Bài trước / Bài kế among the saved ones', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final lessons = db.grammarLessons().where((l) => !l.chapter).take(3).toList();
    for (final l in lessons) {
      user.setGrammarMark(l.ref, true);
    }
    addTearDown(() {
      for (final l in lessons) {
        user.setGrammarMark(l.ref, false);
      }
    });
    await tester.pumpWidget(wrap(GrammarLessonPage(ref: lessons[1].ref, saved: true)));
    await tester.tap(find.text('Đã lưu'));
    await tester.pump();
    expect(find.text('Lưu bài'), findsOneWidget);
    final prev = find.widgetWithText(OutlinedButton, lessons[0].title);
    final next = find.ancestor(of: find.text(lessons[2].title), matching: find.byType(OutlinedButton));
    expect(tester.widget<OutlinedButton>(prev).onPressed, isNotNull);
    expect(tester.widget<OutlinedButton>(next).onPressed, isNotNull);
  }, skip: !has);
}
