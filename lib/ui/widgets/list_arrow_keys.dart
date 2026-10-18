/// ↑ / ↓ in a search field step through the result list under it, so a keyboard user can
/// pick a row and press Enter (the field's own submit) without reaching for the mouse.
/// Used by Tra nhanh (`lookup_sheet.dart`) and the dictionary page.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ListArrowKeys extends StatelessWidget {
  final int count;

  /// Picked row; -1 = none.
  final int active;

  /// Row the first ↑ / ↓ lands on (the one Enter would open anyway).
  final int start;
  final ValueChanged<int> onActive;

  /// Put on the picked row so it can be scrolled into view.
  final GlobalKey activeKey;
  final Widget child;
  const ListArrowKeys({super.key, required this.count, required this.active, this.start = 0, required this.onActive, required this.activeKey, required this.child});

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final down = e.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!down && e.logicalKey != LogicalKeyboardKey.arrowUp) return KeyEventResult.ignored;
    if (count == 0) return KeyEventResult.ignored;
    final next = active < 0 ? start.clamp(0, count - 1) : (down ? active + 1 : active - 1).clamp(-1, count - 1);
    onActive(next);
    // The neighbouring row is always built (within the list's cache extent), so it can be scrolled to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = activeKey.currentContext;
      if (c == null) return;
      Scrollable.ensureVisible(
        c,
        duration: const Duration(milliseconds: 80),
        alignmentPolicy: down ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: _onKey, child: child);
}
