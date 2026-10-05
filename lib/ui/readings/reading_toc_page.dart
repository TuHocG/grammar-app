/// Bài Đọc → mục lục: 139 groups, nested, with a title filter (docs/08 R1).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/content_db.dart';
import '../../data/models.dart';

final sectionTreeProvider = Provider<ReadingSection>((ref) => ref.watch(contentDbProvider).sectionTree());

class ReadingTocPage extends ConsumerStatefulWidget {
  const ReadingTocPage({super.key});
  @override
  ConsumerState<ReadingTocPage> createState() => _ReadingTocPageState();
}

class _ReadingTocPageState extends ConsumerState<ReadingTocPage> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final root = ref.watch(sectionTreeProvider);
    final db = ref.read(contentDbProvider);
    final lastSid = int.tryParse(ref.read(userDbProvider).progress('reading', 'last_section') ?? '');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài Đọc'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Tìm bài theo tên', isDense: true, border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _filter = v.trim()),
            ),
          ),
        ),
      ),
      body: _filter.length >= 2
          ? _SearchResults(hits: db.searchReadings(_filter))
          : ListView(
              children: [
                for (final s in root.children) _SectionTile(section: s, initiallyExpanded: s.sid == lastSid || _containsSid(s, lastSid)),
              ],
            ),
    );
  }

  bool _containsSid(ReadingSection s, int? sid) => sid != null && s.children.any((c) => c.sid == sid || _containsSid(c, sid));
}

class _SectionTile extends ConsumerWidget {
  final ReadingSection section;
  final bool initiallyExpanded;
  const _SectionTile({required this.section, this.initiallyExpanded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final count = section.totalReadings;
    final title = Text(section.title, style: theme.textTheme.titleSmall);
    final trailing = Text('$count', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline));
    if (section.isLeaf) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: 16.0 + 16.0 * (section.depth - 1), right: 16),
        title: title,
        trailing: trailing,
        onTap: () => context.push('/readings/section/${section.sid}'),
      );
    }
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.only(left: 16.0 + 16.0 * (section.depth - 1), right: 16),
      title: title,
      trailing: trailing,
      children: [
        if (section.readingCount > 0)
          ListTile(
            contentPadding: EdgeInsets.only(left: 16.0 + 16.0 * section.depth, right: 16),
            title: Text('Bài trong "${section.title}"', style: theme.textTheme.bodyMedium),
            trailing: Text('${section.readingCount}', style: theme.textTheme.bodySmall),
            onTap: () => context.push('/readings/section/${section.sid}'),
          ),
        for (final c in section.children) _SectionTile(section: c),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<ReadingSummary> hits;
  const _SearchResults({required this.hits});
  @override
  Widget build(BuildContext context) => ListView(
        children: [
          for (final h in hits)
            ListTile(
              title: Text(h.title),
              trailing: h.hasAudio ? const Icon(Icons.graphic_eq, size: 18) : null,
              onTap: () => context.push('/readings/${h.id}'),
            ),
          if (hits.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Không có bài nào khớp.')),
        ],
      );
}

/// List of readings inside one section.
class ReadingListPage extends ConsumerWidget {
  final int sid;
  const ReadingListPage({super.key, required this.sid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    final section = db.section(sid);
    final items = db.readingsInSection(sid);
    ref.read(userDbProvider).setProgress('reading', 'last_section', '$sid');
    final lastId = int.tryParse(ref.read(userDbProvider).progress('reading', 'last_in_$sid') ?? '');
    return Scaffold(
      appBar: AppBar(title: Text(section?.title ?? 'Bài Đọc')),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final r = items[i];
          final isLast = r.id == lastId;
          return ListTile(
            leading: r.img != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      db.mediaFile(r.img!),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(width: 48, height: 48, child: Icon(Icons.image_not_supported_outlined)),
                    ),
                  )
                : const SizedBox(width: 48, height: 48, child: Icon(Icons.article_outlined)),
            title: Text(r.title, style: TextStyle(fontWeight: isLast ? FontWeight.w600 : null)),
            trailing: r.hasAudio ? const Icon(Icons.graphic_eq, size: 18) : null,
            onTap: () => context.push('/readings/${r.id}'),
          );
        },
      ),
    );
  }
}
