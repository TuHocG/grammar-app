/// ExerciseRunner (docs/08 E2–E10): one page that runs a list of exercises of the four kinds
/// with the old app's rules: fill (lower-case trimmed compare, all alternatives accepted,
/// empty answer accepts an empty blank), choice (no shuffle; a wrong pick first = no point),
/// error (pick the wrong part), sentences (display only). After grading: the right answer in
/// violet, the wrong pick in gray and struck through, the other options faded (as the old app
/// faded wrong lines), explanation per blank/option with grammar links, translation, score;
/// at the end a result card. Wide screens show a question map on the right.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/models.dart';
import '../grammar/grammar_page.dart';
import '../widgets/mark_text.dart';
import '../widgets/prev_next_keys.dart';
import '../widgets/question_layout.dart';
import '../dictionary/quick_def_sheet.dart';
import '../widgets/scramble_board.dart';
import '../widgets/shell.dart';
import '../widgets/word_tap_text.dart';

class ExerciseRunner extends ConsumerStatefulWidget {
  final String title;
  final List<Exercise> exercises;

  /// Titles come from the "lesson" set when run from a grammar lesson, else the "menu" set.
  final bool lessonContext;

  /// Called when the learner finishes the list; return true to close.
  final VoidCallback? onNextGroup;
  final String? progressKey;

  /// Breadcrumb shown above the title; the title itself is the last crumb.
  final List<Crumb> crumbs;
  const ExerciseRunner({super.key, required this.title, required this.exercises, this.lessonContext = false, this.onNextGroup, this.progressKey, this.crumbs = const [Crumb('Bài Tập', '/')]});

  @override
  ConsumerState<ExerciseRunner> createState() => _ExerciseRunnerState();
}

class _Result {
  bool graded = false;
  bool correct = false;
  bool lostPoint = false; // choice: wrong pick before the right one
  int? picked; // choice/error
  List<bool> blankOk = const [];
}

class _ExerciseRunnerState extends ConsumerState<ExerciseRunner> {
  int _pos = 0;

  /// Items actually run: a scramble record ("_"-separated sentences) becomes one item per
  /// sentence, so the map, the score and Next work per sentence.
  late final List<Exercise> _items = _expand(widget.exercises);

  static List<Exercise> _expand(List<Exercise> src) {
    final out = <Exercise>[];
    for (final e in src) {
      if (e.kind != 'scramble') {
        out.add(e);
        continue;
      }
      final lines = e.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      // The translation record lists the sentences the same way, separated by '_'.
      final vis = (e.vi ?? '').split('_').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
      for (var k = 0; k < lines.length; k++) {
        out.add(
          Exercise(
            id: e.id * 1000 + k,
            menu: e.menu,
            lessonRef: e.lessonRef,
            g: e.g,
            kind: e.kind,
            tt: e.tt,
            text: lines[k].trim(),
            blanks: e.blanks,
            given: e.given,
            choices: e.choices,
            answer: e.answer,
            vi: k < vis.length ? vis[k] : null,
            expl: e.expl,
            refs: e.refs,
          ),
        );
      }
    }
    return out;
  }

  late final List<_Result> _res = List.generate(_items.length, (_) => _Result());
  final Map<int, List<TextEditingController>> _ctls = {};
  final Map<int, List<FocusNode>> _focus = {};
  bool _showVi = false;
  bool _finished = false;

  Exercise get _ex => _items[_pos];
  _Result get _r => _res[_pos];
  int get _score => _res.where((r) => r.graded && r.correct).length;
  int get _done => _res.where((r) => r.graded).length;

  List<TextEditingController> _controllers(Exercise e) => _ctls.putIfAbsent(e.id, () => List.generate(e.blanks.length, (_) => TextEditingController()));

  List<FocusNode> _focusNodes(Exercise e) => _focus.putIfAbsent(e.id, () => List.generate(e.blanks.length, (_) => FocusNode()));

