/// Xếp từ (docs/08 X1–X3): the English sentence is shuffled; tap the words in order (a wrong
/// word does not move); "Đáp án" shows the sentence, "Câu kế" moves on. Sentences shorter
/// than 4 words are skipped, punctuation is dropped, as in XepTu.bas.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/content_db.dart';
import '../../data/models.dart';
import 'reading_page.dart';

List<String> scrambleTokens(String en) =>
    en.replaceAll(RegExp(r"[^\w\s'’-]"), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

class ScramblePage extends ConsumerStatefulWidget {
  final int id;
  const ScramblePage({super.key, required this.id});
  @override
  ConsumerState<ScramblePage> createState() => _ScramblePageState();
}

class _ScramblePageState extends ConsumerState<ScramblePage> {
  Reading? _reading;
  List<Sentence> _items = const [];
  int _pos = 0;
  List<String> _target = const [];
  List<String> _pool = const [];
  final List<String> _placed = [];
  int? _wrong;
  bool _revealed = false;
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    _reading = ref.read(contentDbProvider).reading(widget.id);
    if (_reading != null) {
      _items = practiceSentences(_reading!, minWords: 4);
      _load(0);
    }
  }

  void _load(int pos) {
    _pos = pos;
    _target = scrambleTokens(_items[pos].en);
    _pool = List.of(_target)..shuffle(_rnd);
    if (_pool.join(' ') == _target.join(' ') && _pool.length > 1) _pool = _pool.reversed.toList();
    _placed.clear();
    _wrong = null;
    _revealed = false;
    setState(() {});
  }

  void _tap(int i) {
    final want = _target[_placed.length];
    if (_pool[i].toLowerCase() == want.toLowerCase()) {
      setState(() {
        _placed.add(_pool[i]);
        _pool = List.of(_pool)..removeAt(i);
        _wrong = null;
      });
      if (_pool.isEmpty) ref.read(ttsProvider).speak(_items[_pos].en);
    } else {
      setState(() => _wrong = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    if (r == null || _items.isEmpty) return Scaffold(appBar: AppBar(title: const Text('Xếp từ')), body: const Center(child: Text('Bài này không có câu đủ dài để xếp.')));
    final theme = Theme.of(context);
    final s = _items[_pos];
    final done = _pool.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text('Xếp từ · ${_pos + 1}/${_items.length}')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.vi, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: done ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in _placed) Chip(label: Text(w), backgroundColor: theme.colorScheme.primaryContainer),
                if (_revealed)
                  for (final w in _target.skip(_placed.length)) Chip(label: Text(w), backgroundColor: theme.colorScheme.errorContainer),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _pool.length; i++)
                ActionChip(
                  label: Text(_pool[i]),
                  backgroundColor: _wrong == i ? theme.colorScheme.errorContainer : null,
                  onPressed: _revealed ? null : () => _tap(i),
                ),
            ],
          ),
          const Spacer(),
          if (done)
            Text(s.en, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton(onPressed: _pos > 0 ? () => _load(_pos - 1) : null, child: const Text('Câu trước')),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: done ? null : () => setState(() => _revealed = true),
              child: const Text('Đáp án'),
            ),
            const SizedBox(width: 8),
            IconButton(tooltip: 'Nghe câu', icon: const Icon(Icons.volume_up), onPressed: () => ref.read(ttsProvider).speak(s.en)),
            const Spacer(),
            FilledButton(onPressed: _pos < _items.length - 1 ? () => _load(_pos + 1) : null, child: const Text('Câu kế')),
          ]),
        ]),
      ),
    );
  }
}
