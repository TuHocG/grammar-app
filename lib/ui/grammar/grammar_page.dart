/// Văn Phạm (docs/08 P1–P5): chapters / lessons, lesson body, exercises per lesson and mixed
/// exercises for several selected lessons.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/content_db.dart';
import '../../data/models.dart';
import '../widgets/mark_text.dart';

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

class GrammarPage extends ConsumerStatefulWidget {
  const GrammarPage({super.key});
  @override
  ConsumerState<GrammarPage> createState() => _GrammarPageState();
}

class _GrammarPageState extends ConsumerState<GrammarPage> {
  int _chapter = 0;
  bool _selectMode = false;
  final Set<int> _picked = {};

  @override
  void initState() {
    super.initState();
    _chapter = int.tryParse(ref.read(userDbProvider).progress('grammar', 'chapter') ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final chapters = _chapters(ref.watch(grammarLessonsProvider));
    if (_chapter >= chapters.length) _chapter = 0;
    final ch = chapters[_chapter];
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 760;

    final chapterList = ListView.builder(
      itemCount: chapters.length,
      itemBuilder: (context, i) => ListTile(
        selected: i == _chapter,
        dense: true,
        title: Text(chapters[i].head.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () {
          setState(() => _chapter = i);
          ref.read(userDbProvider).setProgress('grammar', 'chapter', '$i');
          if (!wide) _showLessons(context, chapters[i]);
        },
      ),
    );

    final lessonList = ListView(
      children: [
        if (ch.head.chapter)
          ListTile(
            leading: const Icon(Icons.auto_stories),
            title: Text(ch.head.title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
            subtitle: const Text('Giới thiệu chương'),
            onTap: () => context.push('/grammar/${ch.head.ref}'),
          ),
        for (final l in ch.lessons)
          ListTile(
            leading: _selectMode
                ? Checkbox(value: _picked.contains(l.ref), onChanged: l.drills ? (v) => setState(() => v! ? _picked.add(l.ref) : _picked.remove(l.ref)) : null)
                : Icon(l.drills ? Icons.circle : Icons.circle_outlined, size: 10, color: l.drills ? theme.colorScheme.error : theme.colorScheme.outlineVariant),
            title: Text(l.title),
            onTap: _selectMode
                ? (l.drills ? () => setState(() => _picked.contains(l.ref) ? _picked.remove(l.ref) : _picked.add(l.ref)) : null)
                : () => context.push('/grammar/${l.ref}'),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Văn Phạm'),
        actions: [
          IconButton(
            tooltip: _selectMode ? 'Thoát chọn nhiều' : 'Chọn nhiều bài để làm bài tập trộn',
            icon: Icon(_selectMode ? Icons.close : Icons.checklist),
            onPressed: () => setState(() { _selectMode = !_selectMode; _picked.clear(); }),
          ),
          IconButton(tooltip: 'Hướng dẫn', icon: const Icon(Icons.help_outline), onPressed: () => context.push('/help/7')),
        ],
      ),
      body: wide
          ? Row(children: [
              SizedBox(width: 300, child: chapterList),
              const VerticalDivider(width: 1),
              Expanded(child: lessonList),
            ])
          : chapterList,
      floatingActionButton: _selectMode && _picked.isNotEmpty
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.play_arrow),
              label: Text('Làm bài tập trộn (${_picked.length} bài)'),
              onPressed: () => context.push('/exercises/lessons/${_picked.join(',')}'),
            )
          : null,
    );
  }

  void _showLessons(BuildContext context, _Chapter ch) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, ctl) => ListView(
          controller: ctl,
          children: [
            if (ch.head.chapter) ListTile(title: Text(ch.head.title), subtitle: const Text('Giới thiệu chương'), onTap: () { Navigator.pop(context); this.context.push('/grammar/${ch.head.ref}'); }),
            for (final l in ch.lessons)
              ListTile(
                leading: Icon(l.drills ? Icons.circle : Icons.circle_outlined, size: 10, color: l.drills ? Theme.of(context).colorScheme.error : null),
                title: Text(l.title),
                onTap: () { Navigator.pop(context); this.context.push('/grammar/${l.ref}'); },
              ),
          ],
        ),
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
    if (l == null) return const Scaffold(body: Center(child: Text('Không có bài này.')));
    wref.read(userDbProvider).setProgress('grammar', 'last_lesson', '$ref');
    final all = wref.read(grammarLessonsProvider);
    final i = all.indexWhere((x) => x.ref == ref);
    final prev = i > 0 ? all[i - 1].ref : null;
    final next = i >= 0 && i < all.length - 1 ? all[i + 1].ref : null;
    return Scaffold(
      appBar: AppBar(
        title: Text('$ref. ${l.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (l.drills)
            FilledButton.tonalIcon(
              icon: const Icon(Icons.edit_note),
              label: const Text('Làm bài tập'),
              onPressed: () => context.push('/exercises/lessons/$ref'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: LessonBody(lesson: l),
      bottomNavigationBar: SafeArea(
        child: Row(children: [
          TextButton.icon(onPressed: prev == null ? null : () => context.pushReplacement('/grammar/$prev'), icon: const Icon(Icons.chevron_left), label: const Text('Bài trước')),
          const Spacer(),
          TextButton.icon(onPressed: next == null ? null : () => context.pushReplacement('/grammar/$next'), icon: const Icon(Icons.chevron_right), label: const Text('Bài kế')),
        ]),
      ),
    );
  }
}

class LessonBody extends StatelessWidget {
  final GrammarLesson lesson;
  const LessonBody({super.key, required this.lesson});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: MarkText(
          lesson.body,
          source: 'grammar:${lesson.ref}',
          onLessonRef: (n) => showLessonSheet(context, n),
        ),
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
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, ctl) => l == null
          ? const Center(child: Text('Không có bài này.'))
          : ListView(
              controller: ctl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text('$ref. ${l.title}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                MarkText(l.body, source: 'grammar:$ref', onLessonRef: (n) => showLessonSheet(context, n)),
              ],
            ),
    ),
  );
}
