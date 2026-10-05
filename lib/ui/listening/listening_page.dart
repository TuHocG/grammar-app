/// Luyện Nghe → Bài tập (docs/08 L1): Unit 1–20; the machine reads the English sentence,
/// the learner picks one of four Vietnamese sentences (shuffled); a point only when the
/// first pick is right; the English can be looked up after answering.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/content_db_more.dart';
import '../../data/models.dart';
import '../widgets/word_tap_text.dart';
import '../../app/theme.dart';
import '../widgets/shell.dart';

class ListeningUnitsPage extends ConsumerWidget {
  const ListeningUnitsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    final units = db.listeningUnits();
    final userDb = ref.read(userDbProvider);
    return Scaffold(
      appBar: GrammarAppBar(
        title: const Text('Luyện Nghe'),
        actions: [IconButton(tooltip: 'Hướng dẫn', icon: const Icon(Icons.help_outline), onPressed: () => context.push('/help/13'))],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.movie_outlined),
            title: const Text('Video có phụ đề song ngữ'),
            subtitle: const Text('210 tập: 3 bộ video bài học và 5 phim'),
            onTap: () => context.push('/video'),
          ),
          const Divider(),
          for (final u in units)
            ListTile(
              leading: CircleAvatar(child: Text('$u')),
              title: Text('Unit $u'),
              subtitle: Text('${db.listeningCount(u)} câu${userDb.progress('listening', 'unit$u') != null ? ' · ${userDb.progress('listening', 'unit$u')}' : ''}'),
              onTap: () => context.push('/listening/$u'),
            ),
        ],
      ),
    );
  }
}

class ListeningUnitPage extends ConsumerStatefulWidget {
  final int unit;
  const ListeningUnitPage({super.key, required this.unit});
  @override
  ConsumerState<ListeningUnitPage> createState() => _ListeningUnitPageState();
}

class _ListeningUnitPageState extends ConsumerState<ListeningUnitPage> {
  late List<ListeningItem> _items;
  int _pos = 0;
  late List<int> _order;      // shuffled option order for the current item
  int? _picked;
  bool _lost = false;
  bool _graded = false;
  int _score = 0;
  int _done = 0;
  bool _finished = false;
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    _items = ref.read(contentDbProvider).listeningItems(widget.unit);
    _load(0);
  }

  void _load(int pos) {
    _pos = pos;
    _order = List.generate(_items[pos].options.length, (i) => i)..shuffle(_rnd);
    _picked = null;
    _lost = false;
    _graded = false;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  Future<void> _speak() => ref.read(ttsProvider).speak(_items[_pos].en);

  void _pick(int optionIdx) {
    if (_graded) return;
    setState(() {
      _picked = optionIdx;
      if (optionIdx == 0) {
        _graded = true;
        _done++;
        if (!_lost) _score++;
      } else {
        _lost = true;
      }
    });
    if (_graded) ref.read(userDbProvider).setProgress('listening', 'unit${widget.unit}', 'đúng $_score/$_done');
  }

  void _next() {
    if (_pos < _items.length - 1) {
      _load(_pos + 1);
    } else {
      setState(() => _finished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_items.isEmpty) return Scaffold(appBar: GrammarAppBar(title: Text('Unit ${widget.unit}')), body: const Center(child: Text('Không có câu.')));
    if (_finished) {
      final pct = _done == 0 ? 0 : (_score * 100 / _done).round();
      return Scaffold(
        appBar: GrammarAppBar(title: Text('Unit ${widget.unit}')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$pct %', style: theme.textTheme.displayMedium?.copyWith(color: theme.colorScheme.primary)),
            Text('Đúng $_score / $_done câu'),
            const SizedBox(height: 16),
            Wrap(spacing: 8, children: [
              FilledButton(onPressed: () { _score = 0; _done = 0; _finished = false; _load(0); }, child: const Text('Làm lại')),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng')),
            ]),
          ]),
        ),
      );
    }
    final it = _items[_pos];
    return Scaffold(
      appBar: GrammarAppBar(
        title: Text('Unit ${widget.unit} · ${_pos + 1}/${_items.length}'),
        actions: [Center(child: Text('Đúng $_score / $_done', style: theme.textTheme.titleSmall)), const SizedBox(width: 16)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            FilledButton.tonalIcon(onPressed: _speak, icon: const Icon(Icons.volume_up), label: const Text('Nghe lại')),
            const SizedBox(width: 12),
            Expanded(
              child: _graded
                  ? WordTapText(it.en, style: theme.textTheme.titleMedium, context: it.en, source: 'listening:${it.id}')
                  : Text('Nghe câu tiếng Anh rồi chọn câu dịch đúng.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
            ),
          ]),
          const SizedBox(height: 16),
          for (var k = 0; k < _order.length; k++) _option(k, _order[k], theme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(children: [
            OutlinedButton(onPressed: _pos > 0 ? () => _load(_pos - 1) : null, child: const Text('Câu trước')),
            const Spacer(),
            FilledButton(onPressed: _graded ? _next : null, child: Text(_pos == _items.length - 1 ? 'Kết thúc' : 'Câu kế')),
          ]),
        ),
      ),
    );
  }

  Widget _option(int shown, int optionIdx, ThemeData theme) {
    final it = _items[_pos];
    final g = context.g;
    final letter = String.fromCharCode(97 + shown);
    final isAnswer = optionIdx == 0;
    Color bg = g.card, border = g.border, fg = g.ink, dotFill = Colors.transparent, dotBorder = g.border, dotColor = g.slate;
    Widget? dotChild;
    var weight = FontWeight.w400;
    var strike = false;
    if (_graded) {
      if (isAnswer) {
        bg = g.lilac;
        border = g.iris;
        weight = FontWeight.w600;
        dotFill = g.iris;
        dotBorder = g.iris;
        dotChild = Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary);
      } else if (_picked == optionIdx) {
        fg = g.slate;
        strike = true;
        dotFill = g.slate;
        dotBorder = g.slate;
        dotChild = Icon(Icons.close, size: 14, color: theme.colorScheme.onPrimary);
      } else {
        fg = g.fog;
        dotColor = g.fog;
      }
    } else if (_picked == optionIdx) {
      fg = g.slate;
      strike = true;
      dotFill = g.slate;
      dotBorder = g.slate;
      dotChild = Icon(Icons.close, size: 14, color: theme.colorScheme.onPrimary);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: border)),
        child: InkWell(
          onTap: _graded ? null : () => _pick(optionIdx),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              LetterDot(letter, fill: dotFill, border: dotBorder, color: dotColor, child: dotChild),
              const SizedBox(width: 14),
              Expanded(child: Text(it.options[optionIdx], style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17, color: fg, fontWeight: weight, decoration: strike ? TextDecoration.lineThrough : null, decorationColor: g.fog))),
            ]),
          ),
        ),
      ),
    );
  }

}
