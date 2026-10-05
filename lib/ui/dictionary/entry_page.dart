/// Full-page dictionary entry, by row id or by word (docs/08 G4–G8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/lookup.dart';
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
      if (e == null) return const Scaffold(body: Center(child: Text('Không có mục này.')));
      r = e.isRedirect ? ref.read(lookupProvider).lookup(e.redirect!) : ref.read(lookupProvider).lookup(e.headword);
    } else {
      r = ref.read(lookupProvider).lookup(word ?? '');
    }
    final saved = ref.watch(userWordsProvider).savedKeys.contains(r.key);
    final tts = ref.read(ttsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(r.headword, style: TextStyle(color: saved ? Marks.savedWord : null)),
        actions: [
          IconButton(tooltip: 'Đọc', icon: const Icon(Icons.volume_up), onPressed: () => tts.speak(r.headword)),
          IconButton(
            tooltip: saved ? 'Bỏ lưu' : 'Lưu vào Từ Vựng Của Bạn',
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: saved ? Marks.savedWord : null),
            onPressed: () {
              final n = ref.read(userWordsProvider.notifier);
              saved ? n.removeByKey(r.key) : n.save(headword: r.headword, ipa: r.ipa, source: 'dict');
            },
          ),
        ],
      ),
      body: !r.found
          ? Center(child: Text('Không có "${r.query}" trong từ điển.', style: theme.textTheme.bodyLarge))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                if (r.redirectedFrom != null)
                  Text('${r.redirectedFrom} → ${r.headword}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                if (r.quick != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text.rich(TextSpan(children: [
                        if (r.quick!.respell != null && r.quick!.respell!.isNotEmpty)
                          TextSpan(text: '<${r.quick!.respell}>  ', style: TextStyle(color: theme.colorScheme.outline)),
                        if (r.quick!.pos != null && r.quick!.pos!.isNotEmpty)
                          TextSpan(text: '(${r.quick!.pos}) ', style: TextStyle(fontStyle: FontStyle.italic, color: theme.colorScheme.tertiary)),
                        TextSpan(text: r.quick!.vi, style: theme.textTheme.bodyLarge),
                      ])),
                    ),
                  ),
                for (var i = 0; i < r.entries.length; i++) ...[
                  if (i > 0) const Divider(height: 28),
                  EntryView(entry: r.entries[i], family: i == 0 ? r.family : null, showHeadword: r.entries.length > 1 || r.entries[i].ipa != null),
                ],
                if (r.entries.isEmpty && r.family != null) EntryViewFamilyOnly(family: r.family!),
              ],
            ),
    );
  }
}

class EntryViewFamilyOnly extends StatelessWidget {
  final dynamic family;
  const EntryViewFamilyOnly({super.key, required this.family});
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        children: [for (final m in family.members) Chip(label: Text('${m.word} (${m.pos})'))],
      );
}
