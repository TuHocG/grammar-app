// Word-order drill: words match with their case (the chips come from the sentence itself), and
// the answer box is sized for the whole sentence from the start, so the word pool under it stays
// put while words are placed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/app/providers.dart';
import 'package:grammar/app/theme.dart';
import 'package:grammar/platform/tts.dart';
import 'package:grammar/ui/widgets/scramble_board.dart';

void main() {
  Future<void> pumpBoard(WidgetTester tester, String sentence, {void Function(bool revealed)? onSolved}) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [ttsProvider.overrideWithValue(TtsService())],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ScrambleBoard(sentence: sentence, speakOnSolved: false, onSolved: onSolved),
          ),
        ),
      ),
    ));
  }

  Future<void> tapWord(WidgetTester tester, String w) async {
    await tester.tap(find.widgetWithText(ActionChip, w));
    await tester.pump();
  }

  // Words in the answer box (the hidden sizing copy sits outside the Positioned layer).
  List<String> placed(WidgetTester tester) => tester
      .widgetList<Chip>(find.descendant(of: find.byType(Positioned), matching: find.byType(Chip)))
      .map((c) => (c.label as Text).data!)
      .toList();

  testWidgets('the word pool does not move while the sentence is built', (tester) async {
    const sentence = 'The baby birds sat in the nest on a very cold winter morning.';
    await pumpBoard(tester, sentence);
    double poolTop() => tester.getTopLeft(find.byType(ActionChip).first).dy;
    final before = poolTop();
    for (final w in scrambleTokens(sentence)) {
      await tapWord(tester, w);
      expect(poolTop(), before, reason: 'after placing "$w"');
    }
  });

  testWidgets('words match with their case', (tester) async {
    bool? revealed;
    await pumpBoard(tester, 'The cat saw the dog.', onSolved: (r) => revealed = r);
    await tapWord(tester, 'the');
    expect(placed(tester), isEmpty, reason: 'lowercase "the" is not the first word');
    for (final w in ['The', 'cat', 'saw', 'the', 'dog']) {
      await tapWord(tester, w);
    }
    expect(placed(tester), ['The', 'cat', 'saw', 'the', 'dog']);
    expect(revealed, isFalse);
  });
}
