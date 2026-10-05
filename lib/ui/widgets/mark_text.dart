/// Renders the light Markdown used by grammar lessons and explanations (docs/05):
/// `**bold**`, `` `highlight` ``, `### heading`, `> formula`, ``` blocks (verb tables) ```,
/// while keeping every word tappable for the dictionary (docs/08 P2, G3).
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/search_key.dart';
import '../dictionary/quick_def_sheet.dart';

class MarkText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle? style;
  final String? source;
  /// Called for `` `n` `` numeric links (grammar lesson references) if any.
  final void Function(int ref)? onLessonRef;
  const MarkText(this.text, {super.key, this.style, this.source, this.onLessonRef});

  @override
  ConsumerState<MarkText> createState() => _MarkTextState();
}

class _MarkTextState extends ConsumerState<MarkText> {
  final List<GestureRecognizer> _recs = [];

  @override
  void dispose() {
    for (final r in _recs) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recs) {
      r.dispose();
    }
    _recs.clear();
    final theme = Theme.of(context);
    final base = widget.style ?? theme.textTheme.bodyLarge!;
    final saved = ref.watch(userWordsProvider).savedKeys;
    final lines = widget.text.replaceAll('\r\n', '\n').split('\n');
    final blocks = <Widget>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.trimLeft().startsWith('```')) {
        final buf = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          buf.add(lines[i]);
          i++;
        }
        i++;
        blocks.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(buf.join('\n'), style: base.copyWith(fontFamily: 'Consolas', fontFamilyFallback: const ['Courier New', 'monospace'], fontSize: (base.fontSize ?? 16) - 1)),
          ),
        ));
        continue;
      }
      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: 8));
        i++;
        continue;
      }
      TextStyle style = base;
      var content = line;
      EdgeInsets pad = EdgeInsets.zero;
      Color? bg;
      if (line.startsWith('### ')) {
        content = line.substring(4);
        style = theme.textTheme.titleMedium!.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700);
        pad = const EdgeInsets.only(top: 10, bottom: 2);
      } else if (line.startsWith('> ')) {
        content = line.substring(2);
        bg = theme.colorScheme.secondaryContainer;
        pad = const EdgeInsets.symmetric(vertical: 4);
      }
      final span = _inline(content, style, theme, saved);
      Widget w = Padding(padding: pad, child: Text.rich(span));
      if (bg != null) {
        w = Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
          child: Text.rich(span),
        );
      }
      blocks.add(w);
      i++;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  static final _markRe = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
  static final _wordRe = RegExp(r"[A-Za-zÀ-ɏḀ-ỿ][A-Za-zÀ-ɏḀ-ỿ'’-]*|[^A-Za-zÀ-ɏḀ-ỿ]+");

  TextSpan _inline(String text, TextStyle style, ThemeData theme, Set<String> saved) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _markRe.allMatches(text)) {
      if (m.start > last) spans.addAll(_words(text.substring(last, m.start), style, saved));
      if (m.group(1) != null) {
        spans.addAll(_words(m.group(1)!, style.copyWith(fontWeight: FontWeight.w700), saved));
      } else {
        final code = m.group(2)!;
        final n = int.tryParse(code.trim());
        if (n != null && widget.onLessonRef != null) {
          final rec = TapGestureRecognizer()..onTap = () => widget.onLessonRef!(n);
          _recs.add(rec);
          spans.add(TextSpan(text: ' $code ', style: style.copyWith(color: theme.colorScheme.primary, decoration: TextDecoration.underline), recognizer: rec));
        } else {
          spans.addAll(_words(code, style.copyWith(backgroundColor: theme.colorScheme.tertiaryContainer, fontWeight: FontWeight.w600), saved));
        }
      }
      last = m.end;
    }
    if (last < text.length) spans.addAll(_words(text.substring(last), style, saved));
    return TextSpan(children: spans);
  }

  List<InlineSpan> _words(String text, TextStyle style, Set<String> saved) {
    final out = <InlineSpan>[];
    for (final m in _wordRe.allMatches(text)) {
      final tok = m.group(0)!;
      final isWord = RegExp(r'[A-Za-z]').hasMatch(tok) && !RegExp(r'[À-ɏḀ-ỿ]').hasMatch(tok);
      if (!isWord) {
        out.add(TextSpan(text: tok, style: style));
        continue;
      }
      final key = searchKey(cleanToken(tok));
      final rec = TapGestureRecognizer()..onTap = () => showQuickDef(context, ref, tok, contextSentence: text.trim(), source: widget.source);
      _recs.add(rec);
      out.add(TextSpan(text: tok, style: saved.contains(key) ? style.copyWith(color: Marks.savedWord) : style, recognizer: rec));
    }
    return out;
  }
}
