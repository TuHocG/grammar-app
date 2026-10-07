/// Đàm thoại (docs/08 T1–T6): "look at the Vietnamese, say the English". Hints are written
/// word by word at the cadence of the difficulty level 1–10 (XepTu.bas:SetMucdoF6,
/// VietTuTimer5). Table: docs/02 "Đàm thoại".
///
/// In a reading the prompt is the Vietnamese sentence; in Luyện Nói the machine reads
/// sentence A and the learner answers with sentence B (passed as [PracticeItem]).
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import '../widgets/word_tap_text.dart';
import '../widgets/shell.dart';
import 'reading_page.dart';

class PracticeItem {
  /// Shown to the learner (Vietnamese sentence, or English sentence A in Luyện Nói).
  final String prompt;
  /// What the learner must say.
  final String answer;
  /// Read [prompt] aloud instead of showing it (Luyện Nói).
  final bool speakPrompt;
  const PracticeItem({required this.prompt, required this.answer, this.speakPrompt = false});
}

/// Timer interval per level, seconds (SetMucdoF6).
const levelInterval = [5.0, 3.0, 2.0, 1.0, 0.7, 0.6, 0.5, 0.4, 0.2, 0.1];

class DialogPracticePage extends ConsumerStatefulWidget {
  final String title;
  final List<PracticeItem> items;
  /// Picture pool shown at random per sentence (Luyện Nói only).
  final List<String>? images;
  final String? source;
  const DialogPracticePage({super.key, required this.title, required this.items, this.images, this.source});

  /// Build from a reading: prompt = Vietnamese, answer = English (sentences ≥ 2 words).
  static DialogPracticePage forReading(Reading r) => DialogPracticePage(
        title: r.title,
        items: [for (final s in practiceSentences(r)) PracticeItem(prompt: s.vi, answer: s.en)],
        source: 'reading:${r.id}',
      );

  @override
  ConsumerState<DialogPracticePage> createState() => _DialogPracticePageState();
}

class _DialogPracticePageState extends ConsumerState<DialogPracticePage> {
  int _level = 4;
  int _pos = 0;
  int _rounds = 0;
  final Set<int> _skipped = {};
  final _rnd = Random();
  Timer? _timer;
  int _ticks = 0;
  int _written = 0;      // words (or dots) written so far
  bool _readWhole = false;
  bool _showAnswer = false;
  String? _image;

