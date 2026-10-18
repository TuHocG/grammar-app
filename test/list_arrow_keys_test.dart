// ↑ / ↓ in the search field pick a row of the list under it, Enter opens the picked row:
// in Tra nhanh (the 🔍 sheet) and on the dictionary page that typing anywhere opens.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/app/providers.dart';
import 'package:grammar/app/theme.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/user_db.dart';
import 'package:grammar/platform/tts.dart';
import 'package:grammar/ui/dictionary/dictionary_page.dart';
import 'package:grammar/ui/dictionary/entry_page.dart';
import 'package:grammar/ui/dictionary/lookup_sheet.dart';

void main() {
  final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
  final has = File('$dir/grammar.db').existsSync();
  late ContentDb db;
  late UserDb user;
  late Directory tmp;
  setUpAll(() {
    if (!has) return;
    db = ContentDb.open(dir);
    tmp = Directory.systemTemp.createTempSync('grammar_arrowkeys');
    user = UserDb.open('${tmp.path}/user.db');
  });
  tearDownAll(() {
    if (!has) return;
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  });

  Widget app(Widget home) => ProviderScope(
    overrides: [contentDbProvider.overrideWithValue(db), userDbProvider.overrideWithValue(user), ttsProvider.overrideWithValue(TtsService())],
    child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
  );

  Color? rowColor(WidgetTester tester, String headword) => tester.widget<Material>(find.ancestor(of: find.text(headword), matching: find.byType(Material)).first).color;

  testWidgets('Tra nhanh: ↓ ↓ ↑ moves the highlight, Enter opens the picked word', (tester) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (c) => Scaffold(
            body: TextButton(onPressed: () => showLookupSheet(c), child: const Text('open')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'aban');
    await tester.pump(const Duration(milliseconds: 200));
    final hits = db.around('aban', before: 0, after: 40);
    final lilac = tester.element(find.byType(TextField)).g.lilac;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(rowColor(tester, hits[1].headword), lilac);
    expect(rowColor(tester, hits[0].headword), isNot(lilac));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(rowColor(tester, hits[0].headword), lilac);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final before = find.text(hits[1].headword).evaluate().length;
    await tester.testTextInput.receiveAction(TextInputAction.search); // Enter in the field
    await tester.pumpAndSettle();
    expect(find.text(hits[1].headword).evaluate().length, greaterThan(before)); // the quick definition shows it too
  });

  testWidgets('dictionary page: ↓ starts at the typed word, Enter opens the picked entry', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The test font's wide glyphs push long headwords past the list's 400 px; not what this tests.
    final onError = FlutterError.onError;
    FlutterError.onError = (d) => d.exceptionAsString().contains('RenderFlex overflowed') ? null : onError?.call(d);
    addTearDown(() => FlutterError.onError = onError);
    await tester.pumpWidget(app(const DictionaryPage(initialQuery: 'aban')));
    await tester.pumpAndSettle();
    final hits = db.around('aban', before: 3, after: 120);
    final first = hits.indexWhere((h) => h.key.startsWith('aban'));
    final lilac = tester.element(find.byType(TextField)).g.lilac;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(rowColor(tester, hits[first].headword), lilac);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(rowColor(tester, hits[first + 1].headword), lilac);

    expect(find.byType(EntryCard), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.search); // Enter in the field
    await tester.pumpAndSettle();
    expect(find.byType(EntryCard), findsOneWidget);
  });
}
