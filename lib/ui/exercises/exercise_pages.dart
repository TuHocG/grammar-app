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
import 'exercise_runner.dart';

const groupSize = 25;

class ExerciseGroupsPage extends ConsumerWidget {
  final int menuIdx;
  const ExerciseGroupsPage({super.key, required this.menuIdx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    final menu = db.exerciseMenus().firstWhere((m) => m.idx == menuIdx);
    final n = (menu.count / groupSize).ceil();
    final userDb = ref.read(userDbProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(menu.name)),
      body: ListView.builder(
        itemCount: n,
        itemBuilder: (context, i) {
          final start = menu.start + i * groupSize;
          final end = min(menu.start + (i + 1) * groupSize, menu.end);
          final saved = userDb.progress('exercise', 'menu$menuIdx-g$i');
          return ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text('Bài Tập ${i + 1}'),
            subtitle: Text('${end - start} câu${saved != null ? ' · đã làm: ${_summary(saved)}' : ''}', style: theme.textTheme.bodySmall),
            onTap: () => context.push('/exercises/menu/$menuIdx/$i'),
          );
        },
      ),
    );
  }

  String _summary(String json) {
    final m = RegExp(r'"score":(\d+),"done":(\d+)').firstMatch(json);
    return m == null ? '' : 'đúng ${m.group(1)}/${m.group(2)}';
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
      title: '${menu.name} · Bài Tập ${group + 1}',
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
    final title = refs.length == 1 ? 'Bài tập: ${db.grammarLesson(refs.first)?.title ?? ''}' : 'Bài tập trộn ${refs.length} bài';
    return ExerciseRunner(key: ValueKey('lessons-${refs.join(',')}'), title: title, exercises: items, lessonContext: true, progressKey: 'lessons-${refs.join(',')}');
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
    // 0 → 4 (bright red, to study) → 3 (dark red, reserve) → 0
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
      appBar: AppBar(
        title: const Text('WORD FORMS'),
        actions: [
          IconButton(
            tooltip: 'Xoá mọi đánh dấu',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _marks.isEmpty ? null : () { ref.read(userDbProvider).clearWordformMarks(); setState(() => _marks.clear()); },
          ),
          IconButton(tooltip: 'Hướng dẫn', icon: const Icon(Icons.help_outline), onPressed: () => context.push('/help/26')),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Tìm từ gốc', isDense: true, border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _filter = v.trim()),
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
            'Chạm từ gốc: lần 1 = học (đỏ sáng), lần 2 = dự trữ (đỏ sẫm), lần 3 = bỏ. Không chọn gì thì làm các từ thông dụng.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisExtent: 40, crossAxisSpacing: 6, mainAxisSpacing: 6),
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final r = shown[i];
              final level = _marks[r.position] ?? 0;
              final color = level == 4 ? Marks.savedWord : (level == 3 ? const Color(0xFF7F1D1D) : null);
              return InkWell(
                onTap: () => _cycle(r),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: color?.withValues(alpha: 0.15) ?? theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: color != null ? Border.all(color: color) : null,
                  ),
                  child: Row(children: [
                    if (r.common) Icon(Icons.star, size: 12, color: theme.colorScheme.outline),
                    if (r.common) const SizedBox(width: 4),
                    Expanded(child: Text(r.root, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: color != null ? FontWeight.w600 : null))),
                    Text('${r.count}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                  ]),
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
      title: 'Word Forms · $names${positions.length > 3 ? '…' : ''}',
      exercises: items,
      progressKey: 'wordforms',
    );
  }
}
