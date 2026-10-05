/// QuickDefSheet: quick meaning → full entry → save (docs/08 G3, G4, G5, G9).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/lookup.dart';
import 'entry_view.dart';

Future<void> showQuickDef(BuildContext context, WidgetRef ref, String word, {String? contextSentence, String? source}) async {
  final result = ref.read(lookupProvider).lookup(word);
  // Read the word aloud as the old app does on left click.
  ref.read(ttsProvider).speak(result.found ? result.headword : word);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => QuickDefSheet(result: result, contextSentence: contextSentence, source: source),
  );
}

class QuickDefSheet extends ConsumerStatefulWidget {
  final LookupResult result;
  final String? contextSentence;
  final String? source;
  const QuickDefSheet({super.key, required this.result, this.contextSentence, this.source});

  @override
  ConsumerState<QuickDefSheet> createState() => _QuickDefSheetState();
}

class _QuickDefSheetState extends ConsumerState<QuickDefSheet> {
  bool _full = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final theme = Theme.of(context);
    final words = ref.watch(userWordsProvider);
    final saved = words.savedKeys.contains(r.key);
    final tts = ref.read(ttsProvider);
    final quick = r.quick;
    final userWord = ref.read(userDbProvider).wordByKey(r.key);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: _full ? 0.85 : 0.42,
      minChildSize: 0.25,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(children: [
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: r.headword, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: saved ? Marks.savedWord : null)),
                if (r.ipa != null && r.ipa!.isNotEmpty)
                  TextSpan(text: '   /${r.ipa}/', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                if (quick?.respell != null && quick!.respell!.isNotEmpty)
                  TextSpan(text: '  <${quick.respell}>', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
              ])),
            ),
            IconButton(tooltip: 'Đọc', icon: const Icon(Icons.volume_up), onPressed: () => tts.speak(r.headword)),
            IconButton(
              tooltip: saved ? 'Bỏ lưu' : 'Lưu vào Từ Vựng Của Bạn',
              icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: saved ? Marks.savedWord : null),
              onPressed: () {
                final n = ref.read(userWordsProvider.notifier);
                if (saved) {
                  n.removeByKey(r.key);
                } else {
                  n.save(headword: r.headword, ipa: r.ipa, context: widget.contextSentence, source: widget.source);
                }
              },
            ),
          ]),
          if (r.redirectedFrom != null)
            Text('${r.redirectedFrom} → ${r.headword}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          if (r.key != r.query.toLowerCase() && r.redirectedFrom == null && r.found)
            Text('${r.query} → ${r.headword}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 6),
          if (userWord?.meaning != null && userWord!.meaning!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(userWord.meaning!.replaceAll('_', '\n'), style: theme.textTheme.bodyLarge?.copyWith(color: Marks.savedWord)),
            ),
          if (quick != null)
            Text.rich(TextSpan(children: [
              if (quick.pos != null && quick.pos!.isNotEmpty) TextSpan(text: '(${quick.pos}) ', style: TextStyle(fontStyle: FontStyle.italic, color: theme.colorScheme.tertiary)),
              TextSpan(text: quick.vi, style: theme.textTheme.bodyLarge),
            ]))
          else if (r.entries.isNotEmpty && !_full)
            Text(r.entries.first.preview, style: theme.textTheme.bodyLarge)
          else if (!r.found)
            Text('Không có trong từ điển.', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
          if (r.family != null && !_full)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                r.family!.members.map((m) => m.pos.isEmpty ? m.word : '${m.word} (${m.pos})').join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 12),
          if (!_full && r.entries.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => setState(() => _full = true),
                icon: const Icon(Icons.expand_more),
                label: const Text('Xem nghĩa đầy đủ'),
              ),
            ),
          if (_full) ...[
            const Divider(),
            for (var i = 0; i < r.entries.length; i++) ...[
              if (i > 0) const Divider(height: 28),
              EntryView(entry: r.entries[i], family: i == 0 ? r.family : null, showHeadword: r.entries.length > 1),
            ],
          ],
        ],
      ),
    );
  }
}
