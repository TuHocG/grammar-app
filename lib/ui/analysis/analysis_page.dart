/// Phân Tích Câu (docs/08 A1, A2): the 12 "Những Mẩu Chuyện Tiếng Anh Tập 1" units; every
/// word (the '|' tokens of dataPt) opens its analysis card: Từ, Từ loại, Vị trí, Chức năng,
/// Ý cần viết, Ghi chú and grammar links. Tap = analysis; the card offers the dictionary.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/content_db_more.dart';
import '../../data/models.dart';
import '../../data/search_key.dart';
import '../dictionary/quick_def_sheet.dart';
import '../grammar/grammar_page.dart';
import '../widgets/shell.dart';

/// Reading ids of the analysed units, in analysis-lesson order (section "Những Mẩu Chuyện
/// Tiếng Anh Tập 1", Unit 1..12).
List<int> analysisReadingIds(ContentDb db) {
  final sec = db.sectionTree().children.where((s) => s.title.startsWith('Những Mẩu Chuyện Tiếng Anh Tập 1')).firstOrNull;
  if (sec == null) return const [];
  return db.readingsInSection(sec.sid).map((r) => r.id).toList();
}

class AnalysisListPage extends ConsumerWidget {
  const AnalysisListPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    final ids = db.analysisLessonIds();
    final readings = analysisReadingIds(db);
    return Scaffold(
      appBar: GrammarAppBar(
        title: const Text('Phân Tích Câu'),
        actions: [IconButton(tooltip: 'Hướng dẫn', icon: const Icon(Icons.help_outline), onPressed: () => context.push('/help/5'))],
      ),
      body: ListView(
        children: [
          for (final id in ids)
            if (id < readings.length)
              ListTile(
                leading: CircleAvatar(child: Text('${id + 1}')),
                title: Text(db.reading(readings[id])?.title ?? 'Unit ${id + 1}'),
                subtitle: Text('${db.analysisWords(id).length} từ được phân tích'),
                onTap: () => context.push('/analysis/$id'),
              ),
        ],
      ),
    );
  }
}

class AnalysisPage extends ConsumerStatefulWidget {
  final int id;
  const AnalysisPage({super.key, required this.id});
  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  late final List<AnalysisWord> _words;
  late final List<List<String>> _tokens;   // per sentence, raw '|' tokens
  late final List<String> _vi;
  String _title = '';
  int? _open;
  bool _showVi = false;

  @override
  void initState() {
    super.initState();
    final db = ref.read(contentDbProvider);
    _words = db.analysisWords(widget.id);
    final ids = analysisReadingIds(db);
    final rid = widget.id < ids.length ? ids[widget.id] : null;
    final rows = rid == null ? const <Map<String, Object?>>[] : db.raw.select('SELECT en, vi FROM reading_sentence WHERE reading_id = ? ORDER BY idx', [rid]);
    _tokens = [for (final r in rows) (r['en'] as String).split('|').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()];
    _vi = [for (final r in rows) (r['vi'] ?? '') as String];
    _title = rid == null ? 'Unit ${widget.id + 1}' : (db.reading(rid)?.title ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = ref.watch(userWordsProvider).savedKeys;
    var k = 0;   // global token index == analysis word index
    return Scaffold(
      appBar: GrammarAppBar(
        title: Text('Phân tích · $_title'),
        actions: [
          IconButton(tooltip: 'Bản dịch', icon: Icon(_showVi ? Icons.translate : Icons.translate_outlined), onPressed: () => setState(() => _showVi = !_showVi)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Chạm vào từ để xem phân tích; trong thẻ có nút tra từ điển.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 10),
          for (var s = 0; s < _tokens.length; s++) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tok in _tokens[s])
                  _Token(
                    text: tok,
                    index: k++,
                    selected: _open == k - 1,
                    saved: saved.contains(searchKey(cleanToken(tok))),
                    onTap: (i) => _show(i, tok, s),
                  ),
              ],
            ),
            if (_showVi) Padding(padding: const EdgeInsets.only(top: 2, bottom: 8), child: Text(_vi[s], style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  void _show(int i, String tok, int sentence) {
    setState(() => _open = i);
    final w = i < _words.length ? _words[i] : null;
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (c, ctl) => ListView(
          controller: ctl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(children: [
              Expanded(child: Text(w?.word ?? tok, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
              IconButton(tooltip: 'Đọc', icon: const Icon(Icons.volume_up), onPressed: () => ref.read(ttsProvider).speak(w?.word ?? tok)),
              IconButton(tooltip: 'Tra từ điển', icon: const Icon(Icons.search), onPressed: () => showQuickDef(c, ref, tok, contextSentence: _tokens[sentence].join(' '), source: 'analysis:${widget.id}')),
            ]),
            if (w == null)
              const Text('Không có phân tích cho từ này.')
            else ...[
              _row('Từ loại', w.pos, theme),
              _row('Vị trí', w.position, theme),
              _row('Chức năng', w.function, theme),
              _row('Ý cần viết', w.meaning, theme),
              if (w.note.isNotEmpty) _row('Ghi chú', w.note.replaceFirst(RegExp(r'^[^|]*\|\s*'), ''), theme),
              if (w.refs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final r in w.refs)
                      ActionChip(
                        avatar: const Icon(Icons.menu_book, size: 16),
                        label: Text('Bài $r'),
                        onPressed: () => showLessonSheet(c, r),
                      ),
                  ]),
                ),
            ],
          ],
        ),
      ),
    ).whenComplete(() { if (mounted) setState(() => _open = null); });
  }

  Widget _row(String label, String value, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 92, child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ]),
      );
}

class _Token extends StatelessWidget {
  final String text;
  final int index;
  final bool selected;
  final bool saved;
  final void Function(int) onTap;
  const _Token({required this.text, required this.index, required this.selected, required this.saved, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: selected ? theme.colorScheme.primaryContainer : null, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: theme.textTheme.titleMedium?.copyWith(color: saved ? Marks.savedWord : null)),
      ),
    );
  }
}
