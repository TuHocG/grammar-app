/// Create or edit a user word (old app: F2 "Từ Anh: nghĩa Việt", docs/08 G11). Opened from
/// Từ Vựng Của Bạn, from the dictionary sheet ("Sửa từ") and anywhere with F2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import '../../data/search_key.dart';

typedef _Result = ({String word, String ipa, String meaning});

/// Editor for [word]: the saved entry when there is one, else a new one pre-filled from the
/// dictionary; [contextSentence] / [source] are stored with a new word.
Future<void> openWordEditor(BuildContext context, WidgetRef ref, String? word, {String? contextSentence, String? source}) {
  final w = word?.trim() ?? '';
  final existing = w.isEmpty ? null : ref.read(userDbProvider).wordByKey(searchKey(w));
  return showEditWordDialog(context, ref, existing: existing, initialWord: w.isEmpty ? null : w, contextSentence: contextSentence, source: source);
}

Future<void> showEditWordDialog(BuildContext context, WidgetRef ref, {UserWord? existing, String? initialWord, String? contextSentence, String? source}) async {
  final result = await showDialog<_Result>(
    context: context,
    builder: (_) => _EditWordDialog(existing: existing, initialWord: initialWord),
  );
  if (result == null) return;
  final n = ref.read(userWordsProvider.notifier);
  final meaning = result.meaning.isEmpty ? null : result.meaning;
  if (existing != null && existing.headword != result.word) n.remove(existing.id);
  n.save(
    headword: result.word,
    meaning: meaning,
    ipa: result.ipa.isEmpty ? null : result.ipa,
    context: existing == null ? contextSentence : null,
    source: existing?.source ?? source ?? 'user',
    marked: existing?.marked,
  );
  if (existing != null && meaning == null) n.setMeaning(existing.id, null);
}

/// Owns the text controllers so they outlive the dialog's closing animation (disposing
/// them right after `showDialog` returned made the still-animating fields touch a
/// disposed controller and crash the debug build).
class _EditWordDialog extends ConsumerStatefulWidget {
  final UserWord? existing;
  final String? initialWord;
  const _EditWordDialog({this.existing, this.initialWord});
  @override
  ConsumerState<_EditWordDialog> createState() => _EditWordDialogState();
}

class _EditWordDialogState extends ConsumerState<_EditWordDialog> {
  late final TextEditingController _word = TextEditingController(text: widget.existing?.headword ?? widget.initialWord ?? '');
  late final TextEditingController _ipa = TextEditingController(text: widget.existing?.ipa ?? '');
  late final TextEditingController _meaning = TextEditingController(text: widget.existing?.meaning ?? '');
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // F2 on a word: phonetics and meaning come from the dictionary right away.
    if (widget.existing == null && (widget.initialWord ?? '').isNotEmpty) _autofill();
  }

  @override
  void dispose() {
    _word.dispose();
    _ipa.dispose();
    _meaning.dispose();
    super.dispose();
  }

  void _autofill() {
    final r = ref.read(lookupProvider).lookup(_word.text);
    if (!r.found) return;
    if (_ipa.text.isEmpty && r.ipa != null) _ipa.text = r.ipa!;
    if (_meaning.text.isEmpty) {
      _meaning.text = r.quick?.vi ?? r.entries.firstOrNull?.preview ?? '';
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (word: _word.text.trim(), ipa: _ipa.text.trim(), meaning: _meaning.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Từ mới' : 'Sửa từ'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _word,
                autofocus: widget.existing == null && (widget.initialWord ?? '').isEmpty,
                decoration: const InputDecoration(labelText: 'Từ Anh', hintText: 'wash'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập từ' : null,
                onEditingComplete: _autofill,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ipa,
                decoration: InputDecoration(
                  labelText: 'Phiên âm',
                  hintText: 'wɔʃ',
                  suffixIcon: IconButton(tooltip: 'Lấy phiên âm và nghĩa từ từ điển', icon: const Icon(Icons.auto_fix_high), onPressed: _autofill),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _meaning,
                decoration: const InputDecoration(labelText: 'Nghĩa Việt', hintText: 'rửa, giặt', helperText: 'Dấu _ = xuống dòng', alignLabelWithHint: true),
                minLines: 3,
                maxLines: 6,
                autofocus: widget.existing != null || (widget.initialWord ?? '').isNotEmpty,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        FilledButton(onPressed: _submit, child: const Text('Lưu')),
      ],
    );
  }
}
