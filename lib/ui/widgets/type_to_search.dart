/// Desktop conveniences from the old app: typing a letter anywhere that is not a text
/// field opens the dictionary with that letter (docs/08 G2); Esc closes whatever is on
/// top — a sheet, a dialog, or the page itself (back), like the old app's Esc.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class TypeToSearch extends StatelessWidget {
  final Widget child;
  final GoRouter router;
  const TypeToSearch({super.key, required this.child, required this.router});

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, e) {
        if (e is! KeyDownEvent) return KeyEventResult.ignored;
        if (e.logicalKey == LogicalKeyboardKey.escape) {
          if (!router.canPop()) return KeyEventResult.ignored;
          router.pop();
          return KeyEventResult.handled;
        }
        final ch = e.character;
        if (ch == null || ch.length != 1 || !RegExp(r'[A-Za-z]').hasMatch(ch)) return KeyEventResult.ignored;
        if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isAltPressed || HardwareKeyboard.instance.isMetaPressed) {
          return KeyEventResult.ignored;
        }
        final focused = FocusManager.instance.primaryFocus;
        if (focused?.context?.widget is EditableText || _insideTextField(focused)) return KeyEventResult.ignored;
        final loc = router.routerDelegate.currentConfiguration.uri.path;
        if (loc.startsWith('/dict')) return KeyEventResult.ignored;
        router.push('/dict?q=${Uri.encodeComponent(ch)}');
        return KeyEventResult.handled;
      },
      child: child,
    );
  }

  bool _insideTextField(FocusNode? node) {
    var ctx = node?.context;
    if (ctx == null) return false;
    var found = false;
    ctx.visitAncestorElements((el) {
      if (el.widget is EditableText || el.widget is TextField) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }
}
