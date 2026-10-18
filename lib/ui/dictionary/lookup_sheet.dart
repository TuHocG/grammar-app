/// Tra nhanh from any page (the 🔍 of the top bar): a bottom sheet with a search field and
/// the dictionary list around what is typed, each row with its short meaning. Tapping a row
/// opens the quick definition on top, so closing it returns to the search for the next word;
/// "Mở Từ điển" leaves for the full dictionary page. On a keyboard, ↑ / ↓ pick a row and
/// Enter opens it.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/search_key.dart';
import '../widgets/list_arrow_keys.dart';
import '../widgets/shell.dart';
import 'quick_def_sheet.dart';

Future<void> showLookupSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 720),
  builder: (_) => const LookupSheet(),
);

class LookupSheet extends ConsumerStatefulWidget {
  const LookupSheet({super.key});
  @override
  ConsumerState<LookupSheet> createState() => _LookupSheetState();
}

class _LookupSheetState extends ConsumerState<LookupSheet> {
  final _ctl = TextEditingController();
  Timer? _debounce;
  String _key = '';
  List<DictHit> _hits = const [];

  /// Row picked with ↑ / ↓; -1 = none, Enter then goes by what is typed.
  int _active = -1;
  final _activeKey = GlobalKey();

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    // Right away, not after the debounce: Enter must not open a row picked for older text.
    _active = -1;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final key = searchKey(text);
      setState(() {
        _key = key;
        _hits = key.isEmpty ? const [] : ref.read(contentDbProvider).around(key, before: 0, after: 40);
        _active = -1;
      });
    });
  }

  void _show(String word) => showQuickDef(context, ref, word, source: 'lookup');

  /// Enter: the exact word if listed, else the first word starting with the text, else
  /// whatever was typed (the lookup also tries base forms).
  void _submit() {
    if (_active >= 0 && _active < _hits.length) return _show(_hits[_active].headword);
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    final key = searchKey(text);
    final hit = _hits.where((h) => h.key == key).firstOrNull ?? _hits.where((h) => h.key.startsWith(key)).firstOrNull;
    _show(hit?.headword ?? text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.g;
    final saved = ref.watch(userWordsProvider).savedKeys;
    // 70 % of the screen, but never taller than the room left above the keyboard (a phone
    // held sideways keeps only a strip): the list shrinks first, the field always fits.
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final room = mq.size.height - keyboard - mq.padding.top - 64; // 64: drag handle + gap
    final content = min(mq.size.height * 0.7, max(room, 72.0));
    return SizedBox(
      height: content + keyboard,
      child: Padding(
        // Keeps the list above the on-screen keyboard.
        padding: EdgeInsets.only(bottom: keyboard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ListArrowKeys(
                count: _hits.length,
                active: _active,
                onActive: (i) => setState(() => _active = i),
                activeKey: _activeKey,
                child: SearchPill(
                  controller: _ctl,
                  autofocus: true,
                  hint: 'Gõ từ tiếng Anh cần tra…',
                  onChanged: (v) {
                    _onChanged(v);
                    setState(() {});
                  },
                  onSubmitted: (_) => _submit(),
                  trailing: _ctl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Xoá',
                          onPressed: () {
                            _ctl.clear();
                            _onChanged('');
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: _key.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Gõ vài chữ cái đầu, rồi chạm từ cần xem nghĩa.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: g.slate),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _hits.length,
                      itemBuilder: (context, i) {
                        final h = _hits[i];
                        final isPrefix = h.key.startsWith(_key);
                        final isSaved = saved.contains(h.key);
                        return Material(
                          key: i == _active ? _activeKey : null,
                          color: i == _active ? g.lilac : Colors.transparent,
                          child: InkWell(
                            onTap: () => _show(h.headword),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    h.headword,
                                    style: ReadingStyles.line(context)
                                        .copyWith(fontSize: 17, fontWeight: isPrefix || isSaved ? FontWeight.w600 : FontWeight.w400, color: isSaved ? g.savedWord : (isPrefix ? g.ink : g.fog)),
                                  ),
                                  if (h.ipa != null && h.ipa!.isNotEmpty) ...[const SizedBox(width: 10), Text('/${h.ipa}/', style: theme.textTheme.bodySmall?.copyWith(color: g.iris))],
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(h.preview, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: theme.textTheme.bodySmall),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // While typing the keyboard needs the room; Enter or a tap on a word does the lookup.
            if (keyboard == 0)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        final q = _ctl.text.trim();
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push(q.isEmpty ? '/dict' : '/dict?q=${Uri.encodeQueryComponent(q)}');
                      },
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('Mở Từ điển'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
