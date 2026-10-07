/// First-run screen while the content is not yet downloadable (docs/07 §11): pick `grammar.db`
/// (pictures are read from `dataset/img` next to it), or type its folder.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class DataDirPage extends StatefulWidget {
  final String? initial;
  final String? error;
  final void Function(String dir) onChosen;
  const DataDirPage({super.key, this.initial, this.error, required this.onChosen});

  @override
  State<DataDirPage> createState() => _DataDirPageState();
}

class _DataDirPageState extends State<DataDirPage> {
  late final _ctl = TextEditingController(text: widget.initial ?? '');
  String? _err;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Thư mục dữ liệu', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Chọn file grammar.db (ảnh bài học nằm trong thư mục dataset/img cạnh file). Khi phát triển, đó là content/grammar.db của repo sau khi chạy tool/content/pack.py.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _browse, icon: const Icon(Icons.file_open_outlined), label: const Text('Chọn file grammar.db…')),
              const SizedBox(height: 16),
              Text('hoặc nhập thư mục chứa grammar.db', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              TextField(
                controller: _ctl,
                decoration: InputDecoration(labelText: 'Đường dẫn', border: const OutlineInputBorder(), errorText: _err ?? widget.error),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _submit, child: const Text('Mở')),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _browse() async {
    final f = await FilePicker.pickFile(dialogTitle: 'Chọn file dữ liệu grammar.db', type: FileType.custom, allowedExtensions: const ['db']);
    final path = f?.path;
    if (path == null) return;
    _ctl.text = p.dirname(path);
    _submit();
  }

  void _submit() {
    final dir = _ctl.text.trim();
    if (!File(p.join(dir, 'grammar.db')).existsSync()) {
      setState(() => _err = 'Không thấy grammar.db trong thư mục này.');
      return;
    }
    widget.onChosen(dir);
  }
}
