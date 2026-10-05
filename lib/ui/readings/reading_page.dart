/// Trang bài đọc (docs/08 R2–R4): image, title, paragraphs of tappable words; long-press a
/// sentence (or tap its number) → translation + read aloud; bottom bar → Nghe toàn bài,
/// Xếp từ, Đàm thoại, Nghe viết.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/reading_loader.dart';
import '../../data/models.dart';
import '../../domain/sentence_player.dart';
import '../widgets/word_tap_text.dart';

class ReadingPage extends ConsumerStatefulWidget {
  final int id;
  const ReadingPage({super.key, required this.id});
  @override
  ConsumerState<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends ConsumerState<ReadingPage> {
  Reading? _reading;
  SentencePlayer? _player;
  bool _showAllVi = false;
  final Set<int> _openVi = {};
  int? _speaking;

  @override
  void initState() {
    super.initState();
    final db = ref.read(contentDbProvider);
    _reading = loadReading(ref, widget.id);
    if (_reading != null) {
      if (_reading!.sid >= 0) ref.read(userDbProvider).setProgress('reading', 'last_in_${_reading!.sid}', '${_reading!.id}');
      ref.read(userDbProvider).setProgress('reading', 'last_reading', '${_reading!.id}');
      _player = SentencePlayer(
        tts: ref.read(ttsProvider),
        reading: _reading!,
        audioPath: _reading!.hasRealAudio ? db.mediaPath(_reading!.audio!) : null,
      )..addListener(() {
          if (mounted) setState(() => _speaking = _player!.state == PlayerState.playing ? _player!.index : null);
        });
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _tapSentence(Sentence s) async {
    setState(() {
      if (_openVi.contains(s.idx)) {
        _openVi.remove(s.idx);
      } else {
        _openVi.add(s.idx);
      }
    });
    await _player?.speakOnce(s.idx);
  }

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    if (r == null) return const Scaffold(body: Center(child: Text('Không có bài này.')));
    final db = ref.read(contentDbProvider);
    final theme = Theme.of(context);
    final (prev, next) = r.id >= userReadingBase ? (null, null) : db.neighbours(r);
    final src = 'reading:${r.id}';

    return Scaffold(
      appBar: AppBar(
        title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: _showAllVi ? 'Ẩn bản dịch' : 'Hiện bản dịch',
            icon: Icon(_showAllVi ? Icons.translate : Icons.translate_outlined, color: _showAllVi ? theme.colorScheme.primary : null),
            onPressed: () => setState(() => _showAllVi = !_showAllVi),
          ),
          if (r.hasRealAudio && r.titleAudio)
            IconButton(tooltip: 'Nghe tựa đề', icon: const Icon(Icons.record_voice_over), onPressed: () => _player?.playTitle()),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'help') context.push('/help/3');
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'help', child: Text('Hướng dẫn Bài đọc'))],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (r.img != null)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(r.id >= userReadingBase ? File(r.img!) : db.mediaFile(r.img!), fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: WordTapText(r.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), source: src)),
            IconButton(tooltip: 'Đọc tựa', icon: const Icon(Icons.volume_up), onPressed: () => ref.read(ttsProvider).speak(r.title)),
          ]),
          if (r.page != null) Text('Trang ${r.page}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          for (final para in r.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final s in para) _SentenceBlock(
                  sentence: s,
                  source: src,
                  showVi: _showAllVi || _openVi.contains(s.idx),
                  highlighted: _speaking == s.idx,
                  onTap: () => _tapSentence(s),
                ),
              ]),
            ),
          if (r.hasRealAudio)
            Text('Bài này có giọng đọc thật.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(children: [
            IconButton(tooltip: 'Bài trước', icon: const Icon(Icons.chevron_left), onPressed: prev == null ? null : () => context.pushReplacement('/readings/$prev')),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [
                  _Act('Nghe toàn bài', Icons.play_circle_outline, () => context.push('/readings/${r.id}/listen')),
                  _Act('Xếp từ', Icons.shuffle, () => context.push('/readings/${r.id}/scramble')),
                  _Act('Đàm thoại', Icons.forum_outlined, () => context.push('/readings/${r.id}/dialog')),
                  _Act('Nghe viết', Icons.keyboard_alt_outlined, () => context.push('/readings/${r.id}/dictation')),
                ],
              ),
            ),
            IconButton(tooltip: 'Bài kế', icon: const Icon(Icons.chevron_right), onPressed: next == null ? null : () => context.pushReplacement('/readings/$next')),
          ]),
        ),
      ),
    );
  }
}

class _Act extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _Act(this.label, this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => ActionChip(avatar: Icon(icon, size: 18), label: Text(label), onPressed: onTap);
}

class _SentenceBlock extends StatelessWidget {
  final Sentence sentence;
  final String source;
  final bool showVi;
  final bool highlighted;
  final VoidCallback onTap;
  const _SentenceBlock({required this.sentence, required this.source, required this.showVi, required this.highlighted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 28,
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            child: Icon(showVi ? Icons.expand_less : Icons.translate_outlined, size: 16, color: highlighted ? theme.colorScheme.primary : theme.colorScheme.outline),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WordTapText(sentence.en, style: theme.textTheme.bodyLarge, context: sentence.en, source: source, highlighted: highlighted),
            if (showVi && sentence.vi.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(sentence.vi, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Small helper used by the practice pages: sentences eligible for practice.
List<Sentence> practiceSentences(Reading r, {int minWords = 2}) => r.sentences.where((s) => s.wordCount >= minWords).toList();

/// Red/underline marks are handled by WordTapText; this exposes the colours for the practice pages.
Color savedColor() => Marks.savedWord;
