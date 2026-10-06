/// What F2 should pre-fill in the "Từ của bạn" editor (docs/08 G11): the old app took the
/// word under the mouse ("rê vào từ rồi F2"). Here, in order: the phrase selected in a
/// reading, the word being looked up in an open dictionary sheet, the word under the mouse.
library;

import 'package:flutter/foundation.dart';

typedef WordHint = ({String word, String? context, String? source});

class WordHints {
  WordHints._();
  static final hovered = ValueNotifier<WordHint?>(null);
  static final selected = ValueNotifier<WordHint?>(null);
  static final lookedUp = ValueNotifier<WordHint?>(null);

  static WordHint? get current => selected.value ?? lookedUp.value ?? hovered.value;
}
