/// "Cách Ðọc Phiên Âm Quốc Tế": its own home-menu item (`/ipa`), built from the single
/// reading of section sid 0 (docs/08 R2), hidden from the Bài Đọc tree. It is a lesson,
/// not a reading: the text is Vietnamese instruction, the "sentences" are phonetic symbols and
/// example words, and the Vietnamese line of each is its reading. So: no sentence numbers,
/// no sentence player; symbols are chips that reveal "Ðọc là …", example words are rows
/// that reveal their Vietnamese respelling and read the English word aloud in one tap.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/models.dart';
import '../widgets/shell.dart';

enum _Kind { prose, symbol, example }

class _Item {
  final _Kind kind;
  final Sentence s;
  /// symbol: the symbol itself; example: the English word.
  final String head;
  /// symbol: "sờ (uốn cong lưỡi)." (after "Ðọc là:") or a whole explanation
  /// ("Ðọc kéo dài âm trước nó."); example: IPA between the brackets.
  final String detail;
  /// symbol: true when [detail] followed "Ðọc là:" (the panel then says "đọc là").
  final bool docLa;
  /// example: the Vietnamese respelling without its brackets.
  final String reading;
  const _Item(this.kind, this.s, {this.head = '', this.detail = '', this.docLa = false, this.reading = ''});
}

final _symbolRe = RegExp(r'^(\S{1,5})\s+\.$');   // "ʃ  .", ":  .", "'  ."

final _exampleRe = RegExp(r'^(\S+)\s+\[(.+)\]$');
final _docLaRe = RegExp(r'^Ð?Đ?ọc là:\s*', caseSensitive: false);

List<_Item> _classify(List<Sentence> sentences) {
  final out = <_Item>[];
  for (final s in sentences) {
    final en = s.en.trim(), vi = s.vi.trim();
    final sym = _symbolRe.firstMatch(en);
    if (sym != null && vi.isNotEmpty) {
      final docLa = _docLaRe.hasMatch(vi);
      out.add(_Item(_Kind.symbol, s, head: sym.group(1)!, detail: docLa ? vi.replaceFirst(_docLaRe, '') : vi, docLa: docLa));
      continue;
    }
    final ex = _exampleRe.firstMatch(en);
    if (ex != null && vi.startsWith('[')) {
      out.add(_Item(_Kind.example, s, head: ex.group(1)!, detail: ex.group(2)!, reading: vi.replaceAll(RegExp(r'^\[|\]$'), '')));
      continue;
    }
    out.add(_Item(_Kind.prose, s));
  }
  return out;
}

class IpaLessonPage extends ConsumerStatefulWidget {
  /// Reading id; null = the first reading of section 0.
  final int? id;
  const IpaLessonPage({super.key, this.id});
  @override
  ConsumerState<IpaLessonPage> createState() => _IpaLessonPageState();
}

