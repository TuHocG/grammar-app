// Adding a word through the dialog must not throw after the dialog closes (the text
// controllers used to be disposed while the closing animation still drew the fields).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/app/providers.dart';
import 'package:grammar/app/theme.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/user_db.dart';
import 'package:grammar/platform/tts.dart';
import 'package:grammar/ui/vocab/edit_word_dialog.dart';

void main() {
  final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? r'D:\code\personal\grammar\dist';
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
    await tester.pumpWidget(ProviderScope(
      overrides: [contentDbProvider.overrideWithValue(db), userDbProvider.overrideWithValue(user), ttsProvider.overrideWithValue(TtsService())],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Consumer(builder: (c, ref, _) {
          r = ref;
          return Scaffold(body: TextButton(onPressed: () => showEditWordDialog(c, ref), child: const Text('open')));
        }),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'wash');
    await tester.testTextInput.receiveAction(TextInputAction.done);   // onEditingComplete -> autofill
    await tester.pump();
    expect((tester.widget(find.byType(TextFormField).at(1)) as TextFormField).controller!.text, isNotEmpty);   // IPA filled
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(r.read(userWordsProvider).savedKeys, contains('wash'));
    expect(user.wordByKey('wash')?.meaning, isNotEmpty);
  }, skip: !has);
}
