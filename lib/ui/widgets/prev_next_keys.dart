/// Back / Next from the keyboard on the practice pages (exercises, Luyện Nghe, Xếp từ,
/// Nghe viết, Đàm thoại): Alt+← / Alt+→ (Option on a Mac), also inside an answer box;
/// plain arrows are left alone (cursor, scrolling). The page's own keys
/// ([PrevNextKeys.bindings], e.g. Enter, Space) give way while Tab has put the focus on a
/// button or an option, so Enter / Space press that instead.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// True when the keyboard focus is in a text field (the learner is typing).
bool focusIsTyping() {
  final node = FocusManager.instance.primaryFocus;
  final ctx = node?.context;
  if (ctx == null) return false;
  if (ctx.widget is EditableText) return true;
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

class PrevNextKeys extends StatefulWidget {
  /// Null = nothing before / after (the key is left to others).
  final VoidCallback? onPrev, onNext;
  /// Page keys, active when the focus is on the page itself or in an answer box.
  final Map<SingleActivator, VoidCallback> bindings;
  /// False when the page autofocuses its own answer box (it would lose to this one).
  final bool autofocus;
  final Widget child;
  const PrevNextKeys({super.key, this.onPrev, this.onNext, this.bindings = const {}, this.autofocus = true, required this.child});

  @override
  State<PrevNextKeys> createState() => _PrevNextKeysState();
}

class _PrevNextKeysState extends State<PrevNextKeys> {
  final _node = FocusNode(debugLabel: 'PrevNextKeys');

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    _node.dispose();
    super.dispose();
  }

  /// A focused answer box that gets disabled (graded right) or removed leaves the focus on
  /// the page's scope, above this widget, and the keys stop working; take it back.
  void _onFocusChange() {
    if (!_fellToScope()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _fellToScope()) _node.requestFocus();
    });
  }

  bool _fellToScope() {
    final scope = _node.enclosingScope;
    return scope != null && FocusManager.instance.primaryFocus == scope;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    for (final b in widget.bindings.entries) {
      if (!b.key.accepts(e, HardwareKeyboard.instance)) continue;
      final onControl = FocusManager.instance.primaryFocus != _node && !focusIsTyping();
      if (onControl) return KeyEventResult.ignored;
      b.value();
      return KeyEventResult.handled;
    }
    final k = e.logicalKey;
    if (k != LogicalKeyboardKey.arrowLeft && k != LogicalKeyboardKey.arrowRight) return KeyEventResult.ignored;
    final kb = HardwareKeyboard.instance;
    if (!kb.isAltPressed || kb.isControlPressed || kb.isMetaPressed || kb.isShiftPressed) return KeyEventResult.ignored;
    final action = k == LogicalKeyboardKey.arrowLeft ? widget.onPrev : widget.onNext;
    if (action == null) return KeyEventResult.ignored;
    action();
    return KeyEventResult.handled;
  }

  /// Autofocused so the keys work before anything is clicked; not a Tab stop of its own.
  @override
  Widget build(BuildContext context) => Focus(focusNode: _node, autofocus: widget.autofocus, skipTraversal: true, onKeyEvent: _onKey, child: widget.child);
}
