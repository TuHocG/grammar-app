/// Văn Phạm (docs/08 P1–P5): chapters / lessons, lesson body, exercises per lesson and mixed
/// exercises for several selected lessons. Wide screens: chapter tree on the left, lesson on
/// the right; narrow: chapter list → lessons sheet → lesson page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/models.dart';
import '../widgets/mark_text.dart';
import '../widgets/shell.dart';

final grammarLessonsProvider = Provider<List<GrammarLesson>>((ref) => ref.watch(contentDbProvider).grammarLessons());

class _Chapter {
  final GrammarLesson head;
  final List<GrammarLesson> lessons = [];
  _Chapter(this.head);
}

List<_Chapter> _chapters(List<GrammarLesson> all) {
  final out = <_Chapter>[];
  for (final l in all) {
    if (l.chapter || out.isEmpty) {
      out.add(_Chapter(l));
      if (!l.chapter) out.last.lessons.add(l);
    } else {
      out.last.lessons.add(l);
    }
  }
  return out;
}

_Chapter? _chapterOf(List<_Chapter> chapters, int ref) => chapters.where((c) => c.head.ref == ref || c.lessons.any((l) => l.ref == ref)).firstOrNull;

/// Chapter tree: chapter rows expand to their lessons; the current lesson is highlighted.
class _ChapterTree extends StatelessWidget {
  final List<_Chapter> chapters;
  final int openChapter;
  final int? currentRef;
  final String filter;
  final ValueChanged<int> onOpenChapter;
  final ValueChanged<GrammarLesson> onLesson;
  final bool selectMode;
  final Set<int> picked;
  final ValueChanged<int>? onTogglePick;
  const _ChapterTree({
    required this.chapters,
    required this.openChapter,
    required this.currentRef,
    required this.filter,
    required this.onOpenChapter,
    required this.onLesson,
    this.selectMode = false,
    this.picked = const {},
    this.onTogglePick,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final theme = Theme.of(context);
    final f = filter.toLowerCase();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < chapters.length; i++) ...[
        if (f.isEmpty || chapters[i].head.title.toLowerCase().contains(f) || chapters[i].lessons.any((l) => l.title.toLowerCase().contains(f)))
          InkWell(
            onTap: () => onOpenChapter(i),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(children: [
                Icon(i == openChapter || f.isNotEmpty ? Icons.expand_more : Icons.chevron_right, size: 16, color: g.slate),
                const SizedBox(width: 8),
                Expanded(child: Text(chapters[i].head.title, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                Text('${chapters[i].lessons.length}', style: theme.textTheme.bodySmall?.copyWith(color: g.fog)),
              ]),
            ),
          ),
        if (i == openChapter || f.isNotEmpty) ...[
          if (chapters[i].head.chapter && f.isEmpty)
            _LessonRow(lesson: chapters[i].head, label: 'Giới thiệu chương', selected: currentRef == chapters[i].head.ref, onTap: () => onLesson(chapters[i].head)),
          for (final l in chapters[i].lessons)
            if (f.isEmpty || l.title.toLowerCase().contains(f))
              _LessonRow(
                lesson: l,
                selected: currentRef == l.ref,
                selectMode: selectMode,
                picked: picked.contains(l.ref),
                onTap: selectMode ? (l.drills ? () => onTogglePick?.call(l.ref) : null) : () => onLesson(l),
              ),
        ],
      ],
    ]);
  }
}

class _LessonRow extends StatelessWidget {
  final GrammarLesson lesson;
  final String? label;
  final bool selected;
  final bool selectMode;
  final bool picked;
  final VoidCallback? onTap;
  const _LessonRow({required this.lesson, this.label, required this.selected, this.selectMode = false, this.picked = false, this.onTap});
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
          padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
          child: Row(children: [
            if (selectMode) ...[
              Icon(picked ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: lesson.drills ? (picked ? g.iris : g.fog) : g.border),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label ?? lesson.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: onTap == null && selectMode ? g.fog : (selected ? g.iris : g.ink), fontWeight: selected ? FontWeight.w600 : FontWeight.w400, fontStyle: label != null ? FontStyle.italic : null),
              ),
            ),
            if (lesson.drills) SoftBadge('BT', background: selected ? g.card : null),
          ]),
        ),
      ),
    );
  }
}

