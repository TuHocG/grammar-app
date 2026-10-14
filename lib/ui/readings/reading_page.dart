/// Trang bài đọc (docs/08 R2–R4): image, title, paragraphs of tappable words with small
/// sentence numbers; tap a number → the sentence is read aloud and its translation opens in
/// a lilac panel under the paragraph; "Bản dịch" shows every translation. Toolbar → Nghe toàn
/// bài, Xếp từ, Đàm thoại, Nghe viết. On wide screens the section's readings sit on the left.
/// Drag (mouse) or long-press (touch) selects a phrase; a floating "Tra cụm" button and the
/// selection menu look it up (docs/08 G7). An analysed unit (Phân Tích Câu, docs/08 A1–A2)
/// uses the same page: its words are the '|' groups and a tap opens the analysis card.
library;

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/media_locations.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/reading_loader.dart';
import '../../data/models.dart';
import '../../data/search_key.dart';
import '../../data/content_db_more.dart';
import '../../domain/sentence_player.dart';
import '../analysis/analysis_card.dart';
import '../analysis/analysis_page.dart';
import '../dictionary/quick_def_sheet.dart';
import '../widgets/shell.dart';
import '../vocab/word_hint.dart';
import '../widgets/word_tap_text.dart';

class ReadingPage extends ConsumerStatefulWidget {
  final int id;
  /// Opened from the Phân Tích Câu list: breadcrumbs lead back there.
  final bool fromAnalysis;
  const ReadingPage({super.key, required this.id, this.fromAnalysis = false});
  @override
  ConsumerState<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends ConsumerState<ReadingPage> {
  Reading? _reading;
  SentencePlayer? _player;
  bool _showAllVi = false;
  final Set<int> _openVi = {};
  int? _speaking;
  /// Phrase currently selected in the article (cleaned), or null. A notifier so the
  /// floating button updates without rebuilding the selectable text.
  final ValueNotifier<String?> _phrase = ValueNotifier(null);
  /// Analysis of every '|' token (Phân Tích Câu units), null for ordinary readings.
  List<AnalysisWord>? _analysis;
  /// First global token index of each sentence (by idx) in analysis mode.
  final Map<int, int> _tokenStart = {};

  @override
  void initState() {
    super.initState();
    final db = ref.read(contentDbProvider);
    _reading = loadReading(ref, widget.id);
    if (_reading != null) {
      final lesson = analysisLessonOf(db, _reading!.id);
      if (lesson != null) {
        _analysis = db.analysisWords(lesson);
        var k = 0;
        for (final s in _reading!.sentences) {
          _tokenStart[s.idx] = k;
          k += s.tokens?.length ?? 0;
        }
      }
      if (_reading!.sid >= 0) ref.read(userDbProvider).setProgress('reading', 'last_in_${_reading!.sid}', '${_reading!.id}');
      ref.read(userDbProvider).setProgress('reading', 'last_reading', '${_reading!.id}');
      if (widget.fromAnalysis && lesson != null) ref.read(userDbProvider).setProgress('analysis', 'last', '$lesson');
      _player = SentencePlayer(
        tts: ref.read(ttsProvider),
        reading: _reading!,
        audioPath: _reading!.hasRealAudio ? audioPathFor(ref, _reading!.audio) : null,
      )..addListener(() {
          if (mounted) setState(() => _speaking = _player!.state == PlayerState.playing ? _player!.index : null);
        });
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    _phrase.dispose();
    WordHints.selected.value = null;
    super.dispose();
  }

  static final _ws = RegExp(r'\s+');
  static final _letter = RegExp(r'[A-Za-zÀ-ɏḀ-ỿ]');

  void _selectionChanged(SelectedContent? sel) {
    var t = (sel?.plainText ?? '').replaceAll(_ws, ' ').trim();
    t = cleanToken(t);
    _phrase.value = _letter.hasMatch(t) ? t : null;
    WordHints.selected.value = _phrase.value == null ? null : (word: _phrase.value!, context: null, source: 'reading:${widget.id}');
  }

  void _lookupPhrase(String phrase, String src) {
    ContextMenuController.removeAny();
    showQuickDef(context, ref, phrase, source: src);
  }

  void _tapToken(int global, String tok, Sentence s) {
    final a = _analysis;
    showAnalysisCard(
      context,
      ref,
      word: a != null && global < a.length ? a[global] : null,
      token: tok,
      sentence: s.en,
      source: 'reading:${_reading!.id}',
    );
  }

  /// Tap a sentence number: one rule only. Closed → open the translation and read the
  /// sentence. Open → close it and stop the reading if that sentence is being read.
  Future<void> _tapSentence(Sentence s) async {
    final p = _player;
    if (_openVi.contains(s.idx)) {
      setState(() => _openVi.remove(s.idx));
      if (p != null && p.isSpeaking(s.idx)) await p.stop();
    } else {
      setState(() => _openVi.add(s.idx));
      await p?.speakOnce(s.idx);
    }
  }

  Future<void> _speakOrStop(int idx) async {
    final p = _player;
    if (p == null) return;
    if (p.isSpeaking(idx)) {
      await p.stop();
    } else {
      await p.speakOnce(idx);
    }
  }

  void _cycleFontSize() => cycleFontScale(ref);

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    if (r == null) return const Scaffold(body: EmptyNote('Không có bài này.'));
    final db = ref.read(contentDbProvider);
    final theme = Theme.of(context);
    final g = context.g;
    final wide = context.isWide;
    final isUser = r.id >= userReadingBase;
    final (prev, next) = isUser ? (null, null) : db.neighbours(r);
    final src = 'reading:${r.id}';
    final section = isUser || r.sid < 0 ? null : db.section(r.sid);
    final siblings = section == null ? const <ReadingSummary>[] : db.readingsInSection(r.sid);
    final nextTitle = next == null ? null : siblings.where((x) => x.id == next).firstOrNull?.title;

    final article = Surface(
      padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 20, vertical: wide ? 32 : 20),
      child: SelectionArea(
        onSelectionChanged: _selectionChanged,
        contextMenuBuilder: (context, state) => AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            ContextMenuButtonItem(
              label: 'Tra từ điển',
              onPressed: () {
                final p = _phrase.value;
                if (p != null) _lookupPhrase(p, src);
              },
            ),
            ...state.contextMenuButtonItems,
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (r.img != null) ...[
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radiusCard),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: Image(image: isUser ? FileImage(File(r.img!)) : db.imageProvider(r.img!), fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: WordTapText(r.title, style: ReadingStyles.title(context), source: src)),
          const SizedBox(width: 8),
          RoundIconButton(icon: Icons.volume_up_outlined, tooltip: 'Đọc tựa đề', size: 36, onPressed: () => r.hasRealAudio && r.titleAudio ? _player?.playTitle() : ref.read(ttsProvider).speak(r.title)),
          if (r.page != null) ...[const SizedBox(width: 12), Text('Trang ${r.page}', style: theme.textTheme.bodySmall?.copyWith(color: g.fog))],
        ]),
        const SizedBox(height: 16),
        for (final para in r.paragraphs) ...[
          _Paragraph(
            sentences: para,
            source: src,
            speaking: _speaking,
            onTapNumber: _tapSentence,
            onToken: _analysis == null ? null : _tapToken,
            tokenStart: _tokenStart,
          ),
          if (_showAllVi && para.any((s) => s.vi.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(para.map((s) => s.vi).where((v) => v.isNotEmpty).join(' '), style: theme.textTheme.bodyLarge?.copyWith(color: g.slate, height: 1.6)),
            ),
          for (final s in para.where((s) => _openVi.contains(s.idx)))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LilacPanel(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 3), child: SoftBadge('Câu ${s.idx + 1}', background: g.card)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.en, style: ReadingStyles.line(context).copyWith(fontSize: 16)),
                      if (s.vi.isNotEmpty) Text(s.vi, style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  RoundIconButton(icon: _speaking == s.idx ? Icons.stop_circle_outlined : Icons.volume_up_outlined, tooltip: _speaking == s.idx ? 'Dừng' : 'Đọc lại câu', size: 36, onPressed: () => _speakOrStop(s.idx)),
                  RoundIconButton(icon: Icons.close, tooltip: 'Đóng', size: 36, onPressed: () => setState(() => _openVi.remove(s.idx))),
                ]),
              ),
            ),
          const SizedBox(height: 18),
        ],
      ]),
      ),
    );

    final toolbar = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      FilledButton.icon(onPressed: () => context.push('/readings/${r.id}/listen'), icon: const Icon(Icons.play_arrow_rounded, size: 20), label: const Text('Nghe toàn bài')),
      OutlinedButton.icon(onPressed: () => context.push('/readings/${r.id}/scramble'), icon: const Icon(Icons.shuffle, size: 18), label: const Text('Xếp từ')),
      OutlinedButton.icon(onPressed: () => context.push('/readings/${r.id}/dialog'), icon: const Icon(Icons.forum_outlined, size: 18), label: const Text('Đàm thoại')),
      OutlinedButton.icon(onPressed: () => context.push('/readings/${r.id}/dictation'), icon: const Icon(Icons.keyboard_alt_outlined, size: 18), label: const Text('Nghe viết')),
      if (r.hasRealAudio)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.graphic_eq, size: 16, color: g.slate),
            const SizedBox(width: 6),
            Text('Bài này có giọng đọc thật', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)),
          ]),
        ),
    ]);

    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [toolbar, const SizedBox(height: 16), article]);

    Widget body;
    if (wide && siblings.length > 1) {
      body = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 280,
          child: Surface(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Text(section!.title, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              for (final s in siblings)
                TocRow(
                  title: s.title,
                  selected: s.id == r.id,
                  audio: s.hasAudio,
                  onTap: s.id == r.id ? null : () => context.pushReplacement('/readings/${s.id}'),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(child: main),
      ]);
    } else {
      body = main;
    }

    return Scaffold(
      appBar: GrammarAppBar(
        crumbs: widget.fromAnalysis
            ? [const Crumb('Phân Tích Câu', '/analysis'), Crumb(r.title)]
            : [
                Crumb(isUser ? 'Bài Nhập Của Bạn' : 'Bài Đọc', isUser ? '/my-readings' : '/readings'),
                if (section != null) Crumb(section.title, '/readings/section/${section.sid}'),
                Crumb(r.title),
              ],
        helpSlug: 'bai-doc',
        actions: [
          if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Switch(value: _showAllVi, onChanged: (v) => setState(() => _showAllVi = v)),
                const SizedBox(width: 4),
                Text('Bản dịch', style: theme.textTheme.bodyMedium),
              ]),
            )
          else
            RoundIconButton(icon: Icons.translate, tooltip: _showAllVi ? 'Ẩn bản dịch' : 'Hiện bản dịch', active: _showAllVi, onPressed: () => setState(() => _showAllVi = !_showAllVi)),
          const SizedBox(width: 8),
          RoundIconButton(icon: Icons.format_size, tooltip: 'Cỡ chữ', onPressed: _cycleFontSize),
        ],
      ),
      body: RailListView(children: [body]),
      floatingActionButton: ValueListenableBuilder<String?>(
        valueListenable: _phrase,
        builder: (context, phrase, _) {
          if (phrase == null) return const SizedBox.shrink();
          final short = phrase.length > 36 ? '${phrase.substring(0, 34)}…' : phrase;
          final multi = phrase.contains(' ');
          return FloatingActionButton.extended(
            onPressed: () => _lookupPhrase(phrase, src),
            icon: const Icon(Icons.search),
            label: Text(multi ? 'Tra cụm “$short”' : 'Tra “$short”'),
          );
        },
      ),
      bottomNavigationBar: PrevNextBar(
        onPrev: prev == null ? null : () => context.pushReplacement('/readings/$prev'),
        onNext: next == null ? null : () => context.pushReplacement('/readings/$next'),
        nextLabel: nextTitle == null ? 'Bài kế' : 'Bài kế: $nextTitle',
        middle: wide ? Text(_analysis != null ? 'Chạm từ để xem phân tích và nghĩa · chạm số câu để dịch và nghe' : 'Chạm từ để tra · chạm số câu để dịch và nghe · bôi đen cụm từ để tra cụm', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)) : null,
      ),
    );
  }
}

