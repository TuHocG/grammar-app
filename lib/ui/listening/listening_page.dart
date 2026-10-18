/// Luyện Nghe → Bài tập (docs/08 L1): Unit 1–20; the machine reads the English sentence,
/// the learner picks one of four Vietnamese sentences (shuffled); a point only when the
/// first pick is right; the English can be looked up after answering. Same layout as the
/// exercise runner: progress bar, question card, button row, map of the unit's sentences.
/// The sentence is played from the unit's real recording (`sound/<unit>.*`, shared with
/// the "Các Bài Âm Thanh Thực" reading; docs/08 L2), TTS only when a unit has none.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/content_db.dart';
import '../../data/media_locations.dart';
import '../../data/content_db_more.dart';
import '../../data/models.dart';
import '../../domain/sentence_player.dart';
import '../../platform/tts.dart';
import '../widgets/prev_next_keys.dart';
import '../widgets/question_layout.dart';
import '../widgets/word_tap_text.dart';
import '../../app/theme.dart';
import '../widgets/shell.dart';

class ListeningUnitsPage extends ConsumerWidget {
  const ListeningUnitsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    final theme = Theme.of(context);
    final g = context.g;
    final units = db.listeningUnits();
    final userDb = ref.read(userDbProvider);
    ref.watch(progressRevisionProvider);
    final last = int.tryParse(userDb.progress('listening', 'last') ?? '');

    // Same row layout as the Phân Tích Câu list: thumbnail, title, details, badge.
    Widget row({required Widget thumb, required String title, required String detail, bool current = false, required VoidCallback onTap}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Surface(
            onTap: onTap,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 72, height: 56, child: thumb)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: ReadingStyles.line(context).copyWith(fontSize: 16, fontWeight: current ? FontWeight.w600 : FontWeight.w400)),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: g.slate)),
                  ),
                ]),
              ),
              if (current) const SoftBadge('Đang luyện'),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: g.fog),
            ]),
          ),
        );

    return Scaffold(
      appBar: GrammarAppBar(
        crumbs: const [Crumb('Luyện Nghe')],
        helpSlug: 'luyen-nghe',
      ),
      body: RailListView(children: [
        Text('Luyện Nghe', style: theme.textTheme.headlineLarge),
        Text('${units.length} bài · nghe câu tiếng Anh, chọn câu dịch đúng', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
        const SizedBox(height: 16),
        row(
          thumb: const IconTile(Icons.movie_outlined, size: 56),
          title: 'Video có phụ đề song ngữ',
          detail: '210 tập: 3 bộ video bài học và 5 phim',
          onTap: () => context.push('/video'),
        ),
        const SizedBox(height: 8),
        for (final u in units)
          Builder(builder: (context) {
            final source = db.listeningReadingTitle(u);
            final img = source == null ? null : db.reading(source.id)?.img;
            final score = userDb.progress('listening', 'unit$u');
            return row(
              thumb: img != null
                  ? Image(image: db.imageProvider(img), fit: BoxFit.cover, errorBuilder: (_, _, _) => const IconTile(Icons.hearing_outlined, size: 56))
                  : const IconTile(Icons.hearing_outlined, size: 56),
              title: _unitTitle(u, source?.title),
              detail: '${db.listeningCount(u)} câu${score != null ? ' · $score' : ''}',
              current: u == last,
              onTap: () => context.push('/listening/$u'),
            );
          }),
      ]),
    );
  }
}

/// "Unit 5 · Learn To Request And Offer." — the reading whose recording the unit plays.
String _unitTitle(int unit, String? reading) => reading == null ? 'Unit $unit' : 'Unit $unit · $reading';

class _Result {
  bool graded = false;
  bool correct = false;
  bool lost = false;   // a wrong pick before the right one = no point
  int? picked;
  List<int>? order;    // shuffled option order, fixed once the item is shown
}

class ListeningUnitPage extends ConsumerStatefulWidget {
  final int unit;
  const ListeningUnitPage({super.key, required this.unit});
  @override
  ConsumerState<ListeningUnitPage> createState() => _ListeningUnitPageState();
}

