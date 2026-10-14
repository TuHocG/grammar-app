/// Luyện Nói (docs/08 S1–S5): topics → dialogs → 4 A/B pairs; pick sentences for review
/// (Chọn Câu), review a topic (ôn tập), Đàm thoại from a dialog (machine says A, learner
/// answers B), Xếp từ on the pairs.
library;

import 'package:flutter/material.dart' hide Dialog;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/content_db_more.dart';
import '../../data/models.dart';
import '../../data/user_db.dart';
import '../../data/user_db_more.dart';
import '../../data/reading_loader.dart';
import '../../domain/sentence_player.dart';
import '../readings/dialog_practice_page.dart';
import '../readings/reading_page.dart' show TocRow, cycleFontScale;
import '../widgets/word_tap_text.dart';
import '../widgets/shell.dart';

/// Thumbnail from the CANBAN pool (the old app shows one at random on each page).
Widget _thumb(ContentDb db, int n, {double width = 56, double height = 56}) {
  final img = db.dialogPageImage(n);
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: width,
      height: height,
      child: img == null
          ? IconTile(Icons.record_voice_over_outlined, size: height)
          : Image(image: db.imageProvider(img), fit: BoxFit.cover, errorBuilder: (_, _, _) => IconTile(Icons.record_voice_over_outlined, size: height)),
    ),
  );
}

