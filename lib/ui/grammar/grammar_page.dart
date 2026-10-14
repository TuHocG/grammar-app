/// Văn Phạm (docs/08 P1–P5): chapters / lessons, lesson body, exercises per lesson and mixed
/// exercises for several selected lessons. Wide screens: chapter tree on the left, lesson on
/// the right; narrow: chapter list → lessons sheet → lesson page. Ngữ Pháp Của Bạn (N4) is the
/// same page showing only the lessons the user bookmarked.
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
  bool intro = true;  // the "Giới thiệu chương" row (head of a real chapter)
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

/// The chapters that hold a bookmarked lesson, with only those lessons; a chapter intro is
/// kept when the intro itself is bookmarked.
List<_Chapter> _markedChapters(List<GrammarLesson> all, Set<int> marks) => [
      for (final c in _chapters(all))
        if (c.lessons.any((l) => marks.contains(l.ref)) || (c.head.chapter && marks.contains(c.head.ref)))
          _Chapter(c.head)
            ..intro = c.head.chapter && marks.contains(c.head.ref)
            ..lessons.addAll(c.lessons.where((l) => marks.contains(l.ref))),
    ];

/// Bookmarked lessons in book order, for Bài trước / Bài kế on Ngữ Pháp Của Bạn.
List<GrammarLesson> _markedSequence(List<GrammarLesson> all, Set<int> marks) => [for (final l in all) if (marks.contains(l.ref)) l];

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
  final Set<int> marks;
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
    this.marks = const {},
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
          if (chapters[i].head.chapter && chapters[i].intro && f.isEmpty)
            _LessonRow(lesson: chapters[i].head, label: 'Giới thiệu chương', selected: currentRef == chapters[i].head.ref, marked: marks.contains(chapters[i].head.ref), onTap: () => onLesson(chapters[i].head)),
          for (final l in chapters[i].lessons)
            if (f.isEmpty || l.title.toLowerCase().contains(f))
              _LessonRow(
                lesson: l,
                selected: currentRef == l.ref,
                selectMode: selectMode,
                picked: picked.contains(l.ref),
                marked: marks.contains(l.ref),
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
  final bool marked;
  final VoidCallback? onTap;
  const _LessonRow({required this.lesson, this.label, required this.selected, this.selectMode = false, this.picked = false, this.marked = false, this.onTap});
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
          // The bookmark sits in the left gutter, so titles stay aligned whether marked or not.
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          child: Row(children: [
            SizedBox(width: 20, child: marked ? Icon(Icons.bookmark, size: 14, color: g.iris) : null),
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
  /// Ngữ Pháp Của Bạn: only the bookmarked lessons.
  final bool savedOnly;
  const GrammarPage({super.key, this.savedOnly = false});
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
    _chapter = int.tryParse(userDb.progress('grammar', _chapterKey) ?? '') ?? 0;
    _currentRef = int.tryParse(userDb.progress('grammar', 'last_lesson') ?? '');
    if (widget.savedOnly && !ref.read(grammarMarksProvider).contains(_currentRef)) _currentRef = null;
  }

  // The two pages have different chapter lists, so each remembers its own open chapter.
  String get _chapterKey => widget.savedOnly ? 'saved_chapter' : 'chapter';

  List<_Chapter> _shown(List<GrammarLesson> all) => widget.savedOnly ? _markedChapters(all, ref.read(grammarMarksProvider)) : _chapters(all);

  void _openChapter(int i) {
    setState(() => _chapter = _chapter == i ? -1 : i);
    ref.read(userDbProvider).setProgress('grammar', _chapterKey, '$i');
  }

  void _openLesson(GrammarLesson l) {
    if (context.isWide) {
      // Open the lesson's chapter too (the tree keeps the chapter the user expands otherwise).
      final chapters = _shown(ref.read(grammarLessonsProvider));
      final c = _chapterOf(chapters, l.ref);
      setState(() {
        _currentRef = l.ref;
        if (c != null) _chapter = chapters.indexOf(c);
      });
      ref.read(userDbProvider).setProgress('grammar', 'last_lesson', '${l.ref}');
    } else {
      context.push('/grammar/${l.ref}${widget.savedOnly ? '?saved=1' : ''}');
    }
  }

  void _toggleSelect() => setState(() {
        _selectMode = !_selectMode;
        _picked.clear();
      });

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(grammarLessonsProvider);
    final marks = ref.watch(grammarMarksProvider);
    final saved = widget.savedOnly;
    final chapters = _shown(all);
    if (_chapter >= chapters.length) _chapter = 0;
    final theme = Theme.of(context);
    final g = context.g;
    final wide = context.isWide;
    final db = ref.read(contentDbProvider);

    final tree = Surface(
      padding: const EdgeInsets.all(8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: SearchPill(hint: saved ? 'Tìm trong bài đã lưu' : 'Tìm bài văn phạm', onChanged: (v) => setState(() => _filter = v.trim())),
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
          marks: saved ? const {} : marks,
        ),
      ]),
    );

    final lesson = wide && _currentRef != null ? db.grammarLesson(_currentRef!) : null;
    final mix = FilledButton.icon(
      onPressed: _picked.isEmpty ? null : () => context.push('/exercises/lessons/${_picked.join(',')}'),
      icon: const Icon(Icons.play_arrow_rounded, size: 18),
      label: Text('Làm bài tập trộn (${_picked.length})'),
    );

    return Scaffold(
      appBar: GrammarAppBar(
        crumbs: [Crumb(saved ? 'Ngữ Pháp Của Bạn' : 'Văn Phạm')],
        helpSlug: 'van-pham',
        actions: [
          if (wide)
            OutlinedButton.icon(
              onPressed: _toggleSelect,
              icon: Icon(_selectMode ? Icons.close : Icons.checklist, size: 18),
              label: Text(_selectMode ? 'Thoát chọn' : 'Chọn nhiều bài'),
            )
          else
            RoundIconButton(icon: _selectMode ? Icons.close : Icons.checklist, tooltip: _selectMode ? 'Thoát chọn' : 'Chọn nhiều bài', active: _selectMode, onPressed: _toggleSelect),
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
                  // On a phone the button sits in the bottom bar instead, in reach while scrolling.
                  if (wide) ...[const SizedBox(width: 12), mix],
                ]),
              ),
            ),
          if (saved && chapters.isEmpty)
            const EmptyNote('Chưa lưu bài nào. Mở một bài văn phạm và bấm "Lưu bài" để thêm vào đây.')
          else if (wide)
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
                          Text('${saved ? '${marks.length} bài đã lưu' : '${all.length} mục'} · bài có nhãn BT có bài tập đi kèm', style: theme.textTheme.bodySmall),
                        ]),
                      )
                    : LessonCard(lesson: lesson, all: all, sequence: saved ? _markedSequence(all, marks) : null, onNavigate: (r) => setState(() => _currentRef = r)),
              ),
            ])
          else
            tree,
        ],
      ),
      bottomNavigationBar: _selectMode && !wide
          ? SafeArea(
              child: Container(
                decoration: BoxDecoration(color: g.card, border: Border(top: BorderSide(color: g.border))),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: mix,
              ),
            )
          : null,
    );
  }
}

