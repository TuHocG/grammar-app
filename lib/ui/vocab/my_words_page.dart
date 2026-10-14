/// Từ Vựng Của Bạn → Xem Từ Chọn (docs/08 V1–V3, G11).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../widgets/word_tap_text.dart';
import '../widgets/shell.dart';
import 'edit_word_dialog.dart';

class MyWordsPage extends ConsumerStatefulWidget {
  const MyWordsPage({super.key});
  @override
  ConsumerState<MyWordsPage> createState() => _MyWordsPageState();
}

class _MyWordsPageState extends ConsumerState<MyWordsPage> {
  bool _markedOnly = false;
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userWordsProvider);
    final notifier = ref.read(userWordsProvider.notifier);
    final tts = ref.read(ttsProvider);
    final theme = Theme.of(context);
    var words = state.words;
    if (_markedOnly) words = words.where((w) => w.marked).toList();
    if (_filter.isNotEmpty) {
      final f = _filter.toLowerCase();
      words = words.where((w) => w.headword.toLowerCase().contains(f) || (w.meaning ?? '').toLowerCase().contains(f)).toList();
    }

    return Scaffold(
      appBar: GrammarAppBar(
        title: Text('Từ Vựng Của Bạn (${state.words.length})'),
        actions: [
          IconButton(
            tooltip: _markedOnly ? 'Hiện tất cả' : 'Chỉ từ đã đánh dấu',
            icon: Icon(_markedOnly ? Icons.star : Icons.star_border),
            onPressed: () => setState(() => _markedOnly = !_markedOnly),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'clear') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Xoá cả danh sách?'),
                    content: Text('${state.words.length} từ sẽ bị xoá.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xoá')),
                    ],
                  ),
                );
                if (ok == true) notifier.removeAll();
              }
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'clear', child: Text('Xoá cả danh sách'))],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Lọc', isDense: true, border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _filter = v.trim()),
            ),
          ),
        ),
      ),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        FloatingActionButton.extended(heroTag: 'spin', icon: const Icon(Icons.style), label: const Text('Quay Từ'), onPressed: () => context.push('/spin')),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
        heroTag: 'add',
        icon: const Icon(Icons.add),
        label: const Text('Từ mới'),
        onPressed: () => showEditWordDialog(context, ref),
      ),
      ]),
      body: words.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  state.words.isEmpty
                      ? 'Chưa có từ nào. Chạm vào một từ trong bài rồi bấm Lưu, hoặc bấm "Từ mới".'
                      : 'Không có từ nào khớp.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            )
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(children: [
                  Icon(Icons.star_border, size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Bấm ngôi sao để đánh dấu từ cần ôn trong Quay Từ.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
                ]),
              ),
              Expanded(
                child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: words.length,
              itemBuilder: (context, i) {
                final w = words[i];
                return Dismissible(
                  key: ValueKey(w.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: theme.colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
                  ),
                  onDismissed: (_) => notifier.remove(w.id),
                  child: _WordTile(word: w, index: i + 1, onSpeak: () => tts.speak(w.headword)),
                );
              },
                ),
              ),
            ]),
    );
  }
}

class _WordTile extends ConsumerWidget {
  final UserWord word;
  final int index;
  final VoidCallback onSpeak;
  const _WordTile({required this.word, required this.index, required this.onSpeak});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(userWordsProvider.notifier);
    final meaning = word.meaning ?? ref.read(contentDbProvider).quickDef(word.key)?.vi ?? ref.read(lookupProvider).lookup(word.headword).entries.firstOrNull?.preview ?? '';
    return ListTile(
      leading: SizedBox(width: 28, child: Text('$index', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
      title: Text.rich(TextSpan(children: [
        TextSpan(text: word.headword, style: TextStyle(fontWeight: FontWeight.w600, color: word.marked ? Marks.savedWord : null)),
        if (word.ipa != null && word.ipa!.isNotEmpty) TextSpan(text: '  /${word.ipa}/', style: TextStyle(color: theme.colorScheme.primary, fontSize: 13)),
      ])),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (meaning.isNotEmpty) Text(meaning.replaceAll('_', '\n'), maxLines: 2, overflow: TextOverflow.ellipsis),
        if (word.context != null && word.context!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: WordTapText(word.context!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
          ),
      ]),
      isThreeLine: word.context != null && word.context!.isNotEmpty,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: 'Đọc', icon: const Icon(Icons.volume_up), onPressed: onSpeak),
        IconButton(
          tooltip: word.marked ? 'Bỏ đánh dấu' : 'Đánh dấu để ôn (Quay Từ)',
          icon: Icon(word.marked ? Icons.star : Icons.star_border, color: word.marked ? Marks.savedWord : null),
          onPressed: () => notifier.setMarked(word.id, !word.marked),
        ),
      ]),
      onTap: () => context.push('/dict/word/${Uri.encodeComponent(word.headword)}'),
      onLongPress: () => showEditWordDialog(context, ref, existing: word),
    );
  }
}