class DialogTopicsPage extends ConsumerWidget {
  const DialogTopicsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    final topics = db.dialogTopics();
    final userDb = ref.read(userDbProvider);
    ref.watch(progressRevisionProvider);
    final picks = userDb.dialogPickKeys();
    final lastId = int.tryParse(userDb.progress('dialog', 'last') ?? '');
    final last = lastId == null ? null : db.dialog(lastId);
    final theme = Theme.of(context);
    final g = context.g;
    return Scaffold(
      appBar: GrammarAppBar(
        crumbs: const [Crumb('Luyện Nói')],
        helpSlug: 'luyen-noi',
      ),
      body: RailListView(
        children: [
          Text('Luyện Nói', style: theme.textTheme.headlineLarge),
          Text('${topics.length} chủ đề · chạm từ để tra, chạm dòng để dịch · Chọn câu để ôn tập', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
          const SizedBox(height: 20),
          if (last != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Surface(
                onTap: () => context.push('/dialogs/${last.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(children: [
                  _thumb(db, last.id, width: 72, height: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Đang học · ${db.dialogTopic(last.sid)?.title ?? ''}', style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(last.title, style: ReadingStyles.line(context).copyWith(fontSize: 18, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (last.pairs.isNotEmpty) Text(last.pairs.first.a, style: theme.textTheme.bodySmall?.copyWith(color: g.slate), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  FilledButton(onPressed: () => context.push('/dialogs/${last.id}'), child: const Text('Tiếp tục')),
                ]),
              ),
            ),
          AutoGrid(
            minWidth: 260,
            children: [
              for (final t in topics)
                SetCard(
                  leading: _thumb(db, t.sid),
                  title: t.title,
                  subtitle: '${db.dialogsInTopic(t.sid).length} bài',
                  badge: picks.any((k) => _topicOf(db, k) == t.sid) ? 'đã chọn câu' : null,
                  onTap: () => context.push('/dialogs/topic/${t.sid}'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static final Map<int, int> _topicCache = {};
  int _topicOf(ContentDb db, String key) {
    final id = int.parse(key.split(':').first);
    return _topicCache.putIfAbsent(id, () => db.dialogTopicOf(id) ?? -1);
  }
}

class DialogListPage extends ConsumerStatefulWidget {
  final int sid;
  const DialogListPage({super.key, required this.sid});
  @override
  ConsumerState<DialogListPage> createState() => _DialogListPageState();
}

class _DialogListPageState extends ConsumerState<DialogListPage> {
  @override
  Widget build(BuildContext context) {
    final db = ref.read(contentDbProvider);
    final userDb = ref.read(userDbProvider);
    final topic = db.dialogTopic(widget.sid);
    final dialogs = db.dialogsInTopic(widget.sid);
    final picks = userDb.dialogPickKeys();
    final nPicked = picks.where((k) => dialogs.any((d) => k.startsWith('${d.id}:'))).length;
    userDb.setProgress('dialog', 'last_topic', '${widget.sid}');
    final theme = Theme.of(context);
    return Scaffold(
      appBar: GrammarAppBar(
        crumbs: [const Crumb('Luyện Nói', '/dialogs'), Crumb(topic?.title ?? '')],
        actions: [
          FilledButton.tonalIcon(
            icon: const Icon(Icons.replay),
            label: Text(nPicked >= 4 ? 'Ôn tập $nPicked cặp đã chọn' : 'Ôn tập cả chủ đề'),
            onPressed: () => context.push('/dialogs/topic/${widget.sid}/review'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView.builder(
        itemCount: dialogs.length,
        itemBuilder: (context, i) {
          final d = dialogs[i];
          final n = picks.where((k) => k.startsWith('${d.id}:')).length;
          return ListTile(
            leading: _thumb(db, d.id, width: 64, height: 48),
            title: Text(d.title),
            subtitle: Text(d.pairs.isEmpty ? '' : d.pairs.first.a, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
            trailing: n > 0 ? Text('$n ✓', style: TextStyle(color: Marks.savedWord)) : null,
            onTap: () => context.push('/dialogs/${d.id}'),
          );
        },
      ),
    );
  }
}

class DialogPage extends ConsumerStatefulWidget {
  final int id;
  const DialogPage({super.key, required this.id});
  @override
  ConsumerState<DialogPage> createState() => _DialogPageState();
}

/// One dialog laid out like a reading (docs/08 S1): breadcrumb, toolbar (Nghe toàn bài,
/// Xếp từ, Đàm thoại, Nghe viết, Đổi ảnh, Ôn tập), the topic's dialogs on the left, the
/// A/B lines in the article, Bài trước / Bài kế below. Practice pages get the dialog as a
/// reading (`dialogReadingBase + id`).
class _DialogPageState extends ConsumerState<DialogPage> {
  bool _showVi = false;
  final Set<int> _openVi = {};
  int _imgShift = 0;
  SentencePlayer? _player;
  int? _speaking;

  int get _rid => dialogReadingBase + widget.id;

  @override
  void initState() {
    super.initState();
    final r = loadReading(ref, _rid);
    if (r != null) {
      _player = SentencePlayer(tts: ref.read(ttsProvider), reading: r)
        ..addListener(() {
          if (mounted) setState(() => _speaking = _player!.state == PlayerState.playing ? _player!.index : null);
        });
    }
    final sid = ref.read(contentDbProvider).dialogTopicOf(widget.id);
    ref.read(userDbProvider).setProgress('dialog', 'last', '${widget.id}');
    if (sid != null) ref.read(userDbProvider).setProgress('dialog', 'last_topic', '$sid');
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  /// One tap on a line: read it and show its translation (which stays); tap again while
  /// it is being read → stop.
  Future<void> _tapLine(int slot) async {
    final p = _player;
    setState(() => _openVi.add(slot));
    if (p == null) return;
    if (p.isSpeaking(slot)) {
      await p.stop();
    } else {
      await p.speakOnce(slot);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(contentDbProvider);
    final userDb = ref.read(userDbProvider);
    final d = db.dialog(widget.id);
    if (d == null) return const Scaffold(body: EmptyNote('Không có bài này.'));
    final picks = userDb.dialogPickKeys();
    final theme = Theme.of(context);
    final g = context.g;
    final wide = context.isWide;
    final topic = db.dialogTopic(d.sid);
    final all = db.dialogsInTopic(d.sid);
    final i = all.indexWhere((x) => x.id == d.id);
    final prev = i > 0 ? all[i - 1] : null;
    final next = i >= 0 && i < all.length - 1 ? all[i + 1] : null;
    final nTopicPicks = picks.where((k) => all.any((x) => k.startsWith('${x.id}:'))).length;
    final src = 'dialog:${d.id}';
    final img = db.dialogPageImage(d.id + _imgShift);

    Widget line(String en, String vi, int pairIdx, String who) {
      final slot = pairIdx * 2 + (who == 'A' ? 0 : 1);
      final open = _showVi || _openVi.contains(slot);
      final hl = _speaking == slot;
      return InkWell(
        onTap: () => _tapLine(slot),
        onLongPress: () => _tapLine(slot),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(color: hl ? g.lilac : null, borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 32,
              child: Text('$who:', style: ReadingStyles.passage(context).copyWith(fontWeight: FontWeight.w600, color: who == 'A' ? g.iris : g.slate)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                WordTapText(en, style: ReadingStyles.passage(context), context: en, source: src),
                if (open && vi.isNotEmpty) Text(vi, style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
              ]),
            ),
          ]),
        ),
      );
    }

    final article = Surface(
      padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 20, vertical: wide ? 32 : 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (img != null) ...[
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radiusCard),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: Image(image: db.imageProvider(img), fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(d.title, style: ReadingStyles.title(context)),
        const SizedBox(height: 16),
        for (var p = 0; p < d.pairs.length; p++) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(children: [line(d.pairs[p].a, d.pairs[p].avi, p, 'A'), line(d.pairs[p].b, d.pairs[p].bvi, p, 'B')])),
            Builder(builder: (context) {
              final picked = picks.contains('${d.id}:$p');
              return IconButton(
                tooltip: picked ? 'Bỏ chọn cặp câu này' : 'Chọn cặp câu này để Ôn tập',
                icon: Icon(picked ? Icons.bookmark : Icons.bookmark_border, color: picked ? g.savedWord : g.fog),
                onPressed: () => setState(() => userDb.setDialogPick(d.id, p, !picked)),
              );
            }),
          ]),
          if (p < d.pairs.length - 1) Divider(height: 16, color: g.border),
        ],
      ]),
    );

    final review = nTopicPicks >= 4 ? 'Ôn tập $nTopicPicks cặp đã chọn' : 'Ôn tập cả chủ đề';
    final toolbar = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      FilledButton.icon(onPressed: () => context.push('/readings/$_rid/listen'), icon: const Icon(Icons.play_arrow_rounded, size: 20), label: const Text('Nghe toàn bài')),
      OutlinedButton.icon(onPressed: () => context.push('/readings/$_rid/scramble'), icon: const Icon(Icons.shuffle, size: 18), label: const Text('Xếp từ')),
      OutlinedButton.icon(onPressed: () => context.push('/dialogs/${d.id}/practice'), icon: const Icon(Icons.forum_outlined, size: 18), label: const Text('Đàm thoại')),
      OutlinedButton.icon(onPressed: () => context.push('/readings/$_rid/dictation'), icon: const Icon(Icons.keyboard_alt_outlined, size: 18), label: const Text('Nghe viết')),
      OutlinedButton.icon(onPressed: () => setState(() => _imgShift++), icon: const Icon(Icons.image_outlined, size: 18), label: const Text('Đổi ảnh')),
      FilledButton.tonalIcon(onPressed: () => context.push('/dialogs/topic/${d.sid}/review'), icon: const Icon(Icons.replay, size: 18), label: Text(review)),
    ]);

    // What the bookmarks are for (docs/08 S3–S4), right under the Ôn tập button.
    final reviewNote = Text(
      nTopicPicks == 0
          ? 'Bấm 🔖 bên phải một cặp câu để chọn nó. Ôn tập: máy đọc câu A, bạn đáp câu B — từ 4 cặp đã chọn trở lên chỉ ôn các cặp đó, chưa đủ thì ôn cả chủ đề.'
          : nTopicPicks < 4
              ? 'Đã chọn $nTopicPicks cặp trong chủ đề này; chọn đủ 4 cặp thì Ôn tập chỉ luyện các cặp đã chọn (máy đọc A, bạn đáp B).'
              : 'Đã chọn $nTopicPicks cặp trong chủ đề này: Ôn tập luyện các cặp đó (máy đọc A, bạn đáp B).',
      style: theme.textTheme.bodySmall?.copyWith(color: g.slate),
    );

    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [toolbar, const SizedBox(height: 8), reviewNote, const SizedBox(height: 16), article]);

    Widget body;
    if (wide && all.length > 1) {
      body = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 280,
          child: Surface(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Text(topic?.title ?? '', style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              for (final x in all)
                TocRow(
                  title: x.title,
                  selected: x.id == d.id,
                  audio: false,
                  onTap: x.id == d.id ? null : () => context.pushReplacement('/dialogs/${x.id}'),
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
        crumbs: [
          const Crumb('Luyện Nói', '/dialogs'),
          if (topic != null) Crumb(topic.title, '/dialogs/topic/${topic.sid}'),
          Crumb(d.title),
        ],
        helpSlug: 'luyen-noi',
        actions: [
          if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Switch(value: _showVi, onChanged: (v) => setState(() => _showVi = v)),
                const SizedBox(width: 4),
                Text('Bản dịch', style: theme.textTheme.bodyMedium),
              ]),
            )
          else
            RoundIconButton(icon: Icons.translate, tooltip: _showVi ? 'Ẩn bản dịch' : 'Hiện bản dịch', active: _showVi, onPressed: () => setState(() => _showVi = !_showVi)),
          const SizedBox(width: 8),
          RoundIconButton(icon: Icons.format_size, tooltip: 'Cỡ chữ', onPressed: () => cycleFontScale(ref)),
        ],
      ),
      body: RailListView(children: [body]),
      bottomNavigationBar: PrevNextBar(
        onPrev: prev == null ? null : () => context.pushReplacement('/dialogs/${prev.id}'),
        onNext: next == null ? null : () => context.pushReplacement('/dialogs/${next.id}'),
        prevLabel: prev == null ? 'Bài trước' : 'Bài trước: ${prev.title}',
        nextLabel: next == null ? 'Bài kế' : 'Bài kế: ${next.title}',
        middle: wide ? Text('Chạm từ để tra · chạm vào dòng để nghe và xem dịch', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)) : null,
      ),
    );
  }
}

/// Đàm thoại from one dialog: the machine says A, the learner answers B.
DialogPracticePage dialogPractice(ContentDb db, Dialog d) => DialogPracticePage(
      title: d.title,
      items: [for (final p in d.pairs) PracticeItem(prompt: p.a, answer: p.b, speakPrompt: true)],
      images: db.dialogImages(),
      source: 'dialog:${d.id}',
    );

/// Ôn tập: the picked sentences of a topic (fewer than 4 → the whole topic), as in the old app.
DialogPracticePage topicReview(ContentDb db, UserDb userDb, int sid) {
  final dialogs = db.dialogsInTopic(sid);
  final byId = {for (final d in dialogs) d.id: d};
  final picks = userDb.dialogPicks(dialogs.map((d) => d.id).toList());
  final items = <PracticeItem>[];
  if (picks.length >= 4) {
    for (final (id, idx) in picks) {
      final d = byId[id];
      if (d != null && idx < d.pairs.length) items.add(PracticeItem(prompt: d.pairs[idx].a, answer: d.pairs[idx].b, speakPrompt: true));
    }
  } else {
    for (final d in dialogs) {
      for (final p in d.pairs) {
        items.add(PracticeItem(prompt: p.a, answer: p.b, speakPrompt: true));
      }
    }
  }
  return DialogPracticePage(title: 'Ôn tập · ${db.dialogTopic(sid)?.title ?? ''}', items: items, images: db.dialogImages(), source: 'dialog-topic:$sid');
}

