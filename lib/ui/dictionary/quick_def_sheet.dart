/// QuickDefSheet: quick meaning → full entry → save (docs/08 G3, G4, G5, G9). Shown as a
/// bottom sheet; the header keeps the old app's order `rubber ['rʌbə] (ráp bờ): cao su`,
/// with the Vietnamese respelling as a pill.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/search_key.dart';
import '../../domain/lookup.dart';
import '../vocab/edit_word_dialog.dart';
import '../vocab/word_hint.dart';
import '../widgets/shell.dart';
import 'entry_view.dart';

Future<void> showQuickDef(BuildContext context, WidgetRef ref, String word, {String? contextSentence, String? source, String? fallbackVi}) async {
  final result = ref.read(lookupProvider).lookup(word);
  final saved = ref.read(userWordsProvider).savedKeys;
  final mine = saved.contains(searchKey(result.query)) || saved.contains(result.key);
  if (!result.found && !mine && fallbackVi != null && fallbackVi.trim().isNotEmpty) {
    // Not a dictionary word (a phonetic symbol, "[ˈbæksifɔ:m]"): show what the reading
    // itself says about it, as the old app does in the IPA lessons.
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (_) => _FallbackSheet(token: word.trim(), vi: fallbackVi.trim()),
    );
    return;
  }
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

/// Token + the sentence's Vietnamese line, for tokens the dictionary does not know.
class _FallbackSheet extends StatelessWidget {
  final String token;
  final String vi;
  const _FallbackSheet({required this.token, required this.vi});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.g;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(token, style: ReadingStyles.line(context).copyWith(fontSize: 26, fontWeight: FontWeight.w600, color: g.ink)),
        const SizedBox(height: 10),
        Text(vi, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18, color: g.indigo)),
      ]),
    );
  }
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
  /// F2 edits what was tapped when that is saved or unknown to the dictionary, else the
  /// dictionary's headword.
  late final WordHint _hint = (
    word: !widget.result.found || ref.read(userWordsProvider).savedKeys.contains(searchKey(widget.result.query)) ? widget.result.query : widget.result.headword,
    context: widget.contextSentence,
    source: widget.source,
  );

  @override
  void initState() {
    super.initState();
    WordHints.lookedUp.value = _hint;
  }

  @override
  void dispose() {
    if (WordHints.lookedUp.value == _hint) WordHints.lookedUp.value = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final theme = Theme.of(context);
    final g = context.g;
    final words = ref.watch(userWordsProvider);
    // The user's own entry for exactly what was tapped ("rowing", saved with F2) wins over
    // the dictionary's base form ("row"); otherwise the entry of the looked-up word.
    final tappedKey = searchKey(r.query);
    final uKey = words.savedKeys.contains(tappedKey) ? tappedKey : r.key;
    final saved = words.savedKeys.contains(uKey);
    final tts = ref.read(ttsProvider);
    final quick = r.quick;
    final userWord = ref.read(userDbProvider).wordByKey(uKey);
    final hasOwnMeaning = userWord?.meaning != null && userWord!.meaning!.isNotEmpty;

    void toggleSave() {
      final n = ref.read(userWordsProvider.notifier);
      if (saved) {
        n.removeByKey(uKey);
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
            Text(userWord?.headword ?? r.headword, style: ReadingStyles.line(context).copyWith(fontSize: 26, fontWeight: FontWeight.w600, color: saved ? g.savedWord : g.ink)),
            if ((userWord?.ipa ?? r.ipa) case final ipa? when ipa.isNotEmpty) Text('[$ipa]', style: theme.textTheme.bodyLarge?.copyWith(color: g.iris)),
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
          if (hasOwnMeaning)
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
          else if (!r.found && !hasOwnMeaning)
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
            OutlinedButton.icon(
              onPressed: () => openWordEditor(context, ref, userWord?.headword ?? r.headword, contextSentence: widget.contextSentence, source: widget.source),
              icon: const Icon(Icons.edit_note, size: 18),
              label: Text(saved ? 'Sửa từ (F2)' : 'Thêm với nghĩa riêng (F2)'),
            ),
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
