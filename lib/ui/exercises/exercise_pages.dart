/// Entry points into ExerciseRunner (docs/08 E1, E2, P4, E11, E12):
/// - a right-column menu → groups "Bài Tập n" of 25 → runner (shuffled when > 6);
/// - exercises of one or several grammar lessons (mixed drills);
/// - Word Forms: root table with two mark levels, run the selected roots.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/models.dart';
import '../widgets/shell.dart';
import 'exercise_runner.dart';

const groupSize = 25;

class ExerciseGroupsPage extends ConsumerWidget {
  final int menuIdx;
  const ExerciseGroupsPage({super.key, required this.menuIdx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    final menus = db.exerciseMenus();
    final menu = menus.firstWhere((m) => m.idx == menuIdx);
    final n = (menu.count / groupSize).ceil();
    final userDb = ref.read(userDbProvider);
    final theme = Theme.of(context);
    final g = context.g;
    final progress = userDb.progressOf('exercise', prefix: 'menu$menuIdx-g');
    return Scaffold(
      appBar: GrammarAppBar(
        crumbs: [const Crumb('Bài Tập', '/'), Crumb(menu.name)],
        helpSlug: 'bai-tap',
      ),
      body: RailListView(
        children: [
          if (context.isWide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Left nav with the nine sets, like the readings and dialogs pages.
              SizedBox(
                width: 280,
                child: Surface(
                  padding: const EdgeInsets.all(8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      child: Text('Bài Tập', style: theme.textTheme.titleSmall),
                    ),
                    for (final m in menus)
                      _MenuRow(
                        title: m.name,
                        count: m.count,
                        selected: m.idx == menuIdx,
                        onTap: m.idx == menuIdx ? null : () => context.pushReplacement(m.idx == 8 ? '/exercises/wordforms' : '/exercises/menu/${m.idx}'),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(child: _groups(context, menu, n, progress, theme, g)),
            ])
          else
            _groups(context, menu, n, progress, theme, g),
        ],
      ),
    );
  }

  Widget _groups(BuildContext context, ExerciseMenu menu, int n, Map<String, String> progress, ThemeData theme, GrammarColors g) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(menu.name, style: theme.textTheme.headlineLarge),
          Text('$n Bài Tập, mỗi bài tối đa $groupSize câu · ${menu.count} câu · điểm được lưu theo từng bài', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
          const SizedBox(height: 24),
          AutoGrid(
            minWidth: 220,
            children: [
              for (var i = 0; i < n; i++)
                Builder(builder: (context) {
                  final start = menu.start + i * groupSize;
                  final end = min(menu.start + (i + 1) * groupSize, menu.end);
                  final st = RegExp(r'"pos":(\d+),"score":(\d+),"done":(\d+)').firstMatch(progress['menu$menuIdx-g$i'] ?? '');
                  final done = st == null ? 0 : int.parse(st.group(3)!);
                  final score = st == null ? 0 : int.parse(st.group(2)!);
                  return Surface(
                    onTap: () => context.push('/exercises/menu/$menuIdx/$i'),
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      LetterDot('${i + 1}', size: 36, fill: done > 0 ? g.iris : g.lilac, border: done > 0 ? g.iris : g.lilac, color: done > 0 ? theme.colorScheme.onPrimary : g.iris),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Bài Tập ${i + 1}', style: theme.textTheme.titleMedium),
                          Text(done > 0 ? 'đúng $score/$done · ${end - start} câu' : '${end - start} câu', style: theme.textTheme.bodySmall),
                        ]),
                      ),
                      Icon(Icons.chevron_right, color: g.fog),
                    ]),
                  );
                }),
            ],
          ),
        ]);
  }
}

class _MenuRow extends StatelessWidget {
  final String title;
  final int count;
  final bool selected;
  final VoidCallback? onTap;
  const _MenuRow({required this.title, required this.count, required this.selected, this.onTap});
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
            Text('$count', style: theme.textTheme.bodySmall?.copyWith(color: selected ? g.iris : g.fog)),
          ]),
        ),
      ),
    );
  }
}

class ExerciseGroupRunPage extends ConsumerWidget {
  final int menuIdx;
  final int group;
  const ExerciseGroupRunPage({super.key, required this.menuIdx, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    final menu = db.exerciseMenus().firstWhere((m) => m.idx == menuIdx);
    final start = menu.start + group * groupSize;
    final end = min(start + groupSize, menu.end);
    var items = db.exercisesInRange(start, end).where((e) => !e.isEmpty).toList();
    if (items.length > 6) items = List.of(items)..shuffle(Random(start));   // stable shuffle per group
    final groups = (menu.count / groupSize).ceil();
    return ExerciseRunner(
      key: ValueKey('menu$menuIdx-g$group'),
      title: 'Bài Tập ${group + 1}',
      crumbs: [const Crumb('Bài Tập', '/'), Crumb(menu.name, '/exercises/menu/$menuIdx')],
      exercises: items,
      progressKey: 'menu$menuIdx-g$group',
      onNextGroup: group + 1 < groups ? () => context.pushReplacement('/exercises/menu/$menuIdx/${group + 1}') : null,
    );
  }
}

class LessonExercisesPage extends ConsumerWidget {
  final List<int> refs;
  const LessonExercisesPage({super.key, required this.refs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    var items = db.exercisesForLessons(refs).where((e) => !e.isEmpty).toList();
    if (refs.length > 1) items = List.of(items)..shuffle(Random(refs.fold<int>(0, (a, b) => a * 31 + b)));
    final title = refs.length == 1 ? (db.grammarLesson(refs.first)?.title ?? 'Bài tập') : 'Bài tập trộn ${refs.length} bài';
    return ExerciseRunner(
      key: ValueKey('lessons-${refs.join(',')}'),
      title: title,
      crumbs: [const Crumb('Văn Phạm', '/grammar'), if (refs.length == 1) const Crumb('Bài tập')],
      exercises: items,
      lessonContext: true,
      progressKey: 'lessons-${refs.join(',')}',
    );
  }
}

// ---- Word Forms -----------------------------------------------------------------------

class WordFormsPage extends ConsumerStatefulWidget {
  const WordFormsPage({super.key});
  @override
  ConsumerState<WordFormsPage> createState() => _WordFormsPageState();
}

class _WordFormsPageState extends ConsumerState<WordFormsPage> {
  late List<WordformRoot> _roots;
  late Map<int, int> _marks;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _roots = ref.read(contentDbProvider).wordformRoots();
    _marks = ref.read(userDbProvider).wordformMarks();
  }

