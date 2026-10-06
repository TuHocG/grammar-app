/// Text whose every word can be tapped to look it up (docs/08 G3, G10): every occurrence
/// of a saved word or phrase is red; words of the same family as a saved word (Word Forms
/// families, and inflected forms such as "kicked" for "kick") are underlined. Phrase
/// selection (G7) is done by the page that hosts the text (e.g. ReadingPage wraps the
/// article in a SelectionArea).
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/search_key.dart';
import '../dictionary/quick_def_sheet.dart';

/// Tokens: a bracketed phonetic group "[ˈbæksifɔ:m]" as one unit, then words (Latin,
/// Vietnamese, IPA letters U+0250–02AF and θ), whitespace, punctuation runs.
final _tokenRe = RegExp(r"\[[^\[\]\n]{1,48}\]|[A-Za-zÀ-ɏḀ-ỿɐ-ʯθ0-9][A-Za-zÀ-ɏḀ-ỿɐ-ʯθ0-9'’-]*|\s+|[^\sA-Za-zÀ-ɏḀ-ỿɐ-ʯθ0-9]+");
final _letterRe = RegExp(r'[A-Za-zÀ-ɏḀ-ỿɐ-ʯθ]');

/// Saved key of each token of [toks] (null = not part of a saved word/phrase) and where
/// each saved occurrence starts. Saved phrases ("come through") match whole word runs
/// separated by spaces only; the longest phrase wins.
({List<String?> keys, List<bool> starts}) _savedRuns(List<RegExpMatch> toks, Set<String> saved) {
  final keys = List<String?>.filled(toks.length, null);
  final starts = List<bool>.filled(toks.length, false);
  final wordKey = [
    for (final m in toks) _letterRe.hasMatch(m.group(0)!) ? searchKey(cleanToken(m.group(0)!)) : null,
  ];
  var maxWords = 1;
  for (final k in saved) {
    final n = ' '.allMatches(k).length + 1;
    if (n > maxWords) maxWords = n;
  }
  var i = 0;
  while (i < toks.length) {
    if (wordKey[i] == null) {
      i++;
      continue;
    }
    // Word token indexes of the run starting at i (only whitespace between words).
    final run = <int>[i];
    var j = i + 1;
    while (run.length < maxWords && j + 1 < toks.length && toks[j].group(0)!.trim().isEmpty && !toks[j].group(0)!.contains('\n') && wordKey[j + 1] != null) {
      run.add(j + 1);
      j += 2;
    }
    var matched = 0;
    String? key;
    for (var n = run.length; n >= 1; n--) {
      final k = [for (final t in run.take(n)) wordKey[t]].join(' ');
      if (saved.contains(k)) {
        matched = n;
        key = k;
        break;
      }
    }
    if (key == null) {
      i++;
      continue;
    }
    final end = run[matched - 1];
    for (var t = i; t <= end; t++) {
      keys[t] = key;
    }
    starts[i] = true;
    i = end + 1;
  }
  return (keys: keys, starts: starts);
}

/// Style of a saved word (red) and of a word of a saved word's family (underlined).
TextStyle savedStyle(BuildContext context, TextStyle base) =>
    base.copyWith(color: context.g.savedWord, fontWeight: FontWeight.w600);
TextStyle familyStyle(BuildContext context, TextStyle base) =>
    base.copyWith(decoration: TextDecoration.underline, decorationColor: context.g.savedWord, decorationThickness: 1.5);

/// True when [key] (or its base form: kicked → kick, came → come) is in [family].
bool inSavedFamily(String key, Set<String> family) =>
    family.contains(key) || baseFormCandidates(key).any(family.contains);

/// Builds the spans of [text]: one tappable span per word; saved words/phrases red, words
/// of their families underlined. Recognizers are appended to [recognizers]; the caller
/// owns them.
List<InlineSpan> wordSpans(
  BuildContext context,
  WidgetRef ref,
  String text, {
  required TextStyle base,
  required List<GestureRecognizer> recognizers,
  String? contextSentence,
  String? source,
  /// Shown when the dictionary has nothing for the tapped token: the sentence's own
  /// Vietnamese line (the "Phiên Âm Quốc Tế" readings keep the reading there: "[béc sì phòm]").
  String? fallbackVi,
}) {
  final saved = ref.watch(userWordsProvider).savedKeys;
  final family = ref.watch(familyKeysProvider);
  final toks = _tokenRe.allMatches(text).toList();
  final runs = _savedRuns(toks, saved);
  final spans = <InlineSpan>[];
  for (var i = 0; i < toks.length; i++) {
    final tok = toks[i].group(0)!;
    if (!_letterRe.hasMatch(tok)) {
      spans.add(TextSpan(text: tok, style: runs.keys[i] != null ? savedStyle(context, base) : base));
      continue;
    }
    final style = runs.keys[i] != null
        ? savedStyle(context, base)
        : inSavedFamily(searchKey(cleanToken(tok)), family)
            ? familyStyle(context, base)
            : base;
    final rec = TapGestureRecognizer()..onTap = () => showQuickDef(context, ref, tok, contextSentence: contextSentence ?? text, source: source, fallbackVi: fallbackVi);
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
