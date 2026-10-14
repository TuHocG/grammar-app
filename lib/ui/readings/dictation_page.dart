/// Nghe viết (docs/08 W1–W3): the sentence is read (TTS or recording); the Vietnamese is
/// shown; type the English. Wrong prefix → red; buttons: nghe lại, gợi ý 1 ký tự, hiện từ,
/// câu trước / kế. Punctuation is ignored as in NGHE_VIET.bas. No dictionary here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/media_locations.dart';
import '../../data/reading_loader.dart';
import '../../data/models.dart';
import '../../domain/sentence_player.dart';
import '../widgets/prev_next_keys.dart';
import '../widgets/shell.dart';
import 'reading_page.dart';

String dictationTarget(String en) => en.replaceAll(RegExp(r"[^\w\s'’-]"), '').replaceAll(RegExp(r'\s+'), ' ').trim();

class DictationPage extends ConsumerStatefulWidget {
  final int id;
  const DictationPage({super.key, required this.id});
  @override
  ConsumerState<DictationPage> createState() => _DictationPageState();
}

class _DictationPageState extends ConsumerState<DictationPage> {
  Reading? _reading;
  SentencePlayer? _player;
  List<Sentence> _items = const [];
  int _pos = 0;
  final _ctl = TextEditingController();
  final _focus = FocusNode();
  bool _wrong = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _reading = loadReading(ref, widget.id);
    if (_reading != null) {
      _items = practiceSentences(_reading!);
      _player = SentencePlayer(tts: ref.read(ttsProvider), reading: _reading!, audioPath: _reading!.hasRealAudio ? audioPathFor(ref, _reading!.audio) : null);
      WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
    }
    _ctl.addListener(_check);
  }

  @override
  void dispose() {
    _player?.dispose();
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _target => dictationTarget(_items[_pos].en);

  Future<void> _speak() => _player!.speakOnce(_items[_pos].idx);

  void _check() {
    final typed = _ctl.text;
    final t = _target;
    final ok = t.toLowerCase().startsWith(typed.toLowerCase());
    final done = typed.trim().toLowerCase() == t.toLowerCase();
    // Read the sentence again once, when the text turns wrong; more wrong letters,
    // deleting them or moving the cursor do not restart it.
    final turnedWrong = !ok && !_wrong;
    if (ok != !_wrong || done != _done) setState(() { _wrong = !ok; _done = done; });
    if (turnedWrong) _speak();
  }

  void _hintChar() {
    final t = _target;
    var typed = _ctl.text;
    if (!t.toLowerCase().startsWith(typed.toLowerCase())) typed = _commonPrefix(typed, t);
    if (typed.length < t.length) {
      _ctl.text = t.substring(0, typed.length + 1);
      _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
    }
  }

  void _hintWord() {
    final t = _target;
    var typed = _ctl.text;
    if (!t.toLowerCase().startsWith(typed.toLowerCase())) typed = _commonPrefix(typed, t);
    var end = t.indexOf(' ', typed.length);
    if (end < 0) end = t.length;
    if (end == typed.length && end < t.length) {
      end = t.indexOf(' ', end + 1);
      if (end < 0) end = t.length;
    }
    _ctl.text = t.substring(0, end);
    _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
  }

  String _commonPrefix(String a, String b) {
    var i = 0;
    while (i < a.length && i < b.length && a[i].toLowerCase() == b[i].toLowerCase()) {
      i++;
    }
    return b.substring(0, i);
  }

  void _go(int pos) {
    _pos = pos;
    _ctl.clear();
    _wrong = false;
    _done = false;
    setState(() {});
    _speak();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_reading == null || _items.isEmpty) return Scaffold(appBar: GrammarAppBar(title: const Text('Nghe viết')), body: const Center(child: Text('Bài này không có câu để nghe viết.')));
    final theme = Theme.of(context);
    final s = _items[_pos];
    final prev = _pos > 0 ? () => _go(_pos - 1) : null;
    final next = _pos < _items.length - 1 ? () => _go(_pos + 1) : null;
    return Scaffold(
      appBar: GrammarAppBar(title: Text('Nghe viết · ${_pos + 1}/${_items.length}')),
      body: PrevNextKeys(
        autofocus: false,
        onPrev: prev,
        onNext: next,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s.vi, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextField(
              controller: _ctl,
              focusNode: _focus,
              autofocus: true,
              maxLines: 3,
              style: theme.textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: 'Gõ lại câu tiếng Anh vừa nghe',
                filled: true,
                fillColor: _done
                    ? theme.colorScheme.primaryContainer
                    : (_wrong ? theme.colorScheme.errorContainer : theme.colorScheme.surfaceContainerHighest),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (_done && _pos < _items.length - 1) _go(_pos + 1);
              },
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonalIcon(onPressed: _speak, icon: const Icon(Icons.replay), label: const Text('Nghe lại')),
              OutlinedButton.icon(onPressed: _hintChar, icon: const Icon(Icons.text_increase), label: const Text('Gợi ý 1 ký tự')),
              OutlinedButton.icon(onPressed: _hintWord, icon: const Icon(Icons.short_text), label: const Text('Hiện trọn từ')),
            ]),
            if (_done)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('Đúng rồi!  ${s.en}', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
              ),
            const Spacer(),
            Row(children: [
              OutlinedButton(onPressed: prev, child: const Text('Câu trước')),
              const Spacer(),
              FilledButton(onPressed: next, child: const Text('Câu kế')),
            ]),
          ]),
        ),
      ),
    );
  }
}