class _IpaLessonPageState extends ConsumerState<IpaLessonPage> {
  Reading? _reading;
  late List<_Item> _items;
  int? _symbol;          // idx of the selected symbol
  final Set<int> _shown = {};   // example rows with their reading revealed
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    final db = ref.read(contentDbProvider);
    final id = widget.id ?? db.readingsInSection(0).firstOrNull?.id;
    _reading = id == null ? null : db.reading(id);
    _items = _reading == null ? const [] : _classify(_reading!.sentences);
  }

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    if (r == null) return const Scaffold(body: EmptyNote('Không có bài này.'));
    final theme = Theme.of(context);
    final g = context.g;
    final wide = context.isWide;
    final blocks = <Widget>[];

    // Group consecutive items of one kind into blocks.
    var i = 0;
    while (i < _items.length) {
      final kind = _items[i].kind;
      var j = i;
      while (j < _items.length && _items[j].kind == kind) {
        j++;
      }
      final run = _items.sublist(i, j);
      switch (kind) {
        case _Kind.prose:
          for (final it in run) {
            blocks.add(Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(it.s.en, style: ReadingStyles.passage(context)),
            ));
          }
        case _Kind.symbol:
          blocks.add(_symbolBlock(run, theme, g));
        case _Kind.example:
          blocks.add(_exampleBlock(run, theme, g));
      }
      i = j;
    }

    return Scaffold(
      appBar: GrammarAppBar(
        crumbs: const [Crumb('Phiên Âm Quốc Tế')],
        actions: [
          RoundIconButton(icon: Icons.help_outline, tooltip: 'Hướng dẫn', onPressed: () => context.push('/help/phien-am')),
        ],
      ),
      body: RailListView(children: [
        Surface(
          padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 20, vertical: wide ? 32 : 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(r.title, style: ReadingStyles.title(context)),
            const SizedBox(height: 16),
            ...blocks,
          ]),
        ),
      ]),
    );
  }

  Widget _symbolBlock(List<_Item> run, ThemeData theme, GrammarColors g) {
    final sel = _symbol == null ? null : run.where((it) => it.s.idx == _symbol).firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Chạm một ký hiệu để xem cách đọc.', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final it in run)
            _SymbolChip(
              text: it.head,
              selected: it.s.idx == _symbol,
              onTap: () => setState(() => _symbol = _symbol == it.s.idx ? null : it.s.idx),
            ),
        ]),
        if (sel != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: LilacPanel(
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(sel.head, style: ReadingStyles.line(context).copyWith(fontSize: 26, fontWeight: FontWeight.w600, color: g.iris)),
                const SizedBox(width: 16),
                if (sel.docLa) ...[
                  Text('đọc là', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)),
                  const SizedBox(width: 10),
                ],
                Expanded(child: Text(sel.detail, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18, color: g.indigo, fontWeight: FontWeight.w600))),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _exampleBlock(List<_Item> run, ThemeData theme, GrammarColors g) {
    final tts = ref.read(ttsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Chạm một từ: nghe từ và xem cách đọc tiếng Việt.', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate))),
          Text('Hiện tất cả', style: theme.textTheme.bodyMedium),
          const SizedBox(width: 4),
          Switch(value: _showAll, onChanged: (v) => setState(() => _showAll = v)),
        ]),
        const SizedBox(height: 6),
        for (final it in run)
          _ExampleRow(
            word: it.head,
            ipa: it.detail,
            reading: it.reading,
            revealed: _showAll || _shown.contains(it.s.idx),
            // One tap: reveal the respelling (it stays) and read the word.
            onTap: () {
              setState(() => _shown.add(it.s.idx));
              tts.speak(it.head);
            },
          ),
      ]),
    );
  }
}

class _SymbolChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _SymbolChip({required this.text, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    return Material(
      color: selected ? g.iris : g.canvas,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: selected ? g.iris : g.border)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        // ConstrainedBox + Center(widthFactor/heightFactor): a Container(alignment:) would
        // grow to the Wrap's full width.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(text, style: ReadingStyles.line(context).copyWith(fontSize: 22, fontWeight: FontWeight.w600, color: selected ? Colors.white : g.ink)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExampleRow extends StatelessWidget {
  final String word;
  final String ipa;
  final String reading;
  final bool revealed;
  final VoidCallback onTap;
  const _ExampleRow({required this.word, required this.ipa, required this.reading, required this.revealed, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final theme = Theme.of(context);
    return Material(
      color: revealed ? g.lilac : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 14, runSpacing: 4, children: [
            Text(word, style: ReadingStyles.line(context).copyWith(fontSize: 20, fontWeight: FontWeight.w600, color: g.ink)),
            Text('[$ipa]', style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18, color: g.iris)),
            if (revealed)
              Respell(reading, fontSize: 16)
            else
              Icon(Icons.volume_up_outlined, size: 18, color: g.fog),
          ]),
        ),
      ),
    );
  }
}