const _scales = [0.9, 1.0, 1.15, 1.3, 1.45];

/// "Cỡ chữ": next text size of the reading pages (shared by Bài Đọc and Luyện Nói).
void cycleFontScale(WidgetRef ref) {
  final s = ref.read(settingsProvider);
  final i = _scales.indexWhere((x) => (x - s.fontScale).abs() < 0.01);
  ref.read(settingsProvider.notifier).setFontScale(_scales[(i + 1) % _scales.length]);
}

/// Row of the left nav of a reading-like page (the section's readings, a topic's dialogs).
class TocRow extends StatelessWidget {
  final String title;
  final bool selected;
  final bool audio;
  /// Extra mark at the end of the row (e.g. "has picked spots").
  final Widget? trailing;
  final VoidCallback? onTap;
  const TocRow({super.key, required this.title, required this.selected, this.audio = false, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final theme = Theme.of(context);
    return Material(
      color: selected ? g.lilac : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(color: selected ? g.iris : g.ink, fontWeight: selected ? FontWeight.w600 : FontWeight.w400))),
            if (audio) Icon(Icons.graphic_eq, size: 14, color: selected ? g.iris : g.fog),
            ?trailing,
          ]),
        ),
      ),
    );
  }
}

/// One paragraph as flowing text: sentence numbers (tappable) and tappable words; the
/// sentence being read gets a lilac background.
class _Paragraph extends ConsumerStatefulWidget {
  final List<Sentence> sentences;
  final String source;
  final int? speaking;
  final ValueChanged<Sentence> onTapNumber;
  /// Analysis mode: tap on a '|' token (global index, token, sentence).
  final void Function(int global, String tok, Sentence s)? onToken;
  final Map<int, int> tokenStart;
  const _Paragraph({required this.sentences, required this.source, required this.speaking, required this.onTapNumber, this.onToken, this.tokenStart = const {}});
  @override
  ConsumerState<_Paragraph> createState() => _ParagraphState();
}