class _ListeningUnitPageState extends ConsumerState<ListeningUnitPage> {
  late List<ListeningItem> _items;
  late List<_Result> _res;
  int _pos = 0;
  bool _finished = false;
  final _rnd = Random();
  /// Player over the unit's recording (null = no recording on disk → TTS).
  SentencePlayer? _player;
  Reading? _recording;
  /// The reading whose recording this unit plays (shown and linked in the map).
  ({int id, String title})? _source;
  late final TtsService _tts;
  /// Replaced by the next unit, which starts speaking before this page is disposed.
  bool _replaced = false;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    final db = ref.read(contentDbProvider);
    _items = db.listeningItems(widget.unit);
    ref.read(userDbProvider).setProgress('listening', 'last', '${widget.unit}');
    _res = List.generate(_items.length, (_) => _Result());
    _source = db.listeningReadingTitle(widget.unit);
    final r = db.listeningReading(widget.unit);
    final audio = r != null && r.hasRealAudio ? audioPathFor(ref, r.audio) : null;
    if (r != null && audio != null) {
      _recording = r;
      _player = SentencePlayer(tts: _tts, reading: r, audioPath: audio);
    }
    if (_items.isNotEmpty) _go(0);
  }

  @override
  void dispose() {
    _player?.stopTtsOnDispose = !_replaced;
    _player?.dispose();
    if (!_replaced) _tts.stop();
    super.dispose();
  }

  void _openUnit(int unit) {
    _player?.stop();
    _tts.stop();
    _replaced = true;
    context.pushReplacement('/listening/$unit');
  }

  _Result get _r => _res[_pos];
  int get _score => _res.where((r) => r.graded && r.correct).length;
  int get _done => _res.where((r) => r.graded).length;
  List<int> get _order => _r.order ??= (List.generate(_items[_pos].options.length, (i) => i)..shuffle(_rnd));

  void _go(int pos) {
    if (pos < 0 || pos >= _items.length) return;
    setState(() {
      _pos = pos;
      _finished = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  /// Sentence n of the unit = sentence n of the recording; TTS when it is out of range.
  Future<void> _speak() async {
    final it = _items[_pos];
    final p = _player;
    final idx = it.n - 1;
    if (p != null && idx >= 0 && idx < _recording!.sentences.length) {
      await p.stop();
      await p.speakOnce(idx);
    } else {
      await _tts.speak(it.en);
    }
  }

  void _pick(int optionIdx) {
    if (_r.graded) return;
    setState(() {
      _r.picked = optionIdx;
      if (optionIdx == 0) {
        _r.graded = true;
        _r.correct = !_r.lost;
      } else {
        _r.lost = true;
      }
    });
    if (_r.graded) ref.read(userDbProvider).setProgress('listening', 'unit${widget.unit}', 'đúng $_score/$_done');
  }

  void _next() {
    if (_pos < _items.length - 1) {
      _go(_pos + 1);
    } else {
      setState(() => _finished = true);
    }
  }

  void _restart() {
    setState(() {
      _res = List.generate(_items.length, (_) => _Result());
      _finished = false;
    });
    _go(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.g;
    final wide = context.isWide;
    final n = _items.length;
    final units = ref.read(contentDbProvider).listeningUnits();
    final nextUnit = units.where((u) => u > widget.unit).firstOrNull;
    final crumbs = [const Crumb('Luyện Nghe', '/listening'), Crumb('Unit ${widget.unit}')];
    if (n == 0) return Scaffold(appBar: GrammarAppBar(crumbs: crumbs), body: const EmptyNote('Không có câu.'));

    final map = Surface(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Unit ${widget.unit}', style: theme.textTheme.titleSmall)),
          Text('$n câu', style: theme.textTheme.bodySmall),
        ]),
        if (_source case final src?)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () => context.push('/readings/${src.id}'),
              icon: const Icon(Icons.menu_book_outlined, size: 16),
              label: Text('Bài đọc: ${src.title}', maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < n; i++) _dot(i, g, theme)]),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 4, children: [
          _legend(g.iris, g.iris, 'đúng', theme),
          _legend(Colors.transparent, g.slate, 'sai', theme),
          _legend(Colors.transparent, g.border, 'chưa làm', theme),
        ]),
        if (nextUnit != null) ...[
          const Divider(height: 24),
          TextButton(onPressed: () => _openUnit(nextUnit), child: Text('Unit $nextUnit →')),
        ],
      ]),
    );

    Widget question;
    if (_finished) {
      final pct = _done == 0 ? 0 : (_score * 100 / _done).round();
      question = Surface(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Text('$pct %', style: theme.textTheme.displayMedium?.copyWith(color: g.iris)),
          Text('Đúng $_score / $_done câu đã làm ($n câu)', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            FilledButton(onPressed: _restart, child: const Text('Làm lại')),
            if (nextUnit != null) OutlinedButton(onPressed: () => _openUnit(nextUnit), child: Text('Unit $nextUnit')),
            TextButton(onPressed: () => context.pop(), child: const Text('Đóng')),
          ]),
        ]),
      );
    } else {
      final it = _items[_pos];
      final order = _order;
      question = Surface(
        padding: EdgeInsets.all(wide ? 32 : 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Nghe câu tiếng Anh rồi chọn câu dịch đúng'),
          const SizedBox(height: 8),
          Row(children: [
            FilledButton.tonalIcon(onPressed: _speak, icon: const Icon(Icons.volume_up), label: const Text('Nghe lại')),
            if (_player != null) ...[const SizedBox(width: 8), SoftBadge('Giọng thật', color: g.slate, background: g.canvas)],
            const SizedBox(width: 12),
            Expanded(
              child: _r.graded
                  ? WordTapText(it.en, style: ReadingStyles.prompt(context), context: it.en, source: 'listening:${it.id}')
                  : Text('Câu tiếng Anh hiện ra sau khi bạn chọn đúng.', style: theme.textTheme.bodyMedium?.copyWith(color: g.fog)),
            ),
          ]),
          const SizedBox(height: 16),
          for (var k = 0; k < order.length; k++) _option(k, order[k], theme),
          const SizedBox(height: 20),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            OutlinedButton.icon(onPressed: _pos > 0 ? () => _go(_pos - 1) : null, icon: const Icon(Icons.chevron_left, size: 18), label: const Text('Back')),
            FilledButton(
              onPressed: _next,
              child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_pos == n - 1 ? 'Kết thúc' : 'Next'), const SizedBox(width: 4), const Icon(Icons.chevron_right, size: 18)]),
            ),
            if (!_r.graded) Text('Chọn sai lần đầu = không tính điểm', style: theme.textTheme.bodySmall?.copyWith(color: g.fog)),
          ]),
        ]),
      );
    }

    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: (_pos + 1) / n))),
        const SizedBox(width: 16),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Câu ', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)),
          TextSpan(text: '${_pos + 1}', style: theme.textTheme.titleSmall),
          TextSpan(text: ' / $n', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)),
        ])),
        // The mark's slot is always there so grading doesn't shrink the bar.
        const SizedBox(width: 12),
        SizedBox.square(
          dimension: 20,
          child: _r.graded ? Icon(_r.correct ? Icons.check_circle : Icons.cancel, size: 20, color: _r.correct ? g.iris : g.slate) : null,
        ),
      ]),
      const SizedBox(height: 16),
      question,
    ]);

    return Scaffold(
      appBar: GrammarAppBar(
        crumbs: crumbs,
        helpSlug: 'luyen-nghe',
        actions: [
          Text('Đúng $_score / $_done', style: theme.textTheme.titleSmall),
        ],
      ),
      body: PrevNextKeys(
        onPrev: _finished ? () => _go(n - 1) : (_pos > 0 ? () => _go(_pos - 1) : null),
        onNext: _finished ? null : _next,
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () { if (_r.graded) _next(); },
          const SingleActivator(LogicalKeyboardKey.space): _speak,
        },
        child: RailListView(children: [QuestionWithMap(question: main, map: map, wide: wide)]),
      ),
    );
  }

  Widget _dot(int i, GrammarColors g, ThemeData theme) {
    final r = _res[i];
    final cur = i == _pos && !_finished;
    Color fill = Colors.transparent, border = g.border, color = g.slate;
    if (r.graded && r.correct) {
      fill = g.iris;
      border = g.iris;
      color = theme.colorScheme.onPrimary;
    } else if (r.graded) {
      border = g.slate;
    }
    if (cur) {
      border = g.iris;
      if (!r.graded) color = g.iris;
    }
    return InkWell(
      onTap: () => _go(i),
      customBorder: const CircleBorder(),
      child: Container(
        decoration: cur ? BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: g.lilac, spreadRadius: 3)]) : null,
        child: LetterDot('${i + 1}', size: 28, fill: fill, border: border, color: color),
      ),
    );
  }

  Widget _legend(Color fill, Color border, String label, ThemeData theme) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: fill, border: Border.all(color: border))),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall),
      ]);

  Widget _option(int shown, int optionIdx, ThemeData theme) {
    final it = _items[_pos];
    final g = context.g;
    final r = _r;
    final letter = String.fromCharCode(97 + shown);
    final isAnswer = optionIdx == 0;
    Color bg = g.card, border = g.border, fg = g.ink, dotFill = Colors.transparent, dotBorder = g.border, dotColor = g.slate;
    Widget? dotChild;
    var weight = FontWeight.w400;
    var strike = false;
    if (r.graded) {
      if (isAnswer) {
        bg = g.lilac;
        border = g.iris;
        weight = FontWeight.w600;
        dotFill = g.iris;
        dotBorder = g.iris;
        dotChild = Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary);
      } else if (r.picked == optionIdx) {
        fg = g.slate;
        strike = true;
        dotFill = g.slate;
        dotBorder = g.slate;
        dotChild = Icon(Icons.close, size: 14, color: theme.colorScheme.onPrimary);
      } else {
        fg = g.fog;
        dotColor = g.fog;
      }
    } else if (r.picked == optionIdx) {
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
          onTap: r.graded ? null : () => _pick(optionIdx),
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
