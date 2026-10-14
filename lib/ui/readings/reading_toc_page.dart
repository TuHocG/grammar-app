/// Bài Đọc → mục lục: 139 groups, nested, with a title filter (docs/08 R1), and the list of
/// readings inside one group.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/models.dart';
import '../widgets/shell.dart';

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
    final theme = Theme.of(context);
    final g = context.g;
    ref.watch(progressRevisionProvider);
    final userDb = ref.read(userDbProvider);
    final lastSid = int.tryParse(userDb.progress('reading', 'last_section') ?? '');
    final lastId = int.tryParse(userDb.progress('reading', 'last_reading') ?? '');
    // Section 0 (Phiên Âm Quốc Tế) is its own menu item, never "continue reading" here.
    final lastRead = lastId == null || lastId < 0 ? null : db.reading(lastId);
    final last = lastRead == null || lastRead.sid == 0 ? null : lastRead;

    return Scaffold(
      appBar: GrammarAppBar(
        crumbs: const [Crumb('Bài Đọc')],
        helpSlug: 'bai-doc',
      ),
      body: RailListView(
        maxWidth: 960,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bài Đọc', style: theme.textTheme.headlineLarge),
                Text('${root.children.where((s) => s.sid != 0).fold(0, (a, s) => a + s.totalReadings)} bài trong ${root.children.where((s) => s.sid != 0).length} nhóm · chạm từ để tra, chạm câu để dịch', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          SearchPill(hint: 'Tìm bài theo tên', onChanged: (v) => setState(() => _filter = v.trim())),
          const SizedBox(height: 16),
          if (_filter.length >= 2)
            _SearchResults(hits: db.searchReadings(_filter))
          else ...[
            if (last != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Surface(
                  onTap: () => context.push('/readings/${last.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 72,
                        height: 56,
                        child: last.img != null
                            ? Image(image: db.imageProvider(last.img!), fit: BoxFit.cover, errorBuilder: (_, _, _) => const IconTile(Icons.menu_book_outlined, size: 56))
                            : const IconTile(Icons.menu_book_outlined, size: 56),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Đang đọc · ${db.section(last.sid)?.title ?? ''}', style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(last.title, style: ReadingStyles.line(context).copyWith(fontSize: 18, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    FilledButton(onPressed: () => context.push('/readings/${last.id}'), child: const Text('Tiếp tục')),
                  ]),
                ),
              ),
            Surface(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Section 0 (Phiên Âm Quốc Tế) is its own home-menu item (/ipa).
                for (final s in root.children.where((s) => s.sid != 0)) _SectionTile(section: s, initiallyExpanded: s.sid == lastSid || _containsSid(s, lastSid)),
              ]),
            ),
          ],
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
    final g = context.g;
    final count = section.totalReadings;
    final indent = 12.0 + 20.0 * (section.depth - 1);
    final title = Text(section.title, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis);
    final trailing = Text('$count', style: theme.textTheme.bodySmall?.copyWith(color: g.fog));
    if (section.isLeaf) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: indent + 24, right: 12),
        title: title,
        trailing: trailing,
        onTap: () => context.push('/readings/section/${section.sid}'),
      );
    }
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.only(left: indent, right: 12),
      controlAffinity: ListTileControlAffinity.leading,
      title: title,
      trailing: trailing,
      childrenPadding: EdgeInsets.zero,
      children: [
        if (section.readingCount > 0)
          ListTile(
            contentPadding: EdgeInsets.only(left: indent + 44, right: 12),
            leading: Icon(Icons.menu_book_outlined, size: 18, color: g.iris),
            minLeadingWidth: 0,
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
  Widget build(BuildContext context) {
    final g = context.g;
    if (hits.isEmpty) return const EmptyNote('Không có bài nào khớp.');
    return Surface(
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        for (final h in hits)
          ListTile(
            title: Text(h.title, style: ReadingStyles.line(context).copyWith(fontSize: 16)),
            trailing: h.hasAudio ? Icon(Icons.graphic_eq, size: 18, color: g.fog) : null,
            onTap: () => context.push('/readings/${h.id}'),
          ),
      ]),
    );
  }
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
    final theme = Theme.of(context);
    final g = context.g;
    ref.read(userDbProvider).setProgress('reading', 'last_section', '$sid');
    ref.watch(progressRevisionProvider);
    final lastId = int.tryParse(ref.read(userDbProvider).progress('reading', 'last_in_$sid') ?? '');
    return Scaffold(
      appBar: GrammarAppBar(crumbs: [const Crumb('Bài Đọc', '/readings'), Crumb(section?.title ?? 'Bài Đọc')]),
      body: RailListView(
        maxWidth: 960,
        children: [
          Text(section?.title ?? 'Bài Đọc', style: theme.textTheme.headlineLarge),
          Text('${items.length} bài${items.any((r) => r.hasAudio) ? ' · có bài với giọng đọc thật' : ''}', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
          const SizedBox(height: 20),
          AutoGrid(
            minWidth: 280,
            children: [
              for (final r in items)
                Surface(
                  onTap: () => context.push('/readings/${r.id}'),
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: r.img != null
                            ? Image(image: db.imageProvider(r.img!), fit: BoxFit.cover, errorBuilder: (_, _, _) => const IconTile(Icons.menu_book_outlined, size: 56))
                            : const IconTile(Icons.menu_book_outlined, size: 56),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.title, style: ReadingStyles.line(context).copyWith(fontSize: 16, fontWeight: r.id == lastId ? FontWeight.w600 : FontWeight.w400), maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (r.id == lastId || r.hasAudio)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(spacing: 6, children: [
                              if (r.id == lastId) const SoftBadge('Đang đọc'),
                              if (r.hasAudio) SoftBadge('MP3', color: g.slate, background: g.canvas),
                            ]),
                          ),
                      ]),
                    ),
                  ]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