  void _cycle(WordformRoot r) {
    // 0 → 4 (blue, to study) → 3 (red, reserve) → 0  (the old app: bright red / dark red)
    final cur = _marks[r.position] ?? 0;
    final next = cur == 0 ? 4 : (cur == 4 ? 3 : 0);
    ref.read(userDbProvider).setWordformMark(r.position, next);
    setState(() => next == 0 ? _marks.remove(r.position) : _marks[r.position] = next);
  }

  List<WordformRoot> _selection() {
    final bright = _roots.where((r) => _marks[r.position] == 4).toList();
    if (bright.isNotEmpty) return bright;
    final dark = _roots.where((r) => _marks[r.position] == 3).toList();
    if (dark.isNotEmpty) return dark;
    return _roots.where((r) => r.common).toList();
  }

  void _run() {
    final sel = _selection();
    context.push('/exercises/wordforms/${sel.map((r) => r.position).join(',')}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = _filter.isEmpty ? _roots : _roots.where((r) => r.root.startsWith(_filter.toLowerCase())).toList();
    final nBright = _marks.values.where((v) => v == 4).length;
    final nDark = _marks.values.where((v) => v == 3).length;
    return Scaffold(
      appBar: GrammarAppBar(
        crumbs: const [Crumb('Bài Tập', '/'), Crumb('WORD FORMS')],
        helpSlug: 'word-forms',
        actions: [
          OutlinedButton.icon(
            onPressed: _marks.isEmpty ? null : () { ref.read(userDbProvider).clearWordformMarks(); setState(() => _marks.clear()); },
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: const Text('Xoá đánh dấu'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: context.g.card,
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: SearchPill(hint: 'Tìm từ gốc', onChanged: (v) => setState(() => _filter = v.trim()))),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.play_arrow),
        label: Text(nBright > 0 ? 'Làm bài ($nBright từ)' : (nDark > 0 ? 'Ôn từ dự trữ ($nDark)' : 'Làm từ thông dụng')),
        onPressed: _run,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            'Chạm từ gốc: lần 1 = học (xanh), lần 2 = dự trữ (đỏ), lần 3 = bỏ. Không chọn gì thì làm các từ thông dụng.',
            style: theme.textTheme.bodyMedium?.copyWith(color: context.g.slate),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisExtent: 40, crossAxisSpacing: 6, mainAxisSpacing: 6),
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final r = shown[i];
              final level = _marks[r.position] ?? 0;
              final g = context.g;
              final color = level == 4 ? g.iris : (level == 3 ? g.savedWord : null);
              return Material(
                color: level == 4 ? g.lilac : (level == 3 ? g.savedTint : g.card),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: color ?? g.border)),
                child: InkWell(
                  onTap: () => _cycle(r),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(children: [
                      if (r.common) Icon(Icons.star, size: 12, color: g.fog),
                      if (r.common) const SizedBox(width: 4),
                      Expanded(child: Text(r.root, maxLines: 1, overflow: TextOverflow.ellipsis, style: ReadingStyles.line(context).copyWith(fontSize: 15, color: color ?? g.ink, fontWeight: color != null ? FontWeight.w600 : null))),
                      Text('${r.count}', style: theme.textTheme.labelSmall),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class WordFormsRunPage extends ConsumerWidget {
  final List<int> positions;
  const WordFormsRunPage({super.key, required this.positions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    final menu = db.exerciseMenus().firstWhere((m) => m.idx == 8);
    final roots = db.wordformRoots();
    final byPos = {for (final r in roots) r.position: r};
    final items = <Exercise>[];
    for (final p in positions) {
      final r = byPos[p];
      if (r == null) continue;
      final start = menu.start + r.start - 1;
      items.addAll(db.exercisesInRange(start, start + r.count).where((e) => !e.isEmpty));
    }
    final names = positions.map((p) => byPos[p]?.root ?? '').where((s) => s.isNotEmpty).take(3).join(', ');
    return ExerciseRunner(
      key: ValueKey('wf-${positions.join(',')}'),
      title: '$names${positions.length > 3 ? '…' : ''}',
      crumbs: const [Crumb('Bài Tập', '/'), Crumb('WORD FORMS', '/exercises/wordforms')],
      exercises: items,
      progressKey: 'wordforms',
    );
  }
}