class GrammarPage extends ConsumerStatefulWidget {
  const GrammarPage({super.key});
  @override
  ConsumerState<GrammarPage> createState() => _GrammarPageState();
}

class _GrammarPageState extends ConsumerState<GrammarPage> {
  int _chapter = 0;
  bool _selectMode = false;
  final Set<int> _picked = {};
  String _filter = '';
  int? _currentRef; // wide screens: lesson open on the right

  @override
  void initState() {
    super.initState();
    final userDb = ref.read(userDbProvider);
    _chapter = int.tryParse(userDb.progress('grammar', 'chapter') ?? '') ?? 0;
    _currentRef = int.tryParse(userDb.progress('grammar', 'last_lesson') ?? '');
  }

  void _openChapter(int i) {
    setState(() => _chapter = _chapter == i ? -1 : i);
    ref.read(userDbProvider).setProgress('grammar', 'chapter', '$i');
  }

  void _openLesson(GrammarLesson l) {
    if (context.isWide) {
      setState(() => _currentRef = l.ref);
      ref.read(userDbProvider).setProgress('grammar', 'last_lesson', '${l.ref}');
    } else {
      context.push('/grammar/${l.ref}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(grammarLessonsProvider);
    final chapters = _chapters(all);
    if (_chapter >= chapters.length) _chapter = 0;
    final theme = Theme.of(context);
    final g = context.g;
    final wide = context.isWide;
    final db = ref.read(contentDbProvider);
    if (wide && _currentRef != null && _chapter >= 0 && _chapterOf(chapters, _currentRef!) != chapters[_chapter] && _filter.isEmpty) {
      // keep the open chapter in sync with the lesson shown
      final c = _chapterOf(chapters, _currentRef!);
      if (c != null) _chapter = chapters.indexOf(c);
    }

    final tree = Surface(
      padding: const EdgeInsets.all(8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: SearchPill(hint: 'Tìm bài văn phạm', onChanged: (v) => setState(() => _filter = v.trim())),
        ),
        _ChapterTree(
          chapters: chapters,
          openChapter: _chapter,
          currentRef: wide ? _currentRef : null,
          filter: _filter,
          onOpenChapter: _openChapter,
          onLesson: _openLesson,
          selectMode: _selectMode,
          picked: _picked,
          onTogglePick: (r) => setState(() => _picked.contains(r) ? _picked.remove(r) : _picked.add(r)),
        ),
      ]),
    );

    final lesson = wide && _currentRef != null ? db.grammarLesson(_currentRef!) : null;

    return Scaffold(
      appBar: GrammarAppBar(
        crumbs: const [Crumb('Văn Phạm')],
        actions: [
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _selectMode = !_selectMode;
              _picked.clear();
            }),
            icon: Icon(_selectMode ? Icons.close : Icons.checklist, size: 18),
            label: Text(_selectMode ? 'Thoát chọn' : 'Chọn nhiều bài'),
          ),
          const SizedBox(width: 8),
          RoundIconButton(icon: Icons.help_outline, tooltip: 'Hướng dẫn', onPressed: () => context.push('/help/7')),
        ],
      ),
      body: RailListView(
        children: [
          if (_selectMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LilacPanel(
                child: Row(children: [
                  Icon(Icons.checklist, color: g.iris),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Chọn các bài có BT rồi bấm "Làm bài tập trộn": câu hỏi của những bài đó được trộn chung.', style: theme.textTheme.bodyMedium?.copyWith(color: g.indigo))),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _picked.isEmpty ? null : () => context.push('/exercises/lessons/${_picked.join(',')}'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text('Làm bài tập trộn (${_picked.length})'),
                  ),
                ]),
              ),
            ),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 320, child: tree),
              const SizedBox(width: 24),
              Expanded(
                child: lesson == null
                    ? Surface(
                        padding: const EdgeInsets.all(40),
                        child: Column(children: [
                          Icon(Icons.account_tree_outlined, size: 40, color: g.fog),
                          const SizedBox(height: 12),
                          Text('Chọn một bài bên trái.', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
                          Text('${all.length} mục · bài có nhãn BT có bài tập đi kèm', style: theme.textTheme.bodySmall),
                        ]),
                      )
                    : LessonCard(lesson: lesson, all: all, onNavigate: (r) => setState(() => _currentRef = r)),
              ),
            ])
          else
            tree,
        ],
      ),
    );
  }
}

