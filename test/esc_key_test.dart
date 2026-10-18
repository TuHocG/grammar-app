// Esc closes the top-most thing: a dialog first, then the page (back). Ties the global key
// handler to a real GoRouter.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grammar/ui/widgets/type_to_search.dart';

void main() {
  testWidgets('Esc pops a dialog, then the page, then nothing', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/a',
          builder: (_, _) => const Scaffold(body: Text('page a')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => TypeToSearch(router: router, child: child!),
        ),
      ),
    );
    router.push('/a');
    await tester.pumpAndSettle();
    expect(find.text('page a'), findsOneWidget);

    final ctx = tester.element(find.text('page a'));
    showDialog<void>(
      context: ctx,
      builder: (_) => const AlertDialog(content: Text('dlg')),
    );
    await tester.pumpAndSettle();
    expect(find.text('dlg'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('dlg'), findsNothing);
    expect(find.text('page a'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('page a'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // nothing to pop: no error
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
