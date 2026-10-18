/// Renders one dictionary entry (segments from docs/05 `dict/<shard>.json`) and the
/// related-forms panel (docs/08 G4, G8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../widgets/shell.dart';
import '../widgets/word_tap_text.dart';

/// Part-of-speech tag: small violet label on lilac.
class PosBadge extends StatelessWidget {
  final String pos;
  const PosBadge(this.pos, {super.key});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: g.lilac, borderRadius: BorderRadius.circular(4)),
      child: Text(pos, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: g.iris)),
    );
  }
}

/// "Related forms" (word family) as tappable chips in a lilac panel.
class RelatedFormsPanel extends StatelessWidget {
  final WordFamily family;
  const RelatedFormsPanel({super.key, required this.family});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.g;
    return LilacPanel(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Related forms', style: theme.textTheme.titleSmall?.copyWith(color: g.indigo)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in family.members)
                ActionChip(
                  label: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: m.word, style: ReadingStyles.line(context).copyWith(fontSize: 15)),
                        if (m.pos.isNotEmpty)
                          TextSpan(
                            text: '  ${m.pos}',
                            style: theme.textTheme.bodySmall?.copyWith(color: g.fog),
                          ),
                      ],
                    ),
                  ),
                  onPressed: () => context.push('/dict/word/${Uri.encodeComponent(m.word)}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class EntryView extends ConsumerWidget {
  final DictEntry entry;
  final WordFamily? family;
  final bool showHeadword;
  const EntryView({super.key, required this.entry, this.family, this.showHeadword = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final g = context.g;
    final tts = ref.read(ttsProvider);
    final children = <Widget>[];
    final meaning = theme.textTheme.bodyLarge?.copyWith(fontSize: 17);

    if (showHeadword) {
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(entry.headword, style: ReadingStyles.line(context).copyWith(fontSize: 22, fontWeight: FontWeight.w600)),
            if (entry.ipa != null && entry.ipa!.isNotEmpty) ...[const SizedBox(width: 10), Text('[${entry.ipa}]', style: theme.textTheme.bodyLarge?.copyWith(color: g.iris))],
            const SizedBox(width: 4),
            IconButton(tooltip: 'Đọc', icon: const Icon(Icons.volume_up_outlined, size: 18), visualDensity: VisualDensity.compact, onPressed: () => tts.speak(entry.headword)),
          ],
        ),
      );
    }

    if (entry.isRedirect) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Xem: ${entry.redirect}',
            style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic, color: g.slate),
          ),
        ),
      );
    }

    var meaningNo = 0;
    for (final s in entry.segs) {
      switch (s.kind) {
        case 'pos':
          meaningNo = 0;
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Align(alignment: Alignment.centerLeft, child: PosBadge(s.text)),
            ),
          );
        case 'ipa':
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('[${s.text}]', style: theme.textTheme.bodyMedium?.copyWith(color: g.iris)),
            ),
          );
        case 'dom':
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '(${s.text})',
                style: theme.textTheme.bodySmall?.copyWith(color: g.slate, fontStyle: FontStyle.italic),
              ),
            ),
          );
        case 'm':
          meaningNo++;
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('$meaningNo.', style: theme.textTheme.bodyMedium?.copyWith(color: g.fog, height: 1.7)),
                  ),
                  Expanded(child: Text(s.text, style: meaning)),
                ],
              ),
            ),
          );
        case 'ex':
          children.add(
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4, bottom: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: WordTapText(s.text, style: ReadingStyles.example(context), source: 'dict:${entry.headword}'),
                      ),
                      InkWell(
                        onTap: () => tts.speak(s.text),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.volume_up_outlined, size: 16, color: g.fog),
                        ),
                      ),
                    ],
                  ),
                  if (s.vi.isNotEmpty) Text(s.vi, style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)),
                ],
              ),
            ),
          );
        case 'ref':
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                entry.isRedirect ? '' : '→ ${s.text}',
                style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: g.slate),
              ),
            ),
          );
      }
    }

    if (family != null && family!.members.isNotEmpty) {
      children.add(const SizedBox(height: 16));
      children.add(RelatedFormsPanel(family: family!));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
