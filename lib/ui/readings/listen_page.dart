/// Nghe toàn bài (docs/08 R5, R6): reads sentence by sentence (TTS or recording with time
/// marks), highlights the current one; previous / repeat / next; auto-advance toggle.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/content_db.dart';
import '../../domain/sentence_player.dart';
import '../widgets/word_tap_text.dart';

class ListenPage extends ConsumerStatefulWidget {
  final int id;
  const ListenPage({super.key, required this.id});
  @override
  ConsumerState<ListenPage> createState() => _ListenPageState();
}

class _ListenPageState extends ConsumerState<ListenPage> {
  SentencePlayer? _player;
  bool _showVi = true;
  final _scroll = ScrollController();
  final _keys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    final db = ref.read(contentDbProvider);
    final r = db.reading(widget.id);
    if (r != null) {
      _player = SentencePlayer(tts: ref.read(ttsProvider), reading: r, audioPath: r.hasRealAudio ? db.mediaPath(r.audio!) : null)
        ..addListener(_onChange);
      WidgetsBinding.instance.addPostFrameCallback((_) => _player!.play(from: 0));
    }
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    final k = _keys[_player!.index];
    if (k?.currentContext != null) {
      Scrollable.ensureVisible(k!.currentContext!, alignment: 0.3, duration: const Duration(milliseconds: 250));
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final p = _player!;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      p.repeat();
    } else if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      p.previous();
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight || e.logicalKey == LogicalKeyboardKey.arrowDown) {
      p.next();
    } else if (e.logicalKey == LogicalKeyboardKey.space) {
      p.state == PlayerState.playing ? p.stop() : p.play();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final p = _player;
    if (p == null) return const Scaffold(body: Center(child: Text('Không có bài này.')));
    final r = p.reading;
    final theme = Theme.of(context);
    final playing = p.state == PlayerState.playing;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Nghe: ${r.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: _showVi ? 'Ẩn bản dịch' : 'Hiện bản dịch',
              icon: Icon(_showVi ? Icons.translate : Icons.translate_outlined),
              onPressed: () => setState(() => _showVi = !_showVi),
            ),
          ],
        ),
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Text(r.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (final para in r.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final s in para)
                    InkWell(
                      key: _keys.putIfAbsent(s.idx, GlobalKey.new),
                      onTap: () => p.play(from: s.idx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          WordTapText(s.en, style: theme.textTheme.bodyLarge, context: s.en, source: 'reading:${r.id}', highlighted: p.index == s.idx),
                          if (_showVi && p.index == s.idx)
                            Text(s.vi, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ]),
                      ),
                    ),
                ]),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                'Câu ${p.index + 1} / ${p.count}${r.hasRealAudio ? ' · giọng thật' : ' · giọng máy'}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(tooltip: 'Câu trước (↑)', iconSize: 32, icon: const Icon(Icons.skip_previous), onPressed: p.index > 0 ? p.previous : null),
                IconButton(tooltip: 'Nghe lại câu này (←)', iconSize: 32, icon: const Icon(Icons.replay), onPressed: p.repeat),
                IconButton(
                  tooltip: playing ? 'Dừng (space)' : 'Phát (space)',
                  iconSize: 48,
                  icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                  onPressed: playing ? p.stop : () => p.play(),
                ),
                IconButton(tooltip: 'Câu kế (→)', iconSize: 32, icon: const Icon(Icons.skip_next), onPressed: p.index < p.count - 1 ? p.next : null),
                IconButton(
                  tooltip: p.continuous ? 'Đang đọc liên tục' : 'Chỉ đọc một câu',
                  icon: Icon(p.continuous ? Icons.playlist_play : Icons.looks_one_outlined),
                  onPressed: () => setState(() => p.continuous = !p.continuous),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