  List<String> get _words => widget.items[_pos].answer.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    _level = int.tryParse(ref.read(userDbProvider).setting('dialog_level') ?? '') ?? 4;
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    ref.read(ttsProvider).stop();
    super.dispose();
  }

  // ---- level behaviour (docs/02 table) -------------------------------------------

  bool get _firstWordShown => _level <= 5;
  bool get _dotsOnly => _level >= 7;
  int get _initialWait => _level <= 3 ? 3 : (_level <= 5 ? 7 : 6);

  Future<void> _start() async {
    _timer?.cancel();
    _ticks = 0;
    _readWhole = false;
    _showAnswer = false;
    _written = (_firstWordShown && _words.length >= 2) ? 1 : 0;
    if (widget.images != null && widget.images!.isNotEmpty) _image = widget.images![_rnd.nextInt(widget.images!.length)];
    setState(() {});
    final item = widget.items[_pos];
    if (item.speakPrompt) await ref.read(ttsProvider).speak(item.prompt);
    if (!mounted) return;
    _timer = Timer.periodic(Duration(milliseconds: (levelInterval[_level - 1] * 1000).round()), (_) => _tick());
  }

  Future<void> _tick() async {
    _ticks++;
    if (_ticks < _initialWait) return;
    if (_written >= _words.length) {
      _timer?.cancel();
      if (_dotsOnly && !_readWhole) {
        _readWhole = true;
        await ref.read(ttsProvider).speak(widget.items[_pos].answer);
      }
      return;
    }
    setState(() => _written++);
    if (!_dotsOnly) await ref.read(ttsProvider).speak(_words[_written - 1]);
  }

  // ---- navigation (TangCauSpeak / RandomSpeak / skip) --------------------------------

  int? _nextIndex() {
    final n = widget.items.length;
    if (_skipped.length >= n - 1) return null;
    var i = _pos;
    for (var guard = 0; guard < n * 2; guard++) {
      if (_rounds >= 5) {
        i = (i + 1 + _rnd.nextInt(20)) % n;
      } else {
        i = i + 1;
        if (i >= n) {
          i = 0;
          _rounds++;
        }
      }
      if (!_skipped.contains(i)) return i;
    }
    return null;
  }

  void _next() {
    final i = _nextIndex();
    if (i == null) {
      Navigator.of(context).pop();
      return;
    }
    _pos = i;
    _start();
  }

  void _back() {
    _pos = (_pos - 1 + widget.items.length) % widget.items.length;
    _start();
  }

  void _skip() {
    _skipped.add(_pos);
    _next();
  }

  void _setLevel(int l) {
    _level = l.clamp(1, 10);
    ref.read(userDbProvider).setSetting('dialog_level', '$_level');
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.items[_pos];
    final words = _words;
    final hint = _dotsOnly
        ? List.filled(_written, '.').join(' ')
        : words.take(_written).join(' ');
    final db = ref.read(contentDbProvider);

    return Scaffold(
      appBar: GrammarAppBar(
        title: Text('Đàm thoại · ${widget.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Hướng dẫn',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Mức độ khó'),
                content: const Text(
                  'Mức 1–5: hiện câu đề và từ đầu, rồi lần lượt từng từ (chậm → nhanh), máy đọc từng từ.\n'
                  'Mức 6: chỉ câu đề, rồi từng từ.\n'
                  'Mức 7–10: chỉ câu đề; máy chấm nhịp rồi đọc nguyên câu. Mức 10 tạo phản xạ.\n\n'
                  'Hãy nói câu Anh trước khi máy gợi ý xong.',
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đóng'))],
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('Mức độ khó', style: theme.textTheme.titleSmall),
            IconButton(icon: const Icon(Icons.remove), onPressed: _level > 1 ? () => _setLevel(_level - 1) : null),
            Text('$_level', style: theme.textTheme.titleLarge),
            IconButton(icon: const Icon(Icons.add), onPressed: _level < 10 ? () => _setLevel(_level + 1) : null),
            const Spacer(),
            Text('${_pos + 1}/${widget.items.length}', style: theme.textTheme.bodySmall),
          ]),
          const SizedBox(height: 8),
          if (_image != null)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image(image: db.imageProvider(_image!), errorBuilder: (_, _, _) => const SizedBox.shrink())),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (item.speakPrompt && _dotsOnly)
                  Text('Listen: ...', style: theme.textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic))
                else
                  WordTapText(item.prompt, style: theme.textTheme.titleMedium, source: widget.source),
                if (item.speakPrompt)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(tooltip: 'Nghe lại câu hỏi', icon: const Icon(Icons.volume_up), onPressed: () => ref.read(ttsProvider).speak(item.prompt)),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text.rich(TextSpan(children: [
            if (item.speakPrompt || _written > 0) TextSpan(text: 'Answer: ', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
            TextSpan(text: hint, style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary)),
          ])),
          if (_showAnswer)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: WordTapText(item.answer, style: theme.textTheme.titleMedium, source: widget.source),
            ),
          const Spacer(),
          Row(children: [
            OutlinedButton(onPressed: _back, child: const Text('Back')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _skip, child: const Text('Bỏ câu này')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () => setState(() => _showAnswer = true), child: const Text('Xem câu')),
            IconButton(tooltip: 'Nghe câu trả lời', icon: const Icon(Icons.volume_up), onPressed: () => ref.read(ttsProvider).speak(item.answer)),
            const Spacer(),
            FilledButton(onPressed: _next, child: const Text('Next')),
          ]),
        ]),
      ),
    );
  }
}
