// Nghe viết: a wrong letter reads the sentence again once; more wrong letters, deleting
// them or moving the cursor do not restart it until the text is right and turns wrong again.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/app/providers.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/user_db.dart';
import 'package:grammar/platform/tts.dart';
import 'package:grammar/ui/readings/dictation_page.dart';

class CountingTts extends TtsService {
  final spoken = <String>[];
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}

void main() {
  final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
  final has = File('$dir/grammar.db').existsSync();

  testWidgets('wrong typing reads the sentence again once', (tester) async {
    final db = ContentDb.open(dir);
    final tmp = Directory.systemTemp.createTempSync('grammar_dict');
    final user = UserDb.open('${tmp.path}/user.db');
    final tts = CountingTts();
    addTearDown(() {
      db.close();
      user.close();
      tmp.deleteSync(recursive: true);
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [contentDbProvider.overrideWithValue(db), userDbProvider.overrideWithValue(user), ttsProvider.overrideWithValue(tts)],
      child: const MaterialApp(home: DictationPage(id: 4)),   // no recording here: TTS
    ));
    await tester.pumpAndSettle();
    expect(tts.spoken.length, 1);   // the sentence, on opening

    final field = find.byType(TextField);
    Future<void> type(String s) async {
      await tester.enterText(field, s);
      await tester.pumpAndSettle();
    }

    await type('zz');               // wrong: read again
    expect(tts.spoken.length, 2);
    await type('zzzz');             // more wrong letters
    await type('zzz');              // deleting
    await type('z');
    final ctl = tester.widget<TextField>(field).controller!;
    ctl.selection = const TextSelection.collapsed(offset: 0);   // moving the cursor
    await tester.pumpAndSettle();
    expect(tts.spoken.length, 2);

    await type('');                 // right again (empty prefix)…
    await type('q');                // …then wrong: read once more
    expect(tts.spoken.length, 3);
  }, skip: !has);
}
