/// Renders one dictionary entry (segments from docs/05 `dict/<shard>.json`) and the
/// related-forms list (docs/08 G4, G8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import '../widgets/word_tap_text.dart';

class EntryView extends ConsumerWidget {
  final DictEntry entry;
  final WordFamily? family;
  final bool showHeadword;
  const EntryView({super.key, required this.entry, this.family, this.showHeadword = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tts = ref.read(ttsProvider);
    final children = <Widget>[];

    if (showHeadword) {
      children.add(Row(
        children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: entry.headword, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              if (entry.ipa != null && entry.ipa!.isNotEmpty)
                TextSpan(text: '   /${entry.ipa}/', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
            ])),
          ),
          IconButton(tooltip: 'Đọc', icon: const Icon(Icons.volume_up), onPressed: () => tts.speak(entry.headword)),
        ],
      ));
    }

    if (entry.isRedirect) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Xem: ${entry.redirect}', style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
      ));
    }

    var meaningNo = 0;
    for (final s in entry.segs) {
      switch (s.kind) {
        case 'pos':
          meaningNo = 0;
          children.add(Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Text(s.text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.tertiary, fontStyle: FontStyle.italic)),
          ));
        case 'ipa':
          children.add(Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('/${s.text}/', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
          ));
        case 'dom':
          children.add(Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('(${s.text})', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ));
        case 'm':
          meaningNo++;
          children.add(Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 22, child: Text('$meaningNo.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))),
              Expanded(child: Text(s.text, style: theme.textTheme.bodyLarge)),
            ]),
          ));
        case 'ex':
          children.add(Padding(
            padding: const EdgeInsets.only(left: 26, top: 2, bottom: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: WordTapText(s.text, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), source: 'dict:${entry.headword}')),
                InkWell(onTap: () => tts.speak(s.text), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.volume_up, size: 16))),
              ]),
              if (s.vi.isNotEmpty) Text(s.vi, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ));
        case 'ref':
          children.add(Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(entry.isRedirect ? '' : '→ ${s.text}', style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
          ));
      }
    }

    if (family != null && family!.members.isNotEmpty) {
      children.add(const Divider(height: 24));
      children.add(Text('Related forms', style: theme.textTheme.titleSmall));
      children.add(Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final m in family!.members)
            ActionChip(
              label: Text.rich(TextSpan(children: [
                TextSpan(text: m.word),
                if (m.pos.isNotEmpty) TextSpan(text: ' (${m.pos})', style: TextStyle(color: theme.colorScheme.outline)),
              ])),
              onPressed: () => context.push('/dict/word/${Uri.encodeComponent(m.word)}'),
            ),
        ],
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
