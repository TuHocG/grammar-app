/// Text whose every word can be tapped to look it up; saved words are red and members of
/// their word families are underlined (docs/08 G3, G10). Phrase selection (G7) is done by
/// the page that hosts the text (e.g. ReadingPage wraps the article in a SelectionArea).
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/search_key.dart';
import '../dictionary/quick_def_sheet.dart';

final _tokenRe = RegExp(r"[A-Za-zÀ-ɏḀ-ỿ0-9][A-Za-zÀ-ɏḀ-ỿ0-9'’-]*|\s+|[^\sA-Za-zÀ-ɏḀ-ỿ0-9]+");
final _letterRe = RegExp(r'[A-Za-zÀ-ɏḀ-ỿ]');

/// Builds the spans of [text]: one tappable span per word, red when saved, underlined when
/// in a saved word's family. Recognizers are appended to [recognizers]; the caller owns them.
List<InlineSpan> wordSpans(
  BuildContext context,
  WidgetRef ref,
  String text, {
  required TextStyle base,
  required List<GestureRecognizer> recognizers,
  String? contextSentence,
  String? source,
}) {
  final saved = ref.watch(userWordsProvider).savedKeys;
  final family = ref.watch(familyKeysProvider);
  final g = context.g;
  final spans = <InlineSpan>[];
  for (final m in _tokenRe.allMatches(text)) {
    final tok = m.group(0)!;
    if (!_letterRe.hasMatch(tok)) {
      spans.add(TextSpan(text: tok, style: base));
      continue;
    }
    final key = searchKey(cleanToken(tok));
    var style = base;
    if (saved.contains(key)) {
      style = style.copyWith(color: g.savedWord, fontWeight: FontWeight.w600);
    } else if (family.contains(key)) {
      style = style.copyWith(decoration: TextDecoration.underline, decorationColor: g.fog, decorationThickness: 1);
    }
    final rec = TapGestureRecognizer()..onTap = () => showQuickDef(context, ref, tok, contextSentence: contextSentence ?? text, source: source);
    recognizers.add(rec);
    spans.add(TextSpan(text: tok, style: style, recognizer: rec));
  }
  return spans;
}

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
  final List<GestureRecognizer> _recognizers = [];

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
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final spans = wordSpans(context, ref, widget.text, base: base, recognizers: _recognizers, contextSentence: widget.context, source: widget.source);
    final rich = Text.rich(TextSpan(children: spans), textAlign: widget.textAlign);
    if (!widget.highlighted) return rich;
    return DecoratedBox(
      decoration: BoxDecoration(color: context.g.lilac, borderRadius: BorderRadius.circular(4)),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: rich),
    );
  }
}
