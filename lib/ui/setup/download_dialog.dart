/// A dialog that runs a data download with a progress bar (first run and Cài Đặt → Dữ liệu).
library;

import 'package:flutter/material.dart';

import '../../data/bytes.dart';
import '../../data/download_progress.dart';
import '../../data/release_bundle.dart';
import '../../platform/downloader_io.dart';

/// Downloads [b] with [d]; the data folder when done, null when stopped or failed (the failure
/// was shown). The dialog only closes once the download has really stopped, so a second one
/// never writes the same files.
Future<String?> runDownload(BuildContext context, ContentDownloader d, ReleaseBundle b) => showDialog<String>(context: context, barrierDismissible: false, builder: (_) => _DownloadDialog(d, b));

class _DownloadDialog extends StatefulWidget {
  final ContentDownloader downloader;
  final ReleaseBundle bundle;
  const _DownloadDialog(this.downloader, this.bundle);

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  DownloadProgress? _progress;
  String? _error;
  bool _running = false;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _running = true;
    });
    try {
      final dir = await widget.downloader.install(
        widget.bundle,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) Navigator.of(context).pop(dir);
    } on DownloadCancelled {
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _running = false;
        });
      }
    }
  }

  void _stop() {
    if (_stopping) return;
    setState(() => _stopping = true);
    widget.downloader.cancel(); // _run then pops the dialog
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _running ? _stop() : Navigator.of(context).pop();
      },
      child: AlertDialog(
        title: Text('Tải dữ liệu ${widget.bundle.contentVersion}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: p?.fraction),
            const SizedBox(height: 8),
            Text(
              _stopping
                  ? 'Đang dừng…'
                  : p == null
                  ? 'Đang bắt đầu…'
                  : '${formatBytes(p.done)} / ${formatBytes(p.total)}${p.item != null ? ' · ${p.item}' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            if (_error != null) ...[const SizedBox(height: 8), SelectableText(_error!, style: TextStyle(color: theme.colorScheme.error))],
          ],
        ),
        actions: _running
            ? [TextButton(onPressed: _stopping ? null : _stop, child: const Text('Dừng'))]
            : [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng')), FilledButton(onPressed: _run, child: const Text('Tải tiếp'))],
      ),
    );
  }
}
