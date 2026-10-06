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
import '../readings/dialog_practice_page.dart';
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
          : Image.file(db.mediaFile(img), fit: BoxFit.cover, errorBuilder: (_, _, _) => IconTile(Icons.record_voice_over_outlined, size: height)),
    ),
  );
}

class DialogTopicsPage extends ConsumerWidget {
  const DialogTopicsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    final topics = db.dialogTopics();
    final picks = ref.read(userDbProvider).dialogPickKeys();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: GrammarAppBar(
        title: const Text('Luyện Nói'),
        actions: [IconButton(tooltip: 'Hướng dẫn', icon: const Icon(Icons.help_outline), onPressed: () => context.push('/help/6'))],
      ),
      body: RailListView(
        children: [
          Text('Luyện Nói', style: theme.textTheme.headlineLarge),
          Text('${topics.length} chủ đề · chạm từ để tra, chạm dòng để dịch · Chọn câu để ôn tập', style: theme.textTheme.bodyLarge?.copyWith(color: context.g.slate)),
          const SizedBox(height: 20),
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
        title: Text(topic?.title ?? 'Luyện Nói'),
        actions: [
          FilledButton.tonalIcon(
            icon: const Icon(Icons.replay),
            label: Text(nPicked >= 4 ? 'Ôn tập ($nPicked câu)' : 'Ôn tập cả chủ đề'),
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

class _DialogPageState extends ConsumerState<DialogPage> {
  bool _showVi = false;
  final Set<int> _openVi = {};

  @override
  Widget build(BuildContext context) {
    final db = ref.read(contentDbProvider);
    final userDb = ref.read(userDbProvider);
    final d = db.dialog(widget.id);
    if (d == null) return const Scaffold(body: Center(child: Text('Không có bài này.')));
    final picks = userDb.dialogPickKeys();
    final tts = ref.read(ttsProvider);
    final theme = Theme.of(context);
    final all = db.dialogsInTopic(d.sid);
    final i = all.indexWhere((x) => x.id == d.id);
    final prev = i > 0 ? all[i - 1].id : null;
    final next = i < all.length - 1 ? all[i + 1].id : null;
    final src = 'dialog:${d.id}';

    Widget line(String en, String vi, int pairIdx, String who) {
      final key = '${d.id}:$pairIdx';
      final picked = picks.contains(key);
      final slot = pairIdx * 2 + (who == 'A' ? 0 : 1);
      final open = _showVi || _openVi.contains(slot);
      // One tap on the line (outside a word): read it and show its translation, which stays.
      void speakAndShow() {
        setState(() => _openVi.add(slot));
        tts.speak(en);
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 24, child: Text(who, style: theme.textTheme.labelLarge?.copyWith(color: who == 'A' ? theme.colorScheme.primary : theme.colorScheme.tertiary))),
          Expanded(
            child: InkWell(
              onTap: speakAndShow,
              onLongPress: speakAndShow,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: WordTapText(en, style: theme.textTheme.bodyLarge, context: en, source: src)),
                    const SizedBox(width: 8),
                    Icon(Icons.volume_up_outlined, size: 16, color: open ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
                  ]),
                  if (open) Text(vi, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ]),
              ),
            ),
          ),
          if (who == 'A')
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: picked ? 'Bỏ chọn câu' : 'Chọn câu để ôn tập',
              icon: Icon(picked ? Icons.bookmark : Icons.bookmark_border, size: 18, color: picked ? Marks.savedWord : null),
              onPressed: () { userDb.setDialogPick(d.id, pairIdx, !picked); setState(() {}); },
            )
          else
            const SizedBox(width: 40),
        ]),
      );
    }

    return Scaffold(
      appBar: GrammarAppBar(
        title: Text('${db.dialogTopic(d.sid)?.title ?? ''} · ${d.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'Bản dịch', icon: Icon(_showVi ? Icons.translate : Icons.translate_outlined), onPressed: () => setState(() => _showVi = !_showVi)),
          IconButton(tooltip: 'Hướng dẫn', icon: const Icon(Icons.help_outline), onPressed: () => context.push('/help/24')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (db.dialogPageImage(d.id) case final img?) ...[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusCard),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Image.file(db.mediaFile(img), fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (var p = 0; p < d.pairs.length; p++) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                child: Column(children: [line(d.pairs[p].a, d.pairs[p].avi, p, 'A'), line(d.pairs[p].b, d.pairs[p].bvi, p, 'B')]),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text('Chạm từ để tra; chạm vào dòng (ngoài chữ) để nghe và xem dịch; đánh dấu câu để ôn tập.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: prev == null ? null : () => context.pushReplacement('/dialogs/$prev')),
            Expanded(
              child: Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
                ActionChip(avatar: const Icon(Icons.forum_outlined, size: 18), label: const Text('Đàm thoại'), onPressed: () => context.push('/dialogs/${d.id}/practice')),
                ActionChip(avatar: const Icon(Icons.play_circle_outline, size: 18), label: const Text('Nghe cả bài'), onPressed: () => _playAll(d, tts)),
              ]),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: next == null ? null : () => context.pushReplacement('/dialogs/$next')),
          ]),
        ),
      ),
    );
  }

  Future<void> _playAll(Dialog d, dynamic tts) async {
    for (final p in d.pairs) {
      if (!mounted) return;
      await tts.speak(p.a);
      if (!mounted) return;
      await tts.speak(p.b);
    }
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