class _ParagraphState extends ConsumerState<_Paragraph> {
  final List<GestureRecognizer> _recs = [];

  @override
  void dispose() {
    for (final r in _recs) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recs) {
      r.dispose();
    }
    _recs.clear();
    final g = context.g;
    final base = ReadingStyles.passage(context);
    final spans = <InlineSpan>[];
    for (var i = 0; i < widget.sentences.length; i++) {
      final s = widget.sentences[i];
      final hl = widget.speaking == s.idx;
      final style = hl ? base.copyWith(backgroundColor: g.lilac) : base;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.top,
        // Not part of a phrase selection (G7), and not read as text.
        child: SelectionContainer.disabled(
          child: _SentenceNumber(number: s.idx + 1, highlighted: hl, onTap: () => widget.onTapNumber(s)),
        ),
      ));
      if (widget.onToken != null && s.tokens != null) {
        // Analysed unit: one span per word group ("to see"); saved words red, family underlined.
        final saved = ref.watch(userWordsProvider).savedKeys;
        final family = ref.watch(familyKeysProvider);
        final toks = s.tokens!;
        final start = widget.tokenStart[s.idx] ?? 0;
        for (var j = 0; j < toks.length; j++) {
          final tok = toks[j];
          final rec = TapGestureRecognizer()..onTap = () => widget.onToken!(start + j, tok, s);
          _recs.add(rec);
          final key = searchKey(cleanToken(tok));
          final st = saved.contains(key) ? savedStyle(context, style) : inSavedFamily(key, family) ? familyStyle(context, style) : style;
          spans.add(TextSpan(text: tok, style: st, recognizer: rec));
          if (j < toks.length - 1) spans.add(TextSpan(text: ' ', style: style));
        }
      } else {
        spans.addAll(wordSpans(context, ref, s.en, base: style, recognizers: _recs, contextSentence: s.en, source: widget.source, fallbackVi: s.vi.isEmpty ? null : s.vi));
      }
      if (i < widget.sentences.length - 1) spans.add(TextSpan(text: ' ', style: style));
    }
    return Text.rich(TextSpan(children: spans));
  }
}

/// The small sentence number with a 24 px tap target: the box hangs from the top of the
/// line, the digit is centred in it (so it reads like a superscript yet the tint is even).
class _SentenceNumber extends StatelessWidget {
  final int number;
  final bool highlighted;
  final VoidCallback onTap;
  const _SentenceNumber({required this.number, required this.highlighted, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: g.lilac,
          // ConstrainedBox + Center(widthFactor/heightFactor), not Container(alignment:),
          // which would grow to the line width. The digit sits in the middle of the box so
          // the hover/ink tint is even around it.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text('$number', style: TextStyle(fontFamily: Tokens.uiFont, fontSize: 11, height: 1, fontWeight: FontWeight.w600, color: highlighted ? g.iris : g.fog)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small helper used by the practice pages: sentences eligible for practice.
List<Sentence> practiceSentences(Reading r, {int minWords = 2}) => r.sentences.where((s) => s.wordCount >= minWords).toList();

/// Red/underline marks are handled by WordTapText; this exposes the colours for the practice pages.
Color savedColor() => Marks.savedWord;
