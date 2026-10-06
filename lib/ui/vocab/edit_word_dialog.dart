/// Create or edit a user word (old app: F2 "Từ Anh: nghĩa Việt", docs/08 G11).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

Future<void> showEditWordDialog(BuildContext context, WidgetRef ref, {UserWord? existing, String? initialWord}) async {
  final wordCtl = TextEditingController(text: existing?.headword ?? initialWord ?? '');
  final meaningCtl = TextEditingController(text: existing?.meaning ?? '');
  final ipaCtl = TextEditingController(text: existing?.ipa ?? '');
  final formKey = GlobalKey<FormState>();

  void autofill() {
    final r = ref.read(lookupProvider).lookup(wordCtl.text);
    if (!r.found) return;
    if (ipaCtl.text.isEmpty && r.ipa != null) ipaCtl.text = r.ipa!;
    if (meaningCtl.text.isEmpty) {
      meaningCtl.text = r.quick?.vi ?? r.entries.firstOrNull?.preview ?? '';
    }
  }

  final saved = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(existing == null ? 'Từ mới' : 'Sửa từ'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: wordCtl,
              autofocus: existing == null,
              decoration: const InputDecoration(labelText: 'Từ Anh', hintText: 'wash'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập từ' : null,
              onEditingComplete: autofill,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: ipaCtl,
              decoration: InputDecoration(
                labelText: 'Phiên âm',
                hintText: 'wɔʃ',
                suffixIcon: IconButton(tooltip: 'Lấy phiên âm và nghĩa từ từ điển', icon: const Icon(Icons.auto_fix_high), onPressed: autofill),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: meaningCtl,
              decoration: const InputDecoration(
                labelText: 'Nghĩa Việt',
                hintText: 'rửa, giặt',
                helperText: 'Dấu _ = xuống dòng',
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: 6,
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(c, true);
          },
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
  if (saved == true) {
    final n = ref.read(userWordsProvider.notifier);
    final meaning = meaningCtl.text.trim().isEmpty ? null : meaningCtl.text.trim();
    if (existing != null && existing.headword != wordCtl.text.trim()) n.remove(existing.id);
    n.save(
      headword: wordCtl.text.trim(),
      meaning: meaning,
      ipa: ipaCtl.text.trim().isEmpty ? null : ipaCtl.text.trim(),
      source: existing?.source ?? 'user',
      marked: existing?.marked,
    );
    if (existing != null && meaning == null) n.setMeaning(existing.id, null);
  }
  wordCtl.dispose();
  meaningCtl.dispose();
  ipaCtl.dispose();
}
