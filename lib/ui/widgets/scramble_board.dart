/// Word-scramble board (XepTu.bas): the sentence's words are shuffled; tap them in order
/// (a placed word stays in the pool, greyed out), a wrong word just flashes; "Đáp án" lays the rest down (no point). Used by the reading
/// page's Xếp từ and by type-3 grammar drills in the exercise runner (docs/08 X1–X3, P3).
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../platform/tts.dart';

List<String> scrambleTokens(String en) => en.replaceAll(RegExp(r"[^\w\s'’-]"), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

class ScrambleBoard extends ConsumerStatefulWidget {
  final String sentence;

  /// Shown above the board (the Vietnamese line, or an instruction).
  final String? hint;

  /// Called once when every word is placed; [revealed] = "Đáp án" was used.
  final void Function(bool revealed)? onSolved;

  /// Speak the sentence when solved (default true).
  final bool speakOnSolved;
  const ScrambleBoard({super.key, required this.sentence, this.hint, this.onSolved, this.speakOnSolved = true});

  @override
  ConsumerState<ScrambleBoard> createState() => _ScrambleBoardState();
}

class _ScrambleBoardState extends ConsumerState<ScrambleBoard> {
  late List<String> _target;
  late List<String> _pool;

  /// Indices in [_pool] already placed; they stay visible but disabled.
  final Set<int> _used = {};
  final List<String> _placed = [];
  int? _wrong;

  /// Index in [_placed] from which the words were laid down by "Đáp án" (none = length).
  int? _revealedFrom;
  bool _reported = false;
  final _rnd = Random();

  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    _target = scrambleTokens(widget.sentence);
    _pool = List.of(_target)..shuffle(_rnd);
    if (_pool.join(' ') == _target.join(' ') && _pool.length > 1) _pool = _pool.reversed.toList();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  bool get done => _placed.length == _target.length;

  void _tap(int i) {
    final want = _target[_placed.length];
    if (_pool[i] == want) {
      setState(() {
        _placed.add(_pool[i]);
        _used.add(i);
        _wrong = null;
      });
      if (done) _finish();
    } else {
      setState(() => _wrong = i);
    }
  }

  void _reveal() {
    setState(() {
      _revealedFrom = _placed.length;
      _placed.addAll(_target.skip(_placed.length));
      _used.addAll(Iterable.generate(_pool.length));
    });
    _finish();
  }

  void _finish() {
    if (_reported) return;
    _reported = true;
    if (widget.speakOnSolved) _tts.speak(widget.sentence);
    widget.onSolved?.call(_revealedFrom != null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.hint != null && widget.hint!.isNotEmpty) ...[
          Text(widget.hint!, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
        ],
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: done ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          // An invisible copy of the finished sentence sizes the box up front, so it does not grow
          // (and push the word pool down) as words are placed.
          child: Stack(
            children: [
              Visibility.maintain(
                visible: false,
                child: Wrap(spacing: 8, runSpacing: 8, children: [for (final w in _target) Chip(label: Text(w))]),
              ),
              Positioned.fill(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _placed.length; i++)
                      Chip(label: Text(_placed[i]), backgroundColor: _revealedFrom != null && i >= _revealedFrom! ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _pool.length; i++)
              ActionChip(label: Text(_pool[i]), backgroundColor: _wrong == i ? theme.colorScheme.errorContainer : null, onPressed: _used.contains(i) ? null : () => _tap(i)),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton.icon(
              onPressed: done ? null : _reveal,
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Đáp án'),
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.tertiary, foregroundColor: theme.colorScheme.onTertiary),
            ),
            const SizedBox(width: 8),
            IconButton(tooltip: 'Nghe câu', icon: const Icon(Icons.volume_up), onPressed: () => _tts.speak(widget.sentence)),
          ],
        ),
        if (done) ...[const SizedBox(height: 12), Text(widget.sentence, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary))],
      ],
    );
  }
}
