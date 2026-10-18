// Adding a word through the dialog must not throw after the dialog closes (the text
// controllers used to be disposed while the closing animation still drew the fields).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grammar/app/providers.dart';
import 'package:grammar/app/theme.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/user_db.dart';
import 'package:grammar/platform/tts.dart';
import 'package:grammar/ui/dictionary/entry_page.dart';
import 'package:grammar/ui/widgets/word_tap_text.dart';
import 'package:grammar/ui/vocab/edit_word_dialog.dart';
import 'package:grammar/ui/vocab/word_hint.dart';
import 'package:grammar/ui/widgets/type_to_search.dart';

void main() {
  final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
  final has = File('$dir/grammar.db').existsSync();
  late ContentDb db;
  late UserDb user;
  late Directory tmp;
  setUpAll(() {
    if (!has) return;
    db = ContentDb.open(dir);
    tmp = Directory.systemTemp.createTempSync('grammar_editword');
    user = UserDb.open('${tmp.path}/user.db');
  });
  tearDownAll(() {
    if (!has) return;
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  });

  testWidgets('new word: autofill from the dictionary, save, no exception after closing', (tester) async {
    late WidgetRef r;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentDbProvider.overrideWithValue(db), userDbProvider.overrideWithValue(user), ttsProvider.overrideWithValue(TtsService())],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Consumer(
            builder: (c, ref, _) {
              r = ref;
              return Scaffold(
                body: TextButton(onPressed: () => showEditWordDialog(c, ref), child: const Text('open')),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'wash');
    await tester.testTextInput.receiveAction(TextInputAction.done); // onEditingComplete -> autofill
    await tester.pump();
    expect((tester.widget(find.byType(TextFormField).at(1)) as TextFormField).controller!.text, isNotEmpty); // IPA filled
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(r.read(userWordsProvider).savedKeys, contains('wash'));
    expect(user.wordByKey('wash')?.meaning, isNotEmpty);
  }, skip: !has);

  testWidgets('F2 in a lesson: editor for the word under the mouse, pre-filled; saved word -> Sửa từ', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('lesson')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentDbProvider.overrideWithValue(db), userDbProvider.overrideWithValue(user), ttsProvider.overrideWithValue(TtsService())],
        child: MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: router,
          builder: (context, child) => TypeToSearch(router: router, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    WordHints.hovered.value = (word: 'abandon', context: 'They abandon the car.', source: 'reading:1');
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    expect(find.text('Từ mới'), findsOneWidget);
    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[0].controller!.text, 'abandon');
    expect(fields[1].controller!.text, isNotEmpty); // IPA from the dictionary
    expect(fields[2].controller!.text, isNotEmpty); // meaning from the dictionary
    await tester.enterText(find.byType(TextFormField).at(2), 'bỏ rơi_từ bỏ');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(user.wordByKey('abandon')!.meaning, 'bỏ rơi_từ bỏ');
    expect(user.wordByKey('abandon')!.context, 'They abandon the car.');

    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    expect(find.text('Sửa từ'), findsOneWidget);
    expect(tester.widgetList<TextFormField>(find.byType(TextFormField)).last.controller!.text, 'bỏ rơi_từ bỏ');
    WordHints.hovered.value = null;
    expect(tester.takeException(), isNull);
  }, skip: !has);

  testWidgets('own word missing from the dictionary: entry page shows it with its meaning', (tester) async {
    user.saveWord(headword: 'zorbling', meaning: 'từ tự đặt', ipa: 'zɔːblɪŋ');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentDbProvider.overrideWithValue(db), userDbProvider.overrideWithValue(user), ttsProvider.overrideWithValue(TtsService())],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: Consumer(builder: (c, ref, _) => EntryCard(result: ref.read(lookupProvider).lookup('zorbling'))),
          ),
        ),
      ),
    );
    expect(find.text('zorbling'), findsOneWidget);
    expect(find.text('từ tự đặt'), findsOneWidget);
    expect(find.text('[zɔːblɪŋ]'), findsOneWidget);
    expect(find.text('Không có trong từ điển.'), findsOneWidget);
  }, skip: !has);

  testWidgets('own phrase missing from the dictionary: entry page shows the phrase, not its first word', (tester) async {
    user.saveWord(headword: 'kick the zorb', meaning: 'cụm tự đặt');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentDbProvider.overrideWithValue(db), userDbProvider.overrideWithValue(user), ttsProvider.overrideWithValue(TtsService())],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const EntryPage(word: 'kick the zorb'),
        ),
      ),
    );
    expect(find.text('kick the zorb'), findsWidgets);
    expect(find.text('cụm tự đặt'), findsOneWidget);
    expect(find.text('Đã lưu · bỏ lưu'), findsOneWidget);
  }, skip: !has);

  testWidgets('reading: tapping a word of a saved phrase looks up the phrase with its own meaning', (tester) async {
    user.saveWord(headword: 'kick the zorb', meaning: 'cụm tự đặt');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentDbProvider.overrideWithValue(db), userDbProvider.overrideWithValue(user), ttsProvider.overrideWithValue(TtsService())],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: WordTapText('They kick the zorb today.')),
        ),
      ),
    );
    await tester.tapOnText(find.textRange.ofSubstring('the zorb'));
    await tester.pumpAndSettle();
    expect(find.text('cụm tự đặt'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\[')), findsNothing); // not the IPA of "kick"
  }, skip: !has);
}
