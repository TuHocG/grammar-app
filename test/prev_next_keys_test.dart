// Alt+← / Alt+→ move Back / Next on the practice pages, also from inside an answer box,
// and keep working once the focused box is gone or disabled.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/ui/widgets/prev_next_keys.dart';

class _Pager extends StatefulWidget {
  const _Pager();
  @override
  State<_Pager> createState() => _PagerState();
}

class _PagerState extends State<_Pager> {
  int pos = 0;
  @override
  Widget build(BuildContext context) => PrevNextKeys(
        onPrev: pos > 0 ? () => setState(() => pos--) : null,
        onNext: pos < 2 ? () => setState(() => pos++) : null,
        // Item 1 has an answer box (gone on the other items).
        child: Column(children: [Text('item $pos'), if (pos == 1) const TextField(autofocus: true)]),
      );
}

Future<void> altKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Alt+arrows page, inside an answer box too; plain arrows do not', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: _Pager())));
    await tester.pumpAndSettle();
    expect(find.text('item 0'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);   // plain arrow: not ours
    await tester.pumpAndSettle();
    expect(find.text('item 0'), findsOneWidget);

    await altKey(tester, LogicalKeyboardKey.arrowLeft);         // nothing before: no-op
    await altKey(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('item 1'), findsOneWidget);

    await tester.showKeyboard(find.byType(TextField));
    await altKey(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('item 2'), findsOneWidget);

    // The focused box went away with item 1; the keys still work.
    await altKey(tester, LogicalKeyboardKey.arrowLeft);
    expect(find.text('item 1'), findsOneWidget);
  });
  testWidgets('autofocus: false leaves the page\'s own answer box focused', (tester) async {
    final fn = FocusNode();
    addTearDown(fn.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PrevNextKeys(autofocus: false, onNext: () {}, child: TextField(focusNode: fn, autofocus: true))),
    ));
    await tester.pumpAndSettle();
    expect(fn.hasFocus, isTrue);
  });

  testWidgets('keys keep working after the focused box is disabled (graded right)', (tester) async {
    var next = 0;
    final enabled = ValueNotifier(true);
    final fn = FocusNode();
    addTearDown(enabled.dispose);
    addTearDown(fn.dispose);
    // Like ExerciseRunner: the blank takes the focus in the first frame, before the
    // wrapper's autofocus, so the wrapper is not in the focus history to fall back to.
    WidgetsBinding.instance.addPostFrameCallback((_) => fn.requestFocus());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PrevNextKeys(
          onNext: () => next++,
          child: ValueListenableBuilder<bool>(valueListenable: enabled, builder: (_, on, _) => TextField(focusNode: fn, enabled: on)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(fn.hasFocus, isTrue);
    enabled.value = false;
    await tester.pumpAndSettle();
    await altKey(tester, LogicalKeyboardKey.arrowRight);
    expect(next, 1);
  });
}
