/// First-run screen while the content is not yet downloadable (docs/07 §11): ask for the
/// folder that contains `grammar.db` and `dataset/`.
library;

import 'dart:io';

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
                'Chọn thư mục chứa grammar.db và dataset/ (thường là thư mục dist của repo khi đang phát triển).',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ctl,
                decoration: InputDecoration(labelText: 'Đường dẫn', border: const OutlineInputBorder(), errorText: _err ?? widget.error),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _submit, child: const Text('Mở')),
            ]),
          ),
        ),
      ),
    );
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