class GrammarLessonPage extends ConsumerWidget {
  final int ref;
  const GrammarLessonPage({super.key, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef wref) {
    final db = wref.read(contentDbProvider);
    final l = db.grammarLesson(ref);
    if (l == null) return const Scaffold(body: EmptyNote('Không có bài này.'));
    wref.read(userDbProvider).setProgress('grammar', 'last_lesson', '$ref');
    final all = wref.read(grammarLessonsProvider);
    final chapter = _chapterOf(_chapters(all), ref);
    return Scaffold(
      appBar: GrammarAppBar(crumbs: [
        const Crumb('Văn Phạm', '/grammar'),
        if (chapter != null && chapter.head.ref != ref) Crumb(chapter.head.title, '/grammar'),
        Crumb(l.title),
      ]),
      body: RailListView(maxWidth: 960, children: [LessonCard(lesson: l, all: all, onNavigate: (r) => context.pushReplacement('/grammar/$r'))]),
    );
  }
}

/// Lesson card: eyebrow (chapter · position), title, "Làm Bài Tập" pill, body, prev/next.
class LessonCard extends StatelessWidget {
  final GrammarLesson lesson;
  final List<GrammarLesson> all;
  final ValueChanged<int> onNavigate;
  const LessonCard({super.key, required this.lesson, required this.all, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.g;
    final i = all.indexWhere((x) => x.ref == lesson.ref);
    final prev = i > 0 ? all[i - 1] : null;
    final next = i >= 0 && i < all.length - 1 ? all[i + 1] : null;
    final chapter = _chapterOf(_chapters(all), lesson.ref);
    final pos = chapter == null ? null : chapter.lessons.indexOf(lesson) + 1;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Surface(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 40, vertical: narrow ? 24 : 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.start, runSpacing: 12, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow(chapter == null || lesson.chapter ? 'Bài ${lesson.ref}' : '${chapter.head.title} · bài $pos/${chapter.lessons.length}'),
            const SizedBox(height: 2),
            Text(lesson.title, style: theme.textTheme.headlineLarge),
          ]),
          if (lesson.drills)
            FilledButton.icon(
              onPressed: () => context.push('/exercises/lessons/${lesson.ref}'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Làm Bài Tập'),
            ),
        ]),
        const SizedBox(height: 20),
        MarkText(lesson.body, source: 'grammar:${lesson.ref}', onLessonRef: (n) => showLessonSheet(context, n)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: g.border))),
          child: Row(children: [
            Flexible(
              child: OutlinedButton.icon(
                onPressed: prev == null ? null : () => onNavigate(prev.ref),
                icon: const Icon(Icons.chevron_left, size: 18),
                label: Text(prev?.title ?? 'Bài trước', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const Spacer(),
            Flexible(
              child: OutlinedButton(
                onPressed: next == null ? null : () => onNavigate(next.ref),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text(next?.title ?? 'Bài kế', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Kept for callers that embed a lesson body.
class LessonBody extends StatelessWidget {
  final GrammarLesson lesson;
  const LessonBody({super.key, required this.lesson});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: MarkText(lesson.body, source: 'grammar:${lesson.ref}', onLessonRef: (n) => showLessonSheet(context, n)),
      );
}

/// Opens a grammar lesson in a sheet on top of the current screen (links from exercises).
Future<void> showLessonSheet(BuildContext context, int ref) {
  final db = ProviderScope.containerOf(context).read(contentDbProvider);
  final l = db.grammarLesson(ref);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 900),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, ctl) => l == null
          ? const EmptyNote('Không có bài này.')
          : ListView(
              controller: ctl,
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              children: [
                Row(children: [
                  Expanded(child: Text(l.title, style: Theme.of(context).textTheme.headlineSmall)),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/grammar/$ref');
                    },
                    child: const Text('Mở trang bài'),
                  ),
                ]),
                const SizedBox(height: 12),
                MarkText(l.body, source: 'grammar:$ref', onLessonRef: (n) => showLessonSheet(context, n)),
              ],
            ),
    ),
  );
}
