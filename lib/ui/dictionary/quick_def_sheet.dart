/// QuickDefSheet: quick meaning → full entry → save (docs/08 G3, G4, G5, G9). Shown as a
/// bottom sheet; the header keeps the old app's order `rubber ['rʌbə] (ráp bờ): cao su`,
/// with the Vietnamese respelling as a pill.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/lookup.dart';
import '../widgets/shell.dart';
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
    constraints: const BoxConstraints(maxWidth: 720),
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
    final g = context.g;
    final words = ref.watch(userWordsProvider);
    final saved = words.savedKeys.contains(r.key);
    final tts = ref.read(ttsProvider);
    final quick = r.quick;
    final userWord = ref.read(userDbProvider).wordByKey(r.key);

    void toggleSave() {
      final n = ref.read(userWordsProvider.notifier);
      if (saved) {
        n.removeByKey(r.key);
      } else {
        n.save(headword: r.headword, ipa: r.ipa, context: widget.contextSentence, source: widget.source);
      }
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: _full ? 0.85 : 0.42,
      minChildSize: 0.25,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 4, children: [
            Text(r.headword, style: ReadingStyles.line(context).copyWith(fontSize: 26, fontWeight: FontWeight.w600, color: saved ? g.savedWord : g.ink)),
            if (r.ipa != null && r.ipa!.isNotEmpty) Text('[${r.ipa}]', style: theme.textTheme.bodyLarge?.copyWith(color: g.iris)),
            if (quick?.respell != null && quick!.respell!.isNotEmpty) Respell(quick.respell!),
            RoundIconButton(icon: Icons.volume_up_outlined, tooltip: 'Đọc', size: 32, onPressed: () => tts.speak(r.headword)),
          ]),
          if (r.redirectedFrom != null)
            Text('${r.redirectedFrom} → ${r.headword}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          if (r.key != r.query.toLowerCase() && r.redirectedFrom == null && r.found)
            Text('${r.query} → ${r.headword}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          if (r.entryHeadword != null)
            Text('Mục đầy đủ: ${r.entryHeadword}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 10),
          if (userWord?.meaning != null && userWord!.meaning!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(userWord.meaning!.replaceAll('_', '\n'), style: theme.textTheme.bodyLarge?.copyWith(color: g.savedWord)),
            ),
          if (quick != null)
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              if (quick.pos != null && quick.pos!.isNotEmpty) ...[PosBadge(quick.pos!), const SizedBox(width: 8)],
              Expanded(child: Text(quick.vi, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17))),
            ])
          else if (r.entries.isNotEmpty && !_full)
            Text(r.entries.first.preview, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17))
          else if (!r.found)
            Text('Không có trong từ điển.', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
          if (r.family != null && !_full)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: g.border))),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Related forms · ', style: theme.textTheme.bodySmall),
                    for (var i = 0; i < r.family!.members.length; i++) ...[
                      if (i > 0) TextSpan(text: ' · ', style: theme.textTheme.bodySmall),
                      TextSpan(text: r.family!.members[i].word, style: theme.textTheme.bodyMedium?.copyWith(color: g.ink)),
                      if (r.family!.members[i].pos.isNotEmpty) TextSpan(text: ' ${r.family!.members[i].pos}', style: theme.textTheme.bodySmall),
                    ],
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (saved)
              FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: g.savedWord), onPressed: toggleSave, icon: const Icon(Icons.bookmark, size: 16), label: const Text('Đã lưu'))
            else
              FilledButton.icon(onPressed: toggleSave, icon: const Icon(Icons.bookmark_outline, size: 16), label: const Text('Lưu từ')),
            if (!_full && r.entries.isNotEmpty) OutlinedButton(onPressed: () => setState(() => _full = true), child: const Text('Mục đầy đủ')),
            if (r.found) OutlinedButton(onPressed: () => context.push('/dict/word/${Uri.encodeComponent(r.headword)}'), child: const Text('Mở trang từ điển')),
          ]),
          if (_full) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            for (var i = 0; i < r.entries.length; i++) ...[
              if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
              EntryView(entry: r.entries[i], family: i == 0 ? r.family : null, showHeadword: r.entries.length > 1),
            ],
          ],
        ],
      ),
    );
  }
}