  /// Puts the cursor in the first blank still to answer, so the learner can type right away
  /// after moving to another item.
  void _focusBlank() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _finished || _items.isEmpty || _ex.kind != 'fill') return;
      final e = _ex;
      final nodes = _focusNodes(e);
      for (var b = 0; b < nodes.length; b++) {
        final ok = _r.graded && b < _r.blankOk.length && _r.blankOk[b];
        if (!ok) {
          nodes[b].requestFocus();
          return;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _focusBlank();
  }

  @override
  void dispose() {
    for (final l in _ctls.values) {
      for (final c in l) {
        c.dispose();
      }
    }
    for (final l in _focus.values) {
      for (final f in l) {
        f.dispose();
      }
    }
    super.dispose();
  }

  // ---- grading ---------------------------------------------------------------------

  static String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  void _gradeFill() {
    final e = _ex;
    final ctls = _controllers(e);
    final ok = <bool>[];
    for (var i = 0; i < e.blanks.length; i++) {
      final typed = _norm(ctls[i].text);
      final acc = e.blanks[i].accepted.map(_norm).toList();
      ok.add(acc.contains(typed) || (acc.every((a) => a.isEmpty) && typed.isEmpty));
    }
    setState(() {
      _r.graded = true;
      _r.blankOk = ok;
      _r.correct = ok.every((x) => x);
    });
    _save();
  }

  void _pick(int i) {
    final e = _ex;
    if (_r.graded) return;
    setState(() {
      _r.picked = i;
      if (i == e.answerIndex) {
        _r.graded = true;
        _r.correct = !_r.lostPoint;
      } else {
        _r.lostPoint = true; // the old app: wrong first, right later = no point
      }
    });
    if (_r.graded) _save();
  }

  void _save() {
    if (widget.progressKey != null) {
      ref.read(userDbProvider).setProgress('exercise', widget.progressKey!, '{"pos":$_pos,"score":$_score,"done":$_done}');
    }
  }

  void _go(int pos) {
    if (pos < 0 || pos >= _items.length) return;
    setState(() {
      _pos = pos;
      _showVi = false;
      _finished = false;
    });
    _focusBlank();
  }

  void _next() {
    if (_pos < _items.length - 1) {
      _go(_pos + 1);
    } else {
      setState(() => _finished = true);
    }
  }

  // ---- UI ---------------------------------------------------------------------------

  List<Crumb> get _crumbs => [...widget.crumbs, Crumb(widget.title)];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.g;
    if (_items.isEmpty) {
      return Scaffold(
        appBar: GrammarAppBar(crumbs: _crumbs),
        body: const EmptyNote('Không có bài tập.'),
      );
    }
    if (_finished) return _resultPage(theme);
    final e = _ex;
    final db = ref.read(contentDbProvider);
    final heading = e.tt == null ? null : db.exerciseTitle(e.tt!, lessonContext: widget.lessonContext);
    final wide = context.isWide;
    final n = _items.length;

    final question = Surface(
      padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 20, vertical: wide ? 32 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(heading?.replaceAll(r'\', ' / ') ?? _defaultHeading(e.kind)),
          if (e.given.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Từ cho trước:', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)),
                  for (final w in e.given)
                    Chip(
                      label: Text(w, style: ReadingStyles.line(context).copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          switch (e.kind) {
            'fill' => _fillBody(e, theme),
            'choice' => _choiceBody(e, theme),
            'error' => _errorBody(e, theme),
            'scramble' => _scrambleBody(e, theme),
            _ => _sentencesBody(e, theme),
          },
          if (_showVi && e.vi != null && e.vi!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.translate, size: 16, color: g.slate),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.vi!, style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
                  ),
                ],
              ),
            ),
          if (_r.graded && (e.expl.isNotEmpty || e.kind == 'fill')) ...[const SizedBox(height: 20), _explanation(e, theme)],
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(onPressed: _pos > 0 ? () => _go(_pos - 1) : null, icon: const Icon(Icons.chevron_left, size: 18), label: const Text('Back')),
              // Same row for every kind: fill adds "Chấm" before grading; Next is always there.
              if (e.kind == 'fill' && !_r.graded) FilledButton.icon(onPressed: _gradeFill, icon: const Icon(Icons.check, size: 18), label: const Text('Chấm (Enter)')),
              FilledButton(
                style: e.kind == 'fill' && !_r.graded ? FilledButton.styleFrom(backgroundColor: theme.colorScheme.secondaryContainer, foregroundColor: theme.colorScheme.onSecondaryContainer) : null,
                onPressed: _next,
                child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_pos == n - 1 ? 'Kết thúc' : 'Next'), const SizedBox(width: 4), const Icon(Icons.chevron_right, size: 18)]),
              ),
              if (e.vi != null && e.vi!.isNotEmpty)
                OutlinedButton.icon(onPressed: () => setState(() => _showVi = !_showVi), icon: const Icon(Icons.translate, size: 16), label: Text(_showVi ? 'Ẩn dịch' : 'Dịch')),
              if (_r.graded && e.kind == 'fill')
                OutlinedButton.icon(
                  onPressed: () {
                    final ctls = _controllers(e);
                    for (var i = 0; i < e.blanks.length; i++) {
                      ctls[i].text = e.blanks[i].answer;
                    }
                    setState(() {});
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Điền đáp án'),
                ),
              if (e.kind == 'choice' && !_r.graded) Text('Chọn sai lần đầu = không tính điểm', style: theme.textTheme.bodySmall?.copyWith(color: g.fog)),
            ],
          ),
        ],
      ),
    );

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: (_pos + 1) / n),
              ),
            ),
            const SizedBox(width: 16),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Câu ',
                    style: theme.textTheme.bodyMedium?.copyWith(color: g.slate),
                  ),
                  TextSpan(text: '${_pos + 1}', style: theme.textTheme.titleSmall),
                  TextSpan(
                    text: ' / $n',
                    style: theme.textTheme.bodyMedium?.copyWith(color: g.slate),
                  ),
                ],
              ),
            ),
            // The mark's slot is always there so grading doesn't shrink the bar.
            const SizedBox(width: 12),
            SizedBox.square(dimension: 20, child: _r.graded ? Icon(_r.correct ? Icons.check_circle : Icons.cancel, size: 20, color: _r.correct ? g.iris : g.slate) : null),
          ],
        ),
        const SizedBox(height: 16),
        question,
      ],
    );

    final map = Surface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.title, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              Text('$n câu', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < n; i++) _dot(i, g, theme)]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [_legend(g.iris, g.iris, 'đúng', theme, g), _legend(Colors.transparent, g.slate, 'sai', theme, g), _legend(Colors.transparent, g.border, 'chưa làm', theme, g)],
          ),
          if (widget.onNextGroup != null) ...[const Divider(height: 24), TextButton(onPressed: widget.onNextGroup, child: const Text('Bài Tập kế →'))],
        ],
      ),
    );

    return Scaffold(
      appBar: GrammarAppBar(
        crumbs: _crumbs,
        helpSlug: 'bai-tap',
        actions: [Text('Đúng $_score / $_done', style: theme.textTheme.titleSmall)],
      ),
      body: PrevNextKeys(
        onPrev: _pos > 0 ? () => _go(_pos - 1) : null,
        onNext: _next,
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () {
            if (e.kind == 'fill' && !_r.graded) {
              _gradeFill();
            } else if (_r.graded || e.kind == 'sentences' || e.kind == 'text') {
              _next();
            }
          },
        },
        child: RailListView(
          children: [QuestionWithMap(question: main, map: map, wide: wide)],
        ),
      ),
    );
  }

  static String _defaultHeading(String kind) => switch (kind) {
    'choice' => 'Hãy chọn câu đúng',
    'error' => 'Chọn chỗ sai',
    'fill' => 'Điền vào chỗ trống',
    'scramble' => 'Xếp từ thành câu',
    _ => 'Đọc và tra từ',
  };

  Widget _dot(int i, GrammarColors g, ThemeData theme) {
    final r = _res[i];
    final cur = i == _pos;
    Color fill = Colors.transparent, border = g.border, color = g.slate;
    if (r.graded && r.correct) {
      fill = g.iris;
      border = g.iris;
      color = theme.colorScheme.onPrimary;
    } else if (r.graded) {
      border = g.slate;
    }
    if (cur) {
      border = g.iris;
      if (!r.graded) color = g.iris;
    }
    return InkWell(
      onTap: () => _go(i),
      customBorder: const CircleBorder(),
      child: Container(
        decoration: cur
            ? BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: g.lilac, spreadRadius: 3)],
              )
            : null,
        child: LetterDot('${i + 1}', size: 28, fill: fill, border: border, color: color),
      ),
    );
  }

  Widget _legend(Color fill, Color border, String label, ThemeData theme, GrammarColors g) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: border),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: theme.textTheme.bodySmall),
    ],
  );

  // ---- bodies ----------------------------------------------------------------------

  Widget _fillBody(Exercise e, ThemeData theme) {
    final g = context.g;
    final ctls = _controllers(e);
    final nodes = _focusNodes(e);
    final parts = e.text.split(RegExp(r'\{\d+\}'));
    final idxs = RegExp(r'\{(\d+)\}').allMatches(e.text).map((m) => int.parse(m.group(1)!)).toList();
    final spans = <InlineSpan>[];
    final style = ReadingStyles.prompt(context);
    bool? okAt(int b) => _r.graded && b < _r.blankOk.length ? _r.blankOk[b] : null;
    // On a phone keyboard the action key goes to the next open blank, like a form; only
    // the last one grades. Desktop keeps Enter = Chấm in every blank, as the old app did.
    final mobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    final open = [
      for (final b in idxs)
        if (b < e.blanks.length && okAt(b) != true) b,
    ];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: WordTapText(parts[i], style: style, source: 'exercise:${e.id}'),
          ),
        );
      }
      if (i < idxs.length && idxs[i] < e.blanks.length) {
        final b = idxs[i];
        final ok = okAt(b);
        final at = open.indexOf(b);
        final next = mobile && at >= 0 && at < open.length - 1 ? nodes[open[at + 1]] : null;
        // Wide enough for the longest accepted answer (plus one letter of slack), never
        // narrower than 7 letters; the underscore count `n` says nothing about length.
        final fs = style.fontSize ?? 20;
        final longest = e.blanks[b].accepted.fold(0, (m, a) => max(m, a.length));
        final width = ((max(7, longest + 1)) * fs * 0.6 + 16 + 24).clamp(120.0, 360.0);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: SizedBox(
              width: width,
              child: Shortcuts(
                shortcuts: _blankVerticalKeys,
                child: TextField(
                  // A fresh field per question: a reused one keeps the keyboard it opened
                  // with, so Next / Done would not follow the new question's blanks.
                  key: ValueKey((e.id, b)),
                  controller: ctls[b],
                  focusNode: nodes[b],
                  enabled: !_r.graded || !(ok ?? false),
                  style: style.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ok == null ? g.iris : (ok ? g.iris : g.slate),
                    decoration: ok == false ? TextDecoration.lineThrough : null,
                    decorationColor: g.slate,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    filled: true,
                    fillColor: ok == null ? g.canvas : (ok ? g.lilac : g.canvas),
                    suffixIcon: ok == null ? null : Icon(ok ? Icons.check : Icons.close, size: 16, color: ok ? g.iris : g.slate),
                    suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 20),
                    border: UnderlineInputBorder(borderSide: BorderSide(color: g.iris, width: 2)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: ok == false ? g.slate : g.iris, width: 2)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: g.iris, width: 2)),
                    disabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: g.iris, width: 2)),
                  ),
                  textInputAction: next == null ? null : TextInputAction.next,
                  // Non-null keeps the keyboard up while focus moves on.
                  onEditingComplete: next == null ? null : () {},
                  onSubmitted: (_) => next != null ? next.requestFocus() : (_r.graded ? _next() : _gradeFill()),
                ),
              ),
            ),
          ),
        );
      }
    }
    return Text.rich(TextSpan(children: spans), style: style);
  }

  /// ↑ / ↓ in a blank go to its start / end (Shift: select). Flutter's own line-by-line
  /// caret move asserts in a one-line field with centred text (Flutter 3.47).
  static const _blankVerticalKeys = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp): ExtendSelectionToDocumentBoundaryIntent(forward: false, collapseSelection: true),
    SingleActivator(LogicalKeyboardKey.arrowDown): ExtendSelectionToDocumentBoundaryIntent(forward: true, collapseSelection: true),
    SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): ExtendSelectionToDocumentBoundaryIntent(forward: false, collapseSelection: false),
    SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): ExtendSelectionToDocumentBoundaryIntent(forward: true, collapseSelection: false),
    SingleActivator(LogicalKeyboardKey.pageUp): ExtendSelectionToDocumentBoundaryIntent(forward: false, collapseSelection: true),
    SingleActivator(LogicalKeyboardKey.pageDown): ExtendSelectionToDocumentBoundaryIntent(forward: true, collapseSelection: true),
  };

  /// Sentence of a choice exercise; each {n} is the blank's word, underlined and tappable.
  Widget _choiceStem(Exercise e) {
    final style = ReadingStyles.prompt(context);
    final g = context.g;
    if (!e.text.contains(RegExp(r'\{\d+\}'))) return WordTapText(e.text, style: style, source: 'exercise:${e.id}');
    final parts = e.text.split(RegExp(r'\{\d+\}'));
    final idxs = RegExp(r'\{(\d+)\}').allMatches(e.text).map((m) => int.parse(m.group(1)!)).toList();
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: WordTapText(parts[i], style: style, source: 'exercise:${e.id}'),
          ),
        );
      }
      if (i < idxs.length) {
        final word = idxs[i] < e.blanks.length ? e.blanks[idxs[i]].answer : '';
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: InkWell(
              onTap: word.isEmpty ? null : () => showQuickDef(context, ref, word, contextSentence: e.text.replaceAll(RegExp(r'\{\d+\}'), word), source: 'exercise:${e.id}'),
              child: Text(
                word.isEmpty ? '______' : ' $word ',
                style: style.copyWith(color: g.iris, decoration: TextDecoration.underline, decorationColor: g.iris, decorationThickness: 1.5),
              ),
            ),
          ),
        );
      }
    }
    return Text.rich(TextSpan(children: spans), style: style);
  }

  Widget _choiceBody(Exercise e, ThemeData theme) {
    final wide = MediaQuery.sizeOf(context).width >= 700 && e.choices.every((c) => c.length < 40);
    final tiles = [for (var i = 0; i < e.choices.length; i++) _option(e, i, e.choices[i], theme)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stems with a {n} slot (B+C VOCABULARY, tests): the slot holds the word the options
        // replace — shown underlined, as the old app does ("A few _specks_ of paint …").
        _choiceStem(e),
        const SizedBox(height: 20),
        if (wide)
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [for (final t in tiles) SizedBox(width: w, child: t)],
              );
            },
          )
        else
          Column(
            children: [for (final t in tiles) Padding(padding: const EdgeInsets.only(bottom: 10), child: t)],
          ),
      ],
    );
  }

  Widget _errorBody(Exercise e, ThemeData theme) {
    // Sentence with four underlined parts (a–d); the learner picks the wrong one.
    final g = context.g;
    final parts = e.text.split(RegExp(r'\{\d+\}'));
    final idxs = RegExp(r'\{(\d+)\}').allMatches(e.text).map((m) => int.parse(m.group(1)!)).toList();
    final style = ReadingStyles.prompt(context);
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i], style: style));
      if (i < idxs.length && idxs[i] < e.blanks.length) {
        final b = idxs[i];
        final letter = String.fromCharCode(97 + b);
        Color color = g.ink;
        Color underline = g.fog;
        Color? bg;
        var strike = false;
        if (_r.graded) {
          if (b == e.answerIndex) {
            color = g.iris;
            underline = g.iris;
            bg = g.lilac;
          } else if (_r.picked == b) {
            color = g.slate;
          }
        } else if (_r.picked == b) {
          color = g.slate;
          strike = true;
        }
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: InkWell(
              onTap: _r.graded ? null : () => _pick(b),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: e.blanks[b].answer,
                        style: style.copyWith(
                          decoration: strike ? TextDecoration.lineThrough : TextDecoration.underline,
                          decorationThickness: 2,
                          decorationColor: underline,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: ' $letter',
                        style: theme.textTheme.labelMedium?.copyWith(color: color == g.ink ? g.fog : color),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(children: spans)),
        if (_r.graded) ...[
          const SizedBox(height: 10),
          Text('Chỗ sai là ${String.fromCharCode(97 + e.answerIndex)}${_r.lostPoint ? ' · bạn đã chọn sai trước đó' : ''}', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)),
        ],
      ],
    );
  }

  Widget _option(Exercise e, int i, String text, ThemeData theme) {
    final g = context.g;
    final letter = String.fromCharCode(97 + i);
    final isAnswer = i == e.answerIndex;
    final picked = _r.picked == i;
    final graded = _r.graded;

    Color bg = g.card, border = g.border, fg = g.ink, dotFill = Colors.transparent, dotBorder = g.border, dotColor = g.slate;
    Widget? dotChild;
    String? tag;
    var strike = false;
    var weight = FontWeight.w400;
    if (graded) {
      if (isAnswer) {
        bg = g.lilac;
        border = g.iris;
        fg = g.ink;
        weight = FontWeight.w600;
        dotFill = g.iris;
        dotBorder = g.iris;
        dotChild = Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary);
        tag = 'Đáp án';
      } else if (picked || (_r.lostPoint && _wrongPicks.contains(i))) {
        fg = g.slate;
        strike = true;
        dotFill = g.slate;
        dotBorder = g.slate;
        dotChild = Icon(Icons.close, size: 14, color: theme.colorScheme.onPrimary);
        tag = 'Bạn đã chọn';
      } else {
        fg = g.fog;
        dotColor = g.fog;
      }
    } else if (_wrongPicks.contains(i)) {
      fg = g.slate;
      strike = true;
      dotFill = g.slate;
      dotBorder = g.slate;
      dotChild = Icon(Icons.close, size: 14, color: theme.colorScheme.onPrimary);
    }

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: graded ? null : () => _pick(i),
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              LetterDot(letter, fill: dotFill, border: dotBorder, color: dotColor, child: dotChild),
              const SizedBox(width: 14),
              Expanded(
                child: WordTapText(
                  text,
                  style: ReadingStyles.line(context).copyWith(fontSize: 18, color: fg, fontWeight: weight, decoration: strike ? TextDecoration.lineThrough : null, decorationColor: g.fog),
                  source: 'exercise:${e.id}',
                ),
              ),
              if (tag != null) ...[const SizedBox(width: 8), Text(tag, style: theme.textTheme.labelMedium?.copyWith(color: isAnswer ? g.iris : g.slate))],
              if (graded && e.expl.length > 1 && !isAnswer && tag == null)
                IconButton(
                  tooltip: 'Vì sao?',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.info_outline, size: 18, color: g.fog),
                  onPressed: () => _showExplSheet(e, option: i),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Options picked wrongly on the current exercise (only the last wrong pick is remembered
  /// by [_Result]; the first wrong pick is enough to show the "lost point" state).
  Set<int> get _wrongPicks => _r.picked != null && _r.picked != _ex.answerIndex ? {_r.picked!} : const {};

  /// Type 3 drill (XepTu.bas): put the sentence's words back in order. Correct when solved
  /// without "Đáp án"; Next is the runner's own button.
  Widget _scrambleBody(Exercise e, ThemeData theme) => ScrambleBoard(
    key: ValueKey('scramble-${e.id}'),
    sentence: e.text,
    hint: 'Chạm các từ theo đúng thứ tự.',
    onSolved: (revealed) {
      if (_r.graded) return;
      setState(() {
        _r.graded = true;
        _r.correct = !revealed;
      });
      _save();
    },
  );

  Widget _sentencesBody(Exercise e, ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final line in e.text.split('\n').where((l) => l.trim().isNotEmpty))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: WordTapText(line, style: ReadingStyles.prompt(context).copyWith(fontSize: 19), source: 'exercise:${e.id}'),
        ),
    ],
  );

  // ---- explanations ------------------------------------------------------------------

  List<ExplBlock> _blocksFor(Exercise e, {int? option, int? blank}) {
    var blocks = e.expl;
    if (option != null && blocks.length > 1) {
      final letter = String.fromCharCode(65 + option);
      final mine = blocks.where((b) => RegExp('(Câu|Chữ|Phần)\\s+$letter\\b', caseSensitive: false).hasMatch(b.head)).toList();
      if (mine.isNotEmpty) blocks = mine;
    }
    if (blank != null && blocks.length > 1 && blank < blocks.length && e.blanks.length == blocks.length) blocks = [blocks[blank]];
    return blocks;
  }

  /// Inline explanation panel after grading: the wrong pick's block first, then the answer's,
  /// then anything else; for fill exercises the expected answers per blank come first.
  Widget _explanation(Exercise e, ThemeData theme) {
    final g = context.g;
    final db = ref.read(contentDbProvider);
    final ordered = <ExplBlock>[];
    if (e.kind == 'choice' || e.kind == 'error') {
      for (final w in _wrongPicks) {
        ordered.addAll(_blocksFor(e, option: w).where((b) => !ordered.contains(b)));
      }
      if (e.answerIndex >= 0) ordered.addAll(_blocksFor(e, option: e.answerIndex).where((b) => !ordered.contains(b)));
    }
    ordered.addAll(e.expl.where((b) => !ordered.contains(b)));
    final refs = <int>{for (final b in ordered) ...b.refs, ...e.refs};

    return LilacPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.kind == 'fill')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Đáp án:', style: theme.textTheme.titleSmall?.copyWith(color: g.indigo)),
                  for (var b = 0; b < e.blanks.length; b++)
                    Text.rich(
                      TextSpan(
                        children: [
                          if (e.blanks.length > 1) TextSpan(text: '${b + 1}. ', style: theme.textTheme.bodySmall),
                          TextSpan(
                            text: e.blanks[b].answer.isEmpty ? '(để trống)' : e.blanks[b].answer,
                            style: ReadingStyles.line(context).copyWith(color: g.iris, fontWeight: FontWeight.w600),
                          ),
                          if (e.blanks[b].alts.isNotEmpty) TextSpan(text: '  hoặc ${e.blanks[b].alts.join(' / ')}', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          for (final b in ordered) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _blockDot(b, e, g, theme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (b.head.trim().isNotEmpty) Text(b.head, style: theme.textTheme.titleSmall?.copyWith(color: g.indigo)),
                        for (final l in b.lines) MarkText(l, style: theme.textTheme.bodyLarge, source: 'exercise:${e.id}', onLessonRef: (n) => showLessonSheet(context, n)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (refs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Xem bài:', style: theme.textTheme.bodySmall),
                  for (final r in refs.take(8))
                    ActionChip(
                      avatar: Icon(Icons.account_tree_outlined, size: 14, color: g.iris),
                      label: Text(db.grammarLesson(r)?.title ?? 'Bài $r', style: theme.textTheme.bodySmall?.copyWith(color: g.iris)),
                      onPressed: () => showLessonSheet(context, r),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _blockDot(ExplBlock b, Exercise e, GrammarColors g, ThemeData theme) {
    final m = RegExp(r'(?:Câu|Chữ|Phần)\s+([A-Da-d])\b', caseSensitive: false).firstMatch(b.head);
    if (m == null) return Icon(Icons.lightbulb_outline, size: 20, color: g.iris);
    final letter = m.group(1)!.toLowerCase();
    final isAnswer = letter.codeUnitAt(0) - 97 == e.answerIndex;
    return LetterDot(letter, size: 28, fill: isAnswer ? g.iris : g.slate, border: isAnswer ? g.iris : g.slate, color: theme.colorScheme.onPrimary);
  }

  void _showExplSheet(Exercise e, {int? option}) {
    final blocks = _blocksFor(e, option: option);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final b in blocks) ...[
              Text(b.head, style: Theme.of(c).textTheme.titleSmall?.copyWith(color: c.g.indigo)),
              for (final l in b.lines) MarkText(l, style: Theme.of(c).textTheme.bodyLarge, source: 'exercise:${e.id}', onLessonRef: (n) => showLessonSheet(c, n)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  // ---- result ------------------------------------------------------------------------

  Widget _resultPage(ThemeData theme) {
    final g = context.g;
    final pct = _done == 0 ? 0 : (_score * 100 / _done).round();
    return Scaffold(
      appBar: GrammarAppBar(crumbs: _crumbs),
      body: PrevNextKeys(
        onPrev: () => _go(_items.length - 1),
        child: RailListView(
          maxWidth: 640,
          children: [
            Surface(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Kết quả'),
                  const SizedBox(height: 8),
                  Text('$pct %', style: theme.textTheme.displayLarge?.copyWith(color: g.iris, fontSize: 56)),
                  Text('Đúng $_score / $_done câu đã làm (${_items.length} câu)', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
                  const SizedBox(height: 20),
                  Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < _items.length; i++) _dot(i, g, theme)]),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () {
                          for (var i = 0; i < _res.length; i++) {
                            _res[i] = _Result();
                          }
                          for (final l in _ctls.values) {
                            for (final c in l) {
                              c.clear();
                            }
                          }
                          _go(0);
                        },
                        child: const Text('Làm lại'),
                      ),
                      OutlinedButton(onPressed: () => _go(0), child: const Text('Xem lại')),
                      if (widget.onNextGroup != null) OutlinedButton(onPressed: widget.onNextGroup, child: const Text('Bài Tập kế')),
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marks helper kept for pages that colour saved words.
Color savedWordColor() => Marks.savedWord;
