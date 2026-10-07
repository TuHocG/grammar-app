/// Phân Tích Câu (docs/08 A1, A2): the 12 analysed units of "Những Mẩu Chuyện Tiếng Anh
/// Tập 1" (readings 361–372). The list shows each unit with its illustration; a unit opens
/// the ordinary ReadingPage in analysis mode (image, sentence numbers, translation, Nghe
/// toàn bài / Xếp từ / Đàm thoại / Nghe viết), where a tap on a word shows its analysis
/// card together with the quick dictionary meaning.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/content_db_more.dart';
import '../widgets/shell.dart';

/// Reading ids of the analysed units, in analysis-lesson order (section "Những Mẩu Chuyện
/// Tiếng Anh Tập 1", Unit 1..12).
List<int> analysisReadingIds(ContentDb db) {
  final sec = db.sectionTree().children.where((s) => s.title.startsWith('Những Mẩu Chuyện Tiếng Anh Tập 1')).firstOrNull;
  if (sec == null) return const [];
  final n = db.analysisLessonIds().length;
  return db.readingsInSection(sec.sid).map((r) => r.id).take(n).toList();
}

/// Analysis lesson id for a reading, or null when the reading has no analysis.
int? analysisLessonOf(ContentDb db, int readingId) {
  final i = analysisReadingIds(db).indexOf(readingId);
  return i < 0 ? null : db.analysisLessonIds()[i];
}

class AnalysisListPage extends ConsumerWidget {
  const AnalysisListPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    final theme = Theme.of(context);
    final g = context.g;
    final ids = db.analysisLessonIds();
    final readings = analysisReadingIds(db);
    final last = int.tryParse(ref.read(userDbProvider).progress('reading', 'last_reading') ?? '');
    return Scaffold(
      appBar: GrammarAppBar(
        crumbs: const [Crumb('Phân Tích Câu')],
        actions: [RoundIconButton(icon: Icons.help_outline, tooltip: 'Hướng dẫn', onPressed: () => context.push('/help/5'))],
      ),
      body: RailListView(children: [
        Text('Phân Tích Câu', style: theme.textTheme.headlineLarge),
        Text('${ids.length} bài · chạm từ để xem từ loại, chức năng và vì sao phải có từ đó', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
        const SizedBox(height: 16),
        for (var i = 0; i < ids.length && i < readings.length; i++)
          Builder(builder: (context) {
            final r = db.reading(readings[i]);
            if (r == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Surface(
                onTap: () => context.push('/analysis/${ids[i]}'),
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 72,
                      height: 56,
                      child: r.img != null
                          ? Image(image: db.imageProvider(r.img!), fit: BoxFit.cover, errorBuilder: (_, _, _) => const IconTile(Icons.manage_search, size: 56))
                          : const IconTile(Icons.manage_search, size: 56),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.title, style: ReadingStyles.line(context).copyWith(fontSize: 16, fontWeight: r.id == last ? FontWeight.w600 : FontWeight.w400)),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${db.analysisWords(ids[i]).length} từ được phân tích · ${r.sentences.length} câu', style: theme.textTheme.bodySmall?.copyWith(color: g.slate)),
                      ),
                    ]),
                  ),
                  if (r.id == last) const SoftBadge('Đang đọc'),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: g.fog),
                ]),
              ),
            );
          }),
      ]),
    );
  }
}
