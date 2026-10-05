/// Dictionary search: type → list scrolled to the typed text (docs/08 G2).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/search_key.dart';

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

  @override
  void initState() {
    super.initState();
    _search(_ctl.text);
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
    });
  }

  void _openFirstExact() {
    final exact = _hits.where((h) => h.key == _key).firstOrNull;
    if (exact != null) {
      context.push('/dict/${exact.id}');
    } else if (_key.isNotEmpty) {
      context.push('/dict/word/${Uri.encodeComponent(_ctl.text.trim())}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(userWordsProvider).savedKeys;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctl,
          focusNode: _focus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Gõ từ cần tra…',
            border: InputBorder.none,
            suffixIcon: _ctl.text.isEmpty
                ? null
                : IconButton(icon: const Icon(Icons.clear), onPressed: () { _ctl.clear(); _search(''); }),
          ),
          onChanged: _onChanged,
          onSubmitted: (_) => _openFirstExact(),
        ),
      ),
      body: ListView.builder(
        itemCount: _hits.length,
        itemBuilder: (context, i) {
          final h = _hits[i];
          final isPrefix = _key.isNotEmpty && h.key.startsWith(_key);
          final isSaved = saved.contains(h.key);
          return ListTile(
            title: Text.rich(TextSpan(children: [
              TextSpan(
                text: h.headword,
                style: TextStyle(
                  fontWeight: isPrefix ? FontWeight.w600 : FontWeight.normal,
                  color: isSaved ? Marks.savedWord : (isPrefix ? null : theme.colorScheme.outline),
                ),
              ),
              if (h.ipa != null && h.ipa!.isNotEmpty)
                TextSpan(text: '  /${h.ipa}/', style: TextStyle(color: theme.colorScheme.primary, fontSize: 13)),
            ])),
            subtitle: h.preview.isEmpty ? null : Text(h.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => context.push('/dict/${h.id}'),
          );
        },
      ),
    );
  }
}
