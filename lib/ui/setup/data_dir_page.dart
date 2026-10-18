/// First-run screen while the content is not yet downloadable (docs/07 §11): pick or type the
/// data folder (grammar.db, and grammar.images for the illustrations).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../data/image_pack.dart';
import '../settings/data_picker.dart';

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Thư mục dữ liệu', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Tải grammar.db và $imagePackName (ảnh minh hoạ) vào cùng một thư mục rồi chọn thư mục đó. '
                  'Khi phát triển, đó là content/grammar.db của repo sau khi chạy tool/content/pack.py.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: _browse, icon: const Icon(Icons.folder_open_outlined), label: const Text(pickDataLabel)),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _browse() async {
    final String? dir;
    try {
      dir = await pickDataFolder(context);
    } catch (e) {
      if (mounted) setState(() => _err = 'Không mở được hộp thoại chọn thư mục: $e');
      return;
    }
    if (dir == null || !mounted) return;
    _ctl.text = dir;
    _submit();
  }

  Future<void> _submit() async {
    final dir = _ctl.text.trim();
    if (!await ensureStorageAccess(context) || !mounted) return;
    if (!File(p.join(dir, 'grammar.db')).existsSync()) {
      setState(() => _err = 'Không thấy grammar.db trong thư mục này.');
      return;
    }
    widget.onChosen(dir);
  }
}
