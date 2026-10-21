/// First visit of the web app (docs/07 §12): the lessons are downloaded once into the browser.
/// On iPhone and iPad the app should first be put on the home screen, since Safari keeps a
/// separate (and evictable) storage for pages opened in a tab; the web view inside another app
/// (Zalo, Facebook…) cannot do that at all.
library;

import 'package:flutter/material.dart';

import '../../data/bytes.dart';
import '../../data/download_progress.dart';
import '../../data/manifest.dart';
import '../../platform/web_download.dart';
import '../../platform/web_store.dart';

class WebSetupPage extends StatefulWidget {
  final HostLatest latest;
  final HostManifest manifest;
  final HostLocation host;
  final Future<void> Function() onDone;
  const WebSetupPage({super.key, required this.latest, required this.manifest, required this.host, required this.onDone});

  @override
  State<WebSetupPage> createState() => _WebSetupPageState();
}

class _WebSetupPageState extends State<WebSetupPage> {
  DownloadProgress? _progress;
  String? _error;
  bool _running = false;
  int? _missing;

  @override
  void initState() {
    super.initState();
    missingPackBytes(widget.manifest, widget.host).then((n) {
      if (mounted) setState(() => _missing = n);
    });
  }

  Future<void> _download() async {
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await installContent(
        widget.latest,
        widget.manifest,
        widget.host,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await widget.onDone();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.manifest;
    final total = m.db.packs.fold(0, (a, p) => a + p.size);
    final p = _progress;
    final resumable = _missing != null && _missing! < total;
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
                Text('Grammar 4.0', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Bài học (phiên bản ${m.contentVersion}) được tải một lần vào trình duyệt, ${formatBytes(total)}; sau đó app chạy không cần mạng. '
                  'Ảnh minh hoạ tải dần khi mở bài.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (isIosDevice && !isStandalone) ...[const SizedBox(height: 16), _IosHint(safari: isIosSafari)],
                const SizedBox(height: 16),
                if (p != null) ...[
                  LinearProgressIndicator(value: p.fraction),
                  const SizedBox(height: 8),
                  Text('${formatBytes(p.done)} / ${formatBytes(p.total)}', style: theme.textTheme.bodySmall),
                ] else if (resumable)
                  Text('Đã có ${formatBytes(total - _missing!)}, còn ${formatBytes(_missing!)}.', style: theme.textTheme.bodySmall),
                if (_error != null) ...[const SizedBox(height: 8), SelectableText(_error!, style: TextStyle(color: theme.colorScheme.error))],
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: _running ? null : _download, icon: const Icon(Icons.download), label: Text(_running ? 'Đang tải…' : (resumable ? 'Tải tiếp' : 'Tải dữ liệu'))),
                const SizedBox(height: 24),
                Text('Bản cài đặt cho Windows, Android, macOS có thêm video: tuhocg.github.io', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IosHint extends StatelessWidget {
  final bool safari;
  const _IosHint({required this.safari});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(safari ? 'Trên iPhone/iPad: thêm vào Màn hình chính trước' : 'Trên iPhone/iPad: mở bằng Safari', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              safari
                  ? 'Bấm nút Chia sẻ của Safari → "Thêm vào MH chính", rồi mở Grammar từ biểu tượng đó và tải dữ liệu ở đấy. '
                        'Bài học và tiến độ học trong tab Safari không dùng được cho biểu tượng trên màn hình chính, và Safari có thể xoá sau một tuần không mở. '
                        'Thỉnh thoảng hãy xuất file sao lưu trong Cài Đặt.'
                  : 'Trình duyệt này (trong ứng dụng khác) không giữ được dữ liệu lâu và không thêm được vào Màn hình chính. '
                        'Hãy chép địa chỉ trang, mở bằng Safari, rồi thêm vào MH chính.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
