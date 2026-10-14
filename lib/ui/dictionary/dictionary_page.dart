/// Dictionary search: type → list scrolled to the typed text (docs/08 G2). On wide screens
/// the list sits on the left and the selected entry opens on the right.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/search_key.dart';
import '../../domain/lookup.dart';
import '../widgets/shell.dart';
import 'entry_page.dart';

class DictionaryPage extends ConsumerStatefulWidget {
  final String? initialQuery;
  const DictionaryPage({super.key, this.initialQuery});

  @override
  ConsumerState<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends ConsumerState<DictionaryPage> {
  late final TextEditingController _ctl = TextEditingController(text: widget.initialQuery ?? '');
  final _focus = FocusNode();
  Timer? _debounce;
  List<DictHit> _hits = const [];
  String _key = '';
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _search(_ctl.text);
    // Put the caret at the end so typing continues the query that opened the page.
    _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () => _search(text));
  }

  void _search(String text) {
    final key = searchKey(text);
    final db = ref.read(contentDbProvider);
    setState(() {
      _key = key;
      _hits = key.isEmpty ? db.around('a', before: 0, after: 100) : db.around(key, before: 3, after: 120);
      _selectedId = null;
    });
  }

  void _open(DictHit h) {
    if (context.isWide) {
      setState(() => _selectedId = h.id);
    } else {
      context.push('/dict/${h.id}');
    }
  }

  void _openFirstExact() {
    final exact = _hits.where((h) => h.key == _key).firstOrNull;
    if (exact != null) {
      _open(exact);
    } else if (_key.isNotEmpty) {
      if (context.isWide && _hits.isNotEmpty) {
        _open(_hits.firstWhere((h) => h.key.startsWith(_key), orElse: () => _hits.first));
      } else {
        context.push('/dict/word/${Uri.encodeComponent(_ctl.text.trim())}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(userWordsProvider).savedKeys;
    final theme = Theme.of(context);
    final g = context.g;
    final wide = context.isWide;

    final field = SearchPill(
      controller: _ctl,
      focusNode: _focus,
      autofocus: true,
      hint: 'Gõ từ cần tra…',
      onChanged: (v) {
        _onChanged(v);
        setState(() {});
      },
      onSubmitted: (_) => _openFirstExact(),
      trailing: _ctl.text.isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Xoá',
              onPressed: () {
                _ctl.clear();
                _search('');
              },
            ),
    );

    final list = ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _hits.length,
      itemBuilder: (context, i) {
        final h = _hits[i];
        final isPrefix = _key.isNotEmpty && h.key.startsWith(_key);
        final isSaved = saved.contains(h.key);
        final selected = h.id == _selectedId;
        final hwColor = isSaved ? g.savedWord : (isPrefix || _key.isEmpty ? g.ink : g.fog);
        return Material(
          color: selected ? g.lilac : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: () => _open(h),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(h.headword, style: ReadingStyles.line(context).copyWith(fontSize: 17, fontWeight: isPrefix || isSaved ? FontWeight.w600 : FontWeight.w400, color: hwColor)),
                if (h.ipa != null && h.ipa!.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text('/${h.ipa}/', style: theme.textTheme.bodySmall?.copyWith(color: g.iris)),
                ],
                if (h.preview.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(child: Text(h.preview, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: theme.textTheme.bodySmall)),
                ],
              ]),
            ),
          ),
        );
      },
    );

    if (!wide) {
      return Scaffold(
        appBar: GrammarAppBar(search: false, helpSlug: 'tu-dien', title: Padding(padding: const EdgeInsets.only(right: 4), child: field)),
        body: list,
      );
    }

    final db = ref.read(contentDbProvider);
    LookupResult? result;
    if (_selectedId != null) {
      final e = db.entryById(_selectedId!);
      if (e != null) result = ref.read(lookupProvider).lookup(e.isRedirect ? e.redirect! : e.headword);
    }

    return Scaffold(
      appBar: GrammarAppBar(
        search: false,
        crumbs: const [Crumb('Từ điển')],
        helpSlug: 'tu-dien',
        actions: [
          Text('Gõ ở bất kỳ màn hình nào để tra', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)),
        ],
      ),
      body: PageRail(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 400,
            child: Surface(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                field,
                const SizedBox(height: 8),
                SizedBox(height: MediaQuery.sizeOf(context).height - 56 - 48 - 24 - 56 - 60, child: list),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('Danh sách cuộn tới đúng chữ bạn gõ. Enter mở mục đầu tiên. Từ đã lưu tô đỏ.', style: theme.textTheme.bodySmall?.copyWith(color: g.fog)),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: result == null
                ? Surface(
                    padding: const EdgeInsets.all(40),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.search, size: 40, color: g.fog),
                      const SizedBox(height: 12),
                      Text('Chọn một từ bên trái để xem mục từ.', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
                      const SizedBox(height: 4),
                      Text('Thứ tự tra: nghĩa nhanh → mục đầy đủ → dạng gốc → họ từ', style: theme.textTheme.bodySmall),
                    ]),
                  )
                : SingleChildScrollView(child: EntryCard(result: result)),
          ),
        ]),
      ),
    );
  }
}