class GrammarLessonPage extends ConsumerStatefulWidget {
  final int ref;
  /// Opened from Ngữ Pháp Của Bạn: Bài trước / Bài kế stay among the bookmarked lessons.
  final bool saved;
  const GrammarLessonPage({super.key, required this.ref, this.saved = false});

  @override
  ConsumerState<GrammarLessonPage> createState() => _GrammarLessonPageState();
}

class _GrammarLessonPageState extends ConsumerState<GrammarLessonPage> {
  // Saved once per lesson, not per build: a rebuild under another route (theme, window
  // size) must not make this lesson the most recent activity again.
  void _save() {
    if (ref.read(contentDbProvider).grammarLesson(widget.ref) != null) {
      ref.read(userDbProvider).setProgress('grammar', 'last_lesson', '${widget.ref}');
    }
  }

  @override
  void initState() {
    super.initState();
    _save();
  }

  @override
  void didUpdateWidget(GrammarLessonPage old) {
    super.didUpdateWidget(old);
    if (old.ref != widget.ref) _save();
  }

  @override
  Widget build(BuildContext context) {
    final ref = widget.ref;
    final db = this.ref.read(contentDbProvider);
    final l = db.grammarLesson(ref);
    if (l == null) return const Scaffold(body: EmptyNote('Không có bài này.'));
    final all = this.ref.read(grammarLessonsProvider);
    final chapter = _chapterOf(_chapters(all), ref);
    final saved = widget.saved;
    return Scaffold(
      appBar: GrammarAppBar(crumbs: [
        if (saved) const Crumb('Ngữ Pháp Của Bạn', '/my-grammar') else const Crumb('Văn Phạm', '/grammar'),
        if (!saved && chapter != null && chapter.head.ref != ref) Crumb(chapter.head.title, '/grammar'),
        Crumb(l.title),
      ]),
      body: RailListView(maxWidth: 960, children: [
        LessonCard(
          lesson: l,
          all: all,
          sequence: saved ? _markedSequence(all, this.ref.watch(grammarMarksProvider)) : null,
          onNavigate: (r) => context.pushReplacement('/grammar/$r${saved ? '?saved=1' : ''}'),
        ),
      ]),
    );
  }
}

