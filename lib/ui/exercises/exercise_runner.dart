/// ExerciseRunner (docs/08 E2–E10): one page that runs a list of exercises of the four kinds
/// with the old app's rules: fill (lower-case trimmed compare, all alternatives accepted,
/// empty answer accepts an empty blank), choice (no shuffle; a wrong pick first = no point),
/// error (pick the wrong part), sentences (display only). After grading: explanation per
/// blank/option with grammar links, Vietnamese translation, score; at the end a result card.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/models.dart';
import '../grammar/grammar_page.dart';
import '../widgets/mark_text.dart';
import '../widgets/word_tap_text.dart';

class ExerciseRunner extends ConsumerStatefulWidget {
  final String title;
  final List<Exercise> exercises;
  /// Titles come from the "lesson" set when run from a grammar lesson, else the "menu" set.
  final bool lessonContext;
  /// Called when the learner finishes the list; return true to close.
  final VoidCallback? onNextGroup;
  final String? progressKey;
  const ExerciseRunner({super.key, required this.title, required this.exercises, this.lessonContext = false, this.onNextGroup, this.progressKey});

  @override
  ConsumerState<ExerciseRunner> createState() => _ExerciseRunnerState();
}

class _Result {
  bool graded = false;
  bool correct = false;
  bool lostPoint = false; // choice: wrong pick before the right one
  int? picked;            // choice/error
  List<bool> blankOk = const [];
}

class _ExerciseRunnerState extends ConsumerState<ExerciseRunner> {
  int _pos = 0;
  late final List<_Result> _res = List.generate(widget.exercises.length, (_) => _Result());
  final Map<int, List<TextEditingController>> _ctls = {};
  bool _showVi = false;
  bool _finished = false;

  Exercise get _ex => widget.exercises[_pos];
  _Result get _r => _res[_pos];
  int get _score => _res.where((r) => r.graded && r.correct).length;
  int get _done => _res.where((r) => r.graded).length;

  List<TextEditingController> _controllers(Exercise e) =>
      _ctls.putIfAbsent(e.id, () => List.generate(e.blanks.length, (_) => TextEditingController()));

