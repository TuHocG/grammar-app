/// Full-page dictionary entry, by row id or by word (docs/08 G4–G8), and [EntryCard], the
/// card that renders a lookup result (also used in the two-pane dictionary).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/search_key.dart';
import '../../domain/lookup.dart';
import '../widgets/shell.dart';
import 'entry_view.dart';

class EntryPage extends ConsumerWidget {
  final int? id;
  final String? word;
  const EntryPage({super.key, this.id, this.word});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    late final LookupResult r;
    if (id != null) {
      final e = db.entryById(id!);
      if (e == null) return const Scaffold(body: EmptyNote('Không có mục này.'));
      r = e.isRedirect ? ref.read(lookupProvider).lookup(e.redirect!) : ref.read(lookupProvider).lookup(e.headword);
    } else {
      r = ref.read(lookupProvider).lookup(word ?? '');
    }
    return Scaffold(
      appBar: GrammarAppBar(search: false, helpSlug: 'tu-dien', crumbs: [const Crumb('Từ điển', '/dict'), Crumb(r.headword)]),
      body: RailListView(
        maxWidth: 900,
        children: [EntryCard(result: r, lookedUp: word)],
      ),
    );
  }
}

/// Headword block (Literata, IPA in violet, Vietnamese respelling pill), read-aloud and save
/// buttons, quick meaning, full entries, Related forms.
class EntryCard extends ConsumerWidget {
  final LookupResult result;

  /// What was looked up, when [result] may have dropped part of it: a phrase the dictionary
  /// lacks falls back to its first word, but the user may have saved the whole phrase.
  final String? lookedUp;
  const EntryCard({super.key, required this.result, this.lookedUp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = result;
    final theme = Theme.of(context);
    final g = context.g;
    final tts = ref.read(ttsProvider);
    // The user's own entry for exactly what was looked up ("rowing", or a word the dictionary
    // lacks) wins over the dictionary's base form ("row"), as in QuickDefSheet.
    final words = ref.watch(userWordsProvider);
    final tappedKey = searchKey(lookedUp != null ? cleanToken(lookedUp!) : r.query);
    final uKey = words.savedKeys.contains(tappedKey) ? tappedKey : r.key;
    final saved = words.savedKeys.contains(uKey);
    final userWord = saved ? ref.read(userDbProvider).wordByKey(uKey) : null;
    // A saved word the dictionary only knows part of keeps its own IPA, not the dictionary word's.
    final ownOnly = userWord != null && uKey != r.key;
    final ipa = ownOnly ? userWord.ipa : userWord?.ipa ?? r.ipa;
    final quick = r.quick;
    final narrow = MediaQuery.sizeOf(context).width < 600;

    if (!r.found && r.family == null && userWord == null) {
      return Surface(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.query, style: ReadingStyles.headword(context)),
            const SizedBox(height: 8),
            Text('Không có "${r.query}" trong từ điển.', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
          ],
        ),
      );
    }

    final saveButton = saved
        ? FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: g.savedWord),
            onPressed: () => ref.read(userWordsProvider.notifier).removeByKey(uKey),
            icon: const Icon(Icons.bookmark, size: 16),
            label: const Text('Đã lưu · bỏ lưu'),
          )
        : OutlinedButton.icon(
            onPressed: () => ref.read(userWordsProvider.notifier).save(headword: r.headword, ipa: r.ipa, source: 'dict'),
            icon: const Icon(Icons.bookmark_outline, size: 16),
            label: const Text('Lưu từ'),
          );

    return Surface(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 40, vertical: narrow ? 24 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.start,
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userWord?.headword ?? r.headword, style: ReadingStyles.headword(context).copyWith(color: saved ? g.savedWord : null)),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      if (ipa != null && ipa.isNotEmpty)
                        Text(
                          '[$ipa]',
                          style: theme.textTheme.titleMedium?.copyWith(color: g.iris, fontWeight: FontWeight.w400, fontSize: 18),
                        ),
                      if (!ownOnly && quick?.respell != null && quick!.respell!.isNotEmpty) Respell(quick.respell!, fontSize: 16),
                      ActionChip(avatar: const Icon(Icons.volume_up_outlined, size: 16), label: const Text('Đọc'), onPressed: () => tts.speak(userWord?.headword ?? r.headword)),
                    ],
                  ),
                ],
              ),
              saveButton,
            ],
          ),
          if (r.redirectedFrom != null) ...[
            const SizedBox(height: 8),
            Text(
              '${r.redirectedFrom} → ${r.headword}',
              style: theme.textTheme.bodyMedium?.copyWith(color: g.slate, fontStyle: FontStyle.italic),
            ),
          ] else if (userWord != null && r.found && uKey != r.key) ...[
            const SizedBox(height: 8),
            Text(
              '${userWord.headword} → ${r.headword}',
              style: theme.textTheme.bodyMedium?.copyWith(color: g.slate, fontStyle: FontStyle.italic),
            ),
          ],
          if (userWord?.meaning != null && userWord!.meaning!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: g.savedTint, borderRadius: BorderRadius.circular(Tokens.radiusCard)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ghi chú của bạn', style: theme.textTheme.labelMedium?.copyWith(color: g.savedWord)),
                  Text(userWord.meaning!.replaceAll('_', '\n'), style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
          if (!r.found) ...[const SizedBox(height: 16), Text('Không có trong từ điển.', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate))],
          if (quick != null) ...[
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (quick.pos != null && quick.pos!.isNotEmpty) ...[PosBadge(quick.pos!), const SizedBox(width: 8)],
                Expanded(child: Text(quick.vi, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17))),
              ],
            ),
          ],
          for (var i = 0; i < r.entries.length; i++) ...[
            SizedBox(height: i == 0 ? 20 : 12),
            if (i > 0) const Divider(),
            if (i > 0) const SizedBox(height: 12),
            EntryView(entry: r.entries[i], family: null, showHeadword: r.entries.length > 1 || (quick == null && r.entries[i].ipa != null && r.ipa != r.entries[i].ipa)),
          ],
          if (r.family != null && r.family!.members.isNotEmpty) ...[const SizedBox(height: 20), RelatedFormsPanel(family: r.family!)],
        ],
      ),
    );
  }
}
