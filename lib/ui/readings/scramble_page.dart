/// Xếp từ (docs/08 X1–X3): the English sentence is shuffled; tap the words in order (a wrong
/// word does not move); "Đáp án" shows the sentence, "Câu kế" moves on. Sentences shorter
/// than 4 words are skipped, punctuation is dropped, as in XepTu.bas. The board itself is
/// ScrambleBoard, shared with the grammar drills of type 3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reading_loader.dart';
import '../../data/models.dart';
import '../widgets/prev_next_keys.dart';
import '../widgets/scramble_board.dart';
import '../widgets/shell.dart';
import 'reading_page.dart';

export '../widgets/scramble_board.dart' show scrambleTokens;

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

  @override
  void initState() {
    super.initState();
    _reading = loadReading(ref, widget.id);
    if (_reading != null) _items = practiceSentences(_reading!, minWords: 4);
  }

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    if (r == null || _items.isEmpty) {
      return Scaffold(
        appBar: GrammarAppBar(title: const Text('Xếp từ')),
        body: const Center(child: Text('Bài này không có câu đủ dài để xếp.')),
      );
    }
    final s = _items[_pos];
    final prev = _pos > 0 ? () => setState(() => _pos--) : null;
    final next = _pos < _items.length - 1 ? () => setState(() => _pos++) : null;
    return Scaffold(
      appBar: GrammarAppBar(title: Text('Xếp từ · ${_pos + 1}/${_items.length}')),
      body: PrevNextKeys(
        onPrev: prev,
        onNext: next,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: ScrambleBoard(key: ValueKey('${r.id}-$_pos'), sentence: s.en, hint: s.vi),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton(onPressed: prev, child: const Text('Câu trước')),
                  const Spacer(),
                  FilledButton(onPressed: next, child: const Text('Câu kế')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
