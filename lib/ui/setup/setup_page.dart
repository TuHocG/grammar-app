/// First-run screen of the desktop and mobile apps (docs/07 §12): download the lesson data into
/// the app's own folder, or pick a folder that already holds grammar.db (and grammar.images).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/config.dart';
import '../../data/bytes.dart';
import '../../data/image_pack.dart';
import '../../data/release_bundle.dart';
import '../../platform/downloader_io.dart';
import '../settings/data_picker.dart';
import 'download_dialog.dart';

class SetupPage extends StatefulWidget {
  final String? initial;
  final String? error;
  final void Function(String dir) onChosen;
  const SetupPage({super.key, this.initial, this.error, required this.onChosen});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  late final _ctl = TextEditingController(text: widget.initial ?? '');
  String? _err;
  ContentDownloader? _downloader;
  ReleaseBundle? _bundle;
  String? _bundleError;

  @override
  void initState() {
    super.initState();
    _lookUp();
  }

  @override
  void dispose() {
    _downloader?.close();
    super.dispose();
  }

  /// Asks the release host what there is to download.
  Future<void> _lookUp() async {
    setState(() {
      _bundle = null;
      _bundleError = null;
    });
    try {
      final d = _downloader ??= await ContentDownloader.forApp(Uri.parse(grammarDataUrl));
      final b = await d.fetchBundle();
      if (mounted) setState(() => _bundle = b);
    } catch (e) {
      if (mounted) setState(() => _bundleError = e is SocketException ? 'Không kết nối được máy chủ (không có mạng?).' : '$e');
    }
  }

  Future<void> _download() async {
    final dir = await runDownload(context, _downloader!, _bundle!);
    if (dir != null) widget.onChosen(dir);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = _bundle;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Dữ liệu bài học', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('App chưa có bài học. Tải về một lần (khoảng ${formatBytes(b?.downloadBytes ?? 150 << 20)}), hoặc chọn thư mục đã tải sẵn.', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                if (b != null)
                  Text('Bản ${b.contentVersion}${b.date.isNotEmpty ? ' · ${b.date}' : ''} · ${formatBytes(b.downloadBytes)}', style: theme.textTheme.bodySmall)
                else if (_bundleError != null)
                  Text(_bundleError!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error))
                else
                  Text('Đang hỏi máy chủ…', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(onPressed: b == null ? null : _download, icon: const Icon(Icons.download), label: const Text('Tải dữ liệu')),
                    ),
                    if (_bundleError != null) ...[const SizedBox(width: 8), OutlinedButton(onPressed: _lookUp, child: const Text('Thử lại'))],
                  ],
                ),
                const SizedBox(height: 24),
                Text('Đã có sẵn grammar.db?', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Tải grammar.db và $imagePackName (ảnh minh hoạ) vào cùng một thư mục rồi chọn thư mục đó. '
                  'Khi phát triển, đó là content/grammar.db của repo sau khi chạy tool/content/pack.py.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: _browse, icon: const Icon(Icons.folder_open_outlined), label: const Text(pickDataLabel)),
                const SizedBox(height: 12),
                TextField(
                  controller: _ctl,
                  decoration: InputDecoration(labelText: 'Hoặc gõ đường dẫn thư mục', border: const OutlineInputBorder(), errorText: _err ?? widget.error),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _submit, child: const Text('Mở')),
                ),
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
