/// Text whose every word can be tapped to look it up; saved words are red and members of
/// their word families are underlined (docs/08 G3, G10). Long-press selects a phrase for
/// a multi-word lookup (G7).
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/search_key.dart';
import '../dictionary/quick_def_sheet.dart';

class WordTapText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  /// Sentence shown as context when the user saves a word from this text.
  final String? context;
  final String? source;
  final bool highlighted;

  const WordTapText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.context,
    this.source,
    this.highlighted = false,
  });

  @override
  ConsumerState<WordTapText> createState() => _WordTapTextState();
}

class _WordTapTextState extends ConsumerState<WordTapText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final saved = ref.watch(userWordsProvider).savedKeys;
    final family = ref.watch(familyKeysProvider);
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final spans = <InlineSpan>[];
    final tokenRe = RegExp(r"[A-Za-zÀ-ɏḀ-ỿ0-9][A-Za-zÀ-ɏḀ-ỿ0-9'’-]*|\s+|[^\sA-Za-zÀ-ɏḀ-ỿ0-9]+");
    for (final m in tokenRe.allMatches(widget.text)) {
      final tok = m.group(0)!;
      final isWord = RegExp(r'[A-Za-zÀ-ɏḀ-ỿ]').hasMatch(tok);
      if (!isWord) {
        spans.add(TextSpan(text: tok, style: base));
        continue;
      }
      final key = searchKey(cleanToken(tok));
      TextStyle style = base;
      if (saved.contains(key)) {
        style = style.copyWith(color: Marks.savedWord, fontWeight: FontWeight.w600);
      } else if (family.contains(key)) {
        style = style.copyWith(decoration: TextDecoration.underline, decorationColor: Marks.savedWord);
      }
      final rec = TapGestureRecognizer()
        ..onTap = () => showQuickDef(context, ref, tok, contextSentence: widget.context ?? widget.text, source: widget.source);
      _recognizers.add(rec);
      spans.add(TextSpan(text: tok, style: style, recognizer: rec));
    }
    final rich = Text.rich(TextSpan(children: spans), textAlign: widget.textAlign);
    if (!widget.highlighted) return rich;
    return DecoratedBox(
      decoration: BoxDecoration(color: Marks.highlight.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: rich),
    );
  }
}