/// Lesson card: eyebrow (chapter · position), title, "Lưu bài" and "Làm Bài Tập" buttons,
/// body, prev/next.
class LessonCard extends ConsumerWidget {
  final GrammarLesson lesson;
  final List<GrammarLesson> all;
  /// What Bài trước / Bài kế walk through; every lesson ([all]) when null.
  final List<GrammarLesson>? sequence;
  final ValueChanged<int> onNavigate;
  const LessonCard({super.key, required this.lesson, required this.all, this.sequence, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final g = context.g;
    final seq = sequence ?? all;
    // A lesson outside the sequence (just un-bookmarked) still steps to its neighbours in it.
    final at = all.indexWhere((x) => x.ref == lesson.ref);
    int indexOf(GrammarLesson x) => all.indexWhere((y) => y.ref == x.ref);
    final prev = seq.where((x) => indexOf(x) < at).lastOrNull;
    final next = at < 0 ? null : seq.where((x) => indexOf(x) > at).firstOrNull;
    final chapter = _chapterOf(_chapters(all), lesson.ref);
    final pos = chapter == null ? null : chapter.lessons.indexOf(lesson) + 1;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Surface(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 40, vertical: narrow ? 24 : 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title wraps inside its column; the button keeps one place (top right, or under
        // the title on narrow screens) whatever the title length.
        Builder(builder: (context) {
          final head = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow(chapter == null || lesson.chapter ? 'Bài ${lesson.ref}' : '${chapter.head.title} · bài $pos/${chapter.lessons.length}'),
            const SizedBox(height: 2),
            Text(lesson.title, style: theme.textTheme.headlineLarge),
          ]);
          final button = Wrap(spacing: 8, runSpacing: 8, children: [
            GrammarMarkButton(lessonRef: lesson.ref),
            if (lesson.drills)
              FilledButton.icon(
                onPressed: () => context.push('/exercises/lessons/${lesson.ref}'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Làm Bài Tập'),
              ),
          ]);
          if (narrow) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [head, const SizedBox(height: 12), button]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: head),
            const SizedBox(width: 16),
            Padding(padding: const EdgeInsets.only(top: 22), child: button),
          ]);
        }),
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

/// Bookmarks the lesson into Ngữ Pháp Của Bạn, or removes it.
class GrammarMarkButton extends ConsumerWidget {
  final int lessonRef;
  const GrammarMarkButton({super.key, required this.lessonRef});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marked = ref.watch(grammarMarksProvider).contains(lessonRef);
    return OutlinedButton.icon(
      onPressed: () => ref.read(grammarMarksProvider.notifier).toggle(lessonRef),
      icon: Icon(marked ? Icons.bookmark : Icons.bookmark_add_outlined, size: 18),
      label: Text(marked ? 'Đã lưu' : 'Lưu bài'),
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
                  GrammarMarkButton(lessonRef: ref),
                  const SizedBox(width: 4),
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