  @override
  void dispose() {
    for (final l in _ctls.values) {
      for (final c in l) {
        c.dispose();
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
        _r.lostPoint = true;   // the old app: wrong first, right later = no point
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
    if (pos < 0 || pos >= widget.exercises.length) return;
    setState(() {
      _pos = pos;
      _showVi = false;
    });
  }

  void _next() {
    if (_pos < widget.exercises.length - 1) {
      _go(_pos + 1);
    } else {
      setState(() => _finished = true);
    }
  }

  // ---- UI ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.exercises.isEmpty) {
      return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: Text('Không có bài tập.')));
    }
    if (_finished) return _resultPage(theme);
    final e = _ex;
    final db = ref.read(contentDbProvider);
    final heading = e.tt == null ? null : db.exerciseTitle(e.tt!, lessonContext: widget.lessonContext);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Center(child: Text('Đúng $_score / $_done', style: theme.textTheme.titleSmall)),
          const SizedBox(width: 12),
          IconButton(tooltip: 'Hướng dẫn', icon: const Icon(Icons.help_outline), onPressed: () => showLessonHelp(context, e.kind)),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () {
            if (e.kind == 'fill' && !_r.graded) {
              _gradeFill();
            } else if (_r.graded || e.kind == 'sentences' || e.kind == 'text') {
              _next();
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(children: [
                Text('Câu ${_pos + 1} / ${widget.exercises.length}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                const Spacer(),
                if (_r.graded)
                  Icon(_r.correct ? Icons.check_circle : Icons.cancel, color: _r.correct ? Colors.green : theme.colorScheme.error),
              ]),
              if (heading != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 10),
                  child: Text(heading.replaceAll(r'\', ' / '), style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                ),
              if (e.given.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(spacing: 6, children: [
                    Text('Từ cho trước: ', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                    for (final g in e.given) Chip(label: Text(g), visualDensity: VisualDensity.compact),
                  ]),
                ),
              switch (e.kind) {
                'fill' => _fillBody(e, theme),
                'choice' => _choiceBody(e, theme),
                'error' => _errorBody(e, theme),
                _ => _sentencesBody(e, theme),
              },
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (e.kind == 'fill' && !_r.graded) FilledButton.icon(onPressed: _gradeFill, icon: const Icon(Icons.check), label: const Text('Chấm (Enter)')),
                if (_r.graded && e.kind == 'fill')
                  OutlinedButton.icon(
                    onPressed: () {
                      final ctls = _controllers(e);
                      for (var i = 0; i < e.blanks.length; i++) {
                        ctls[i].text = e.blanks[i].answer;
                      }
                      setState(() {});
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('Đáp án'),
                  ),
                if (_r.graded && e.expl.isNotEmpty)
                  OutlinedButton.icon(onPressed: () => _showExpl(e), icon: const Icon(Icons.lightbulb_outline), label: const Text('Vì sao?')),
                if (e.vi != null && e.vi!.isNotEmpty)
                  OutlinedButton.icon(onPressed: () => setState(() => _showVi = !_showVi), icon: const Icon(Icons.translate), label: const Text('Dịch')),
                if (e.refs.isNotEmpty && (_r.graded || e.kind == 'sentences'))
                  for (final r in e.refs.take(6))
                    ActionChip(
                      avatar: const Icon(Icons.menu_book, size: 16),
                      label: Text('Bài $r'),
                      onPressed: () => showLessonSheet(context, r),
                    ),
              ]),
              if (_showVi && e.vi != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(e.vi!, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(children: [
            OutlinedButton.icon(onPressed: _pos > 0 ? () => _go(_pos - 1) : null, icon: const Icon(Icons.chevron_left), label: const Text('Back')),
            const Spacer(),
            Text('$_score đúng', style: theme.textTheme.bodySmall),
            const Spacer(),
            FilledButton.icon(onPressed: _next, icon: const Icon(Icons.chevron_right), label: Text(_pos == widget.exercises.length - 1 ? 'Kết thúc' : 'Next')),
          ]),
        ),
      ),
    );
  }

  Widget _fillBody(Exercise e, ThemeData theme) {
    final ctls = _controllers(e);
    final parts = e.text.split(RegExp(r'\{\d+\}'));
    final idxs = RegExp(r'\{(\d+)\}').allMatches(e.text).map((m) => int.parse(m.group(1)!)).toList();
    final spans = <InlineSpan>[];
    final style = theme.textTheme.titleMedium!;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: WordTapText(parts[i], style: style, source: 'exercise:${e.id}')));
      }
      if (i < idxs.length && idxs[i] < e.blanks.length) {
        final b = idxs[i];
        final ok = _r.graded && b < _r.blankOk.length ? _r.blankOk[b] : null;
        final width = (e.blanks[b].n * 9.0 + 36).clamp(60.0, 260.0);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SizedBox(
            width: width,
            child: TextField(
              controller: ctls[b],
              enabled: !_r.graded || !(ok ?? false),
              style: style.copyWith(color: ok == null ? null : (ok ? Colors.green.shade700 : theme.colorScheme.error), fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                filled: ok != null,
                fillColor: ok == null ? null : (ok ? Colors.green.withValues(alpha: 0.12) : theme.colorScheme.errorContainer),
                suffixIcon: _r.graded
                    ? IconButton(
                        tooltip: 'Vì sao?',
                        icon: const Icon(Icons.info_outline, size: 18),
                        onPressed: () => _showExpl(e, blank: b),
                      )
                    : null,
                border: const UnderlineInputBorder(),
              ),
              onSubmitted: (_) => _r.graded ? _next() : _gradeFill(),
            ),
          ),
        ));
      }
    }
    return Text.rich(TextSpan(children: spans), style: style);
  }

  Widget _choiceBody(Exercise e, ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WordTapText(e.text, style: theme.textTheme.titleMedium, source: 'exercise:${e.id}'),
      const SizedBox(height: 12),
      for (var i = 0; i < e.choices.length; i++) _option(e, i, e.choices[i], theme),
    ]);
  }

  Widget _errorBody(Exercise e, ThemeData theme) {
    // Sentence with four underlined parts (a–d); the learner picks the wrong one.
    final parts = e.text.split(RegExp(r'\{\d+\}'));
    final idxs = RegExp(r'\{(\d+)\}').allMatches(e.text).map((m) => int.parse(m.group(1)!)).toList();
    final style = theme.textTheme.titleMedium!;
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i], style: style));
      if (i < idxs.length && idxs[i] < e.blanks.length) {
        final b = idxs[i];
        final letter = String.fromCharCode(97 + b);
        Color? color;
        if (_r.graded) {
          if (b == e.answerIndex) color = Colors.green.shade700;
        } else if (_r.picked == b) {
          color = theme.colorScheme.error;
        }
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: InkWell(
            onTap: () => _pick(b),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: e.blanks[b].answer, style: style.copyWith(decoration: TextDecoration.underline, decorationThickness: 2, color: color, fontWeight: FontWeight.w600)),
                TextSpan(text: ' ($letter)', style: style.copyWith(fontSize: 12, color: theme.colorScheme.outline)),
              ])),
            ),
          ),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Chọn chỗ sai:', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(height: 6),
      Text.rich(TextSpan(children: spans)),
      if (_r.graded)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(spacing: 6, children: [
            for (var b = 0; b < e.blanks.length; b++)
              ActionChip(label: Text('(${String.fromCharCode(97 + b)}) vì sao?'), onPressed: () => _showExpl(e, option: b)),
          ]),
        ),
    ]);
  }

  Widget _option(Exercise e, int i, String text, ThemeData theme) {
    final letter = String.fromCharCode(97 + i);
    final isAnswer = i == e.answerIndex;
    Color? bg;
    Color? fg;
    if (_r.graded) {
      if (isAnswer) {
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green.shade800;
      } else {
        fg = theme.colorScheme.outline;
      }
    } else if (_r.picked == i) {
      bg = theme.colorScheme.errorContainer;
    }
    return Card(
      color: bg,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(radius: 14, child: Text(letter)),
        title: WordTapText(text, style: theme.textTheme.bodyLarge?.copyWith(color: fg), source: 'exercise:${e.id}'),
        trailing: (_r.graded || _r.picked == i) && e.expl.isNotEmpty
            ? IconButton(tooltip: 'Vì sao?', icon: const Icon(Icons.info_outline), onPressed: () => _showExpl(e, option: i))
            : null,
        onTap: _r.graded ? null : () => _pick(i),
      ),
    );
  }

  Widget _sentencesBody(Exercise e, ThemeData theme) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final line in e.text.split('\n').where((l) => l.trim().isNotEmpty))
          Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: WordTapText(line, style: theme.textTheme.titleMedium, source: 'exercise:${e.id}')),
      ]);

  void _showExpl(Exercise e, {int? blank, int? option}) {
    List<ExplBlock> blocks = e.expl;
    if (option != null && blocks.length > 1) {
      final letter = String.fromCharCode(65 + option);
      final mine = blocks.where((b) => RegExp('(Câu|Chữ|Phần)\\s+$letter\\b', caseSensitive: false).hasMatch(b.head)).toList();
      if (mine.isNotEmpty) blocks = mine;
    }
    if (blank != null && blocks.length > 1 && blank < blocks.length && e.blanks.length == blocks.length) blocks = [blocks[blank]];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        builder: (c, ctl) => ListView(
          controller: ctl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            if (e.vi != null && e.vi!.isNotEmpty) Text(e.vi!, style: Theme.of(c).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
            for (final b in blocks) ...[
              const SizedBox(height: 10),
              Text(b.head, style: Theme.of(c).textTheme.titleSmall?.copyWith(color: Theme.of(c).colorScheme.primary)),
              for (final l in b.lines) Padding(padding: const EdgeInsets.only(top: 2), child: MarkText(l, style: Theme.of(c).textTheme.bodyMedium, source: 'exercise:${e.id}')),
              if (b.refs.isNotEmpty)
                Wrap(spacing: 6, children: [
                  for (final r in b.refs) ActionChip(avatar: const Icon(Icons.menu_book, size: 16), label: Text('Bài $r'), onPressed: () => showLessonSheet(c, r)),
                ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultPage(ThemeData theme) {
    final pct = _done == 0 ? 0 : (_score * 100 / _done).round();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$pct %', style: theme.textTheme.displayMedium?.copyWith(color: theme.colorScheme.primary)),
              Text('Đúng $_score / $_done câu đã làm (${widget.exercises.length} câu)', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 20),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: () => setState(() { _finished = false; _go(0); }), child: const Text('Xem lại')),
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
                    setState(() { _finished = false; _go(0); });
                  },
                  child: const Text('Làm lại'),
                ),
                if (widget.onNextGroup != null) FilledButton.tonal(onPressed: widget.onNextGroup, child: const Text('Nhóm kế')),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Help topic per exercise kind (docs/source/C §8.1 mapping).
void showLessonHelp(BuildContext context, String kind) {
  final id = switch (kind) { 'choice' => 8, 'error' => 12, _ => 15 };
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _HelpRoute(id)));
}

class _HelpRoute extends ConsumerWidget {
  final int id;
  const _HelpRoute(this.id);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.read(contentDbProvider).helpTopic(id);
    return Scaffold(
      appBar: AppBar(title: Text(t?.title ?? 'Hướng dẫn')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: SelectableText(t?.text ?? '')),
    );
  }
}

/// Marks helper kept for pages that colour saved words.
Color savedWordColor() => Marks.savedWord;
