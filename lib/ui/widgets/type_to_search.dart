/// Desktop conveniences from the old app: typing a letter anywhere that is not a text
/// field opens the dictionary with that letter (docs/08 G2); Esc closes whatever is on
/// top — a sheet, a dialog, or the page itself (back), like the old app's Esc; F2 opens the
/// "Từ của bạn" editor for the selected phrase / looked-up word / word under the mouse
/// (docs/08 G11).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../vocab/edit_word_dialog.dart';
import '../vocab/word_hint.dart';

class TypeToSearch extends ConsumerWidget {
  final Widget child;
  final GoRouter router;
  const TypeToSearch({super.key, required this.child, required this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, e) {
        if (e is! KeyDownEvent) return KeyEventResult.ignored;
        if (e.logicalKey == LogicalKeyboardKey.f2) {
          // Not while typing (e.g. already in the editor).
          final f = FocusManager.instance.primaryFocus;
          if (f?.context?.widget is EditableText || _insideTextField(f)) return KeyEventResult.ignored;
          final nav = router.routerDelegate.navigatorKey.currentContext;
          if (nav == null) return KeyEventResult.ignored;
          final h = WordHints.current;
          openWordEditor(nav, ref, h?.word, contextSentence: h?.context, source: h?.source);
          return KeyEventResult.handled;
        }
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
