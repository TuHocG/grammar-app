/// The analysis card of one word in a "Phân Tích Câu" unit (docs/08 A2): the old app's
/// right-click table (Từ, Từ loại, Vị trí, Chức năng, Ý cần viết, "Phải có từ … vì") plus
/// the quick dictionary meaning it showed on the same click, and the linked grammar
/// lessons by their titles.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/models_more.dart';
import '../../domain/lookup.dart';
import '../dictionary/entry_view.dart';
import '../dictionary/quick_def_sheet.dart';
import '../grammar/grammar_page.dart';
import '../widgets/shell.dart';

Future<void> showAnalysisCard(
  BuildContext context,
  WidgetRef ref, {
  required AnalysisWord? word,
  required String token,
  required String sentence,
  required String source,
}) {
  final lookup = ref.read(lookupProvider).lookup(token);
  ref.read(ttsProvider).speak(word?.word ?? token);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (_) => AnalysisCard(word: word, token: token, lookup: lookup, sentence: sentence, source: source),
  );
}

class AnalysisCard extends ConsumerWidget {
  final AnalysisWord? word;
  final String token;
  final LookupResult lookup;
  final String sentence;
  final String source;
  const AnalysisCard({super.key, required this.word, required this.token, required this.lookup, required this.sentence, required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final g = context.g;
    final db = ref.read(contentDbProvider);
    final w = word;
    final r = lookup;
    final saved = ref.watch(userWordsProvider).savedKeys.contains(r.key);
    final quick = r.quick;
    final head = w?.word ?? token;

    void toggleSave() {
      final n = ref.read(userWordsProvider.notifier);
      if (saved) {
        n.removeByKey(r.key);
      } else {
        n.save(headword: r.headword, ipa: r.ipa, context: sentence, source: source);
      }
    }

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 96, child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: g.slate))),
            Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
          ]),
        );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          // Word + quick meaning, as the old app's left click shows next to the table.
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 4, children: [
            Text(head, style: ReadingStyles.line(context).copyWith(fontSize: 26, fontWeight: FontWeight.w600, color: saved ? g.savedWord : g.ink)),
            if (r.ipa != null && r.ipa!.isNotEmpty) Text('[${r.ipa}]', style: theme.textTheme.bodyLarge?.copyWith(color: g.iris)),
            if (quick?.respell != null && quick!.respell!.isNotEmpty) Respell(quick.respell!),
            RoundIconButton(icon: Icons.volume_up_outlined, tooltip: 'Đọc', size: 32, onPressed: () => ref.read(ttsProvider).speak(head)),
          ]),
          if (quick != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                if (quick.pos != null && quick.pos!.isNotEmpty) ...[PosBadge(quick.pos!), const SizedBox(width: 8)],
                Expanded(child: Text(quick.vi, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17))),
              ]),
            )
          else if (r.entries.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.entries.first.preview, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17))),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (saved)
              FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: g.savedWord), onPressed: toggleSave, icon: const Icon(Icons.bookmark, size: 16), label: const Text('Đã lưu'))
            else
              FilledButton.icon(onPressed: toggleSave, icon: const Icon(Icons.bookmark_outline, size: 16), label: const Text('Lưu từ')),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                showQuickDef(context, ref, token, contextSentence: sentence, source: source);
              },
              child: const Text('Tra từ điển'),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: g.border))),
            child: Text('Phân tích', style: theme.textTheme.titleSmall?.copyWith(color: g.slate)),
          ),
          if (w == null)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('Không có phân tích cho từ này.', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)))
          else ...[
            row('Từ loại', w.pos),
            row('Vị trí', w.position),
            row('Chức năng', w.function),
            row('Ý cần viết', w.meaning),
            if (w.note.isNotEmpty) row('Phải có từ này vì', w.note.replaceFirst(RegExp(r'^[^|]*\|\s*'), '')),
            if (w.refs.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Văn phạm liên quan', style: theme.textTheme.titleSmall?.copyWith(color: g.slate)),
              const SizedBox(height: 6),
              // Titles as the old app lists them (blue italic lines), e.g. "Câu Ðơn (Simple Sentence)".
              for (final ref_ in w.refs)
                _LessonLink(
                  number: ref_,
                  title: db.grammarLesson(ref_)?.title ?? 'Bài $ref_',
                  onTap: () => showLessonSheet(context, ref_),
                  onOpen: () => context.push('/grammar/$ref_'),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _LessonLink extends StatelessWidget {
  final int number;
  final String title;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  const _LessonLink({required this.number, required this.title, required this.onTap, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.g;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(children: [
            Icon(Icons.menu_book_outlined, size: 16, color: g.iris),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: theme.textTheme.bodyLarge?.copyWith(color: g.iris, fontStyle: FontStyle.italic))),
            Text('Bài $number', style: theme.textTheme.bodySmall?.copyWith(color: g.fog)),
            const SizedBox(width: 12),
            RoundIconButton(icon: Icons.open_in_new, tooltip: 'Mở trang văn phạm', size: 28, onPressed: onOpen),
          ]),
        ),
      ),
    );
  }
}
