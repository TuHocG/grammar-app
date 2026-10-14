/// Quay Từ (docs/08 V5, V6): marked words come up one after another as flashcards
/// (word → read aloud → meaning), speed 1–10; tap the card to look the word up; "Đã thuộc"
/// removes the mark. With nothing marked, all saved words come up instead (no "Đã thuộc").
/// Replaces the old scrolling-text display.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../platform/tts.dart';
import '../dictionary/quick_def_sheet.dart';
import '../widgets/shell.dart';

class SpinWordsPage extends ConsumerStatefulWidget {
  const SpinWordsPage({super.key});
  @override
  ConsumerState<SpinWordsPage> createState() => _SpinWordsPageState();
}

class _SpinWordsPageState extends ConsumerState<SpinWordsPage> {
  int _speed = 5;
  int _pos = 0;
  bool _showMeaning = false;
  bool _running = true;
  Timer? _timer;
  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    _speed = int.tryParse(ref.read(userDbProvider).setting('spin_speed') ?? '') ?? 5;
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    super.dispose();
  }

  Duration get _interval => Duration(milliseconds: (4200 - _speed * 350).clamp(600, 4000));

  void _schedule() {
    _timer?.cancel();
    if (!_running) return;
    _timer = Timer(_interval, _tick);
  }

  /// Marked words, or every saved word when none is marked (`all` = true).
  static (List<UserWord>, bool all) _deck(List<UserWord> saved) {
    final marked = saved.where((w) => w.marked).toList();
    return marked.isEmpty ? (saved, true) : (marked, false);
  }

  Future<void> _tick() async {
    final (words, _) = _deck(ref.read(userWordsProvider).words);
    if (words.isEmpty) return;
    if (!_showMeaning) {
      setState(() => _showMeaning = true);
    } else {
      setState(() { _pos = (_pos + 1) % words.length; _showMeaning = false; });
      if (_speed <= 7) await _tts.speak(words[_pos].headword);   // 8–10: no voice, as in the old app
    }
    if (mounted) _schedule();
  }

  String _meaning(UserWord w) {
    if (w.meaning != null && w.meaning!.isNotEmpty) return w.meaning!.replaceAll('_', '\n');
    final r = ref.read(lookupProvider).lookup(w.headword);
    return r.quick?.vi ?? r.entries.firstOrNull?.preview ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (words, all) = _deck(ref.watch(userWordsProvider).words);
    if (_pos >= words.length) _pos = 0;
    final w = words.isEmpty ? null : words[_pos];
    return Scaffold(
      appBar: GrammarAppBar(
        title: const Text('Quay Từ'),
        helpSlug: 'tu-vung-cua-ban',
      ),
      body: w == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Chưa có từ nào trong Từ Vựng Của Bạn. Chạm một từ trong bài rồi bấm Lưu.', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              ),
            )
          : Column(children: [
              if (all)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text('Chưa đánh dấu sao từ nào nên đang ôn tất cả từ đã lưu.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                ),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => showQuickDef(context, ref, w.headword, source: 'spin'),
                    child: Card(
                      margin: const EdgeInsets.all(24),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(w.headword, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: Marks.savedWord)),
                          if (w.ipa != null && w.ipa!.isNotEmpty) Text('/${w.ipa}/', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                          const SizedBox(height: 16),
                          AnimatedOpacity(
                            opacity: _showMeaning ? 1 : 0,
                            // Fade in only: hiding happens as the card switches word, so a fade-out would flash the next meaning.
                            duration: _showMeaning ? const Duration(milliseconds: 250) : Duration.zero,
                            child: Text(_meaning(w), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(children: [
                  Row(children: [
                    Text('Tốc độ $_speed', style: theme.textTheme.bodyMedium),
                    Expanded(
                      child: Slider(
                        value: _speed.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        onChanged: (v) { setState(() => _speed = v.round()); ref.read(userDbProvider).setSetting('spin_speed', '$_speed'); _schedule(); },
                      ),
                    ),
                    Text('${words.length} từ · ${_pos + 1}', style: theme.textTheme.bodySmall),
                  ]),
                  Wrap(spacing: 8, children: [
                    IconButton(iconSize: 36, icon: Icon(_running ? Icons.pause_circle : Icons.play_circle), onPressed: () { setState(() => _running = !_running); _schedule(); }),
                    OutlinedButton.icon(onPressed: () => _tts.speak(w.headword), icon: const Icon(Icons.volume_up), label: const Text('Đọc')),
                    OutlinedButton.icon(onPressed: () => setState(() => _showMeaning = true), icon: const Icon(Icons.visibility), label: const Text('Nghĩa')),
                    if (!all) OutlinedButton.icon(
                      onPressed: () { ref.read(userWordsProvider.notifier).setMarked(w.id, false); setState(() => _showMeaning = false); },
                      icon: const Icon(Icons.check),
                      label: const Text('Đã thuộc'),
                    ),
                    OutlinedButton.icon(onPressed: () => _tick(), icon: const Icon(Icons.skip_next), label: const Text('Tiếp')),
                  ]),
                ]),
              ),
            ]),
    );
  }
}
