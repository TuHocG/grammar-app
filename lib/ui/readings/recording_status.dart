/// Whether a reading's real-voice recording is on this device: a mark for the lists, and the
/// line of the reading page with a button to download it (or all of them, in Cài Đặt → Dữ liệu).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../platform/recordings.dart';

/// Cài Đặt, scrolled to Dữ liệu (where all the recordings are downloaded).
const dataSettingsRoute = '/settings?section=data';

/// The sound-wave mark of a reading with a recording; a cloud when it is not downloaded (it is
/// streamed, so it needs a network).
class RecordingMark extends ConsumerWidget {
  final String rel;
  final double size;
  final Color? color;
  const RecordingMark(this.rel, {super.key, this.size = 14, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(recordingsRevisionProvider);
    final here = localRecording(ref, rel) != null;
    return Tooltip(
      message: here ? 'Có giọng đọc thật' : 'Có giọng đọc thật, chưa tải về: cần mạng để nghe',
      child: Icon(here ? Icons.graphic_eq : Icons.cloud_outlined, size: size, color: color ?? context.g.fog),
    );
  }
}

/// "Bài này có giọng đọc thật", and whether it is downloaded; a download button when it is not.
/// [failed]: the player could not play it (offline stream) and reads with the synthetic voice.
class RecordingStatus extends ConsumerStatefulWidget {
  final String rel;
  final bool failed;

  /// The recording is now on this device.
  final VoidCallback? onDownloaded;
  const RecordingStatus({super.key, required this.rel, this.failed = false, this.onDownloaded});

  @override
  ConsumerState<RecordingStatus> createState() => _RecordingStatusState();
}

class _RecordingStatusState extends ConsumerState<RecordingStatus> {
  RecordingDownloader? _downloader;
  double? _progress;

  @override
  void dispose() {
    _downloader?.stop();
    _downloader?.close();
    super.dispose();
  }

  Future<void> _download() async {
    final d = _downloader = RecordingDownloader(ref.read(contentDbProvider), ref.read(userDbProvider));
    setState(() => _progress = 0);
    try {
      await d.fetchAll(
        [widget.rel],
        onProgress: (p) {
          if (mounted) setState(() => _progress = p.fraction);
        },
      );
      if (!mounted) return;
      ref.read(recordingsRevisionProvider.notifier).bump();
      widget.onDownloaded?.call();
    } on RecordingsStopped {
      // stopped by the user, or the page closed
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tải được: $e')));
    } finally {
      d.close();
      if (identical(_downloader, d)) _downloader = null;
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(recordingsRevisionProvider);
    final g = context.g;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(color: g.slate);
    final here = localRecording(ref, widget.rel) != null;
    final progress = _progress;
    final (icon, text) = widget.failed
        ? (Icons.cloud_off_outlined, 'Bài này có giọng đọc thật nhưng chưa tải về và không phát được qua mạng: đang đọc bằng giọng máy')
        : here
        ? (Icons.graphic_eq, 'Bài này có giọng đọc thật')
        : (Icons.cloud_outlined, 'Bài này có giọng đọc thật, chưa tải về: đang phát qua mạng');
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: g.slate),
            const SizedBox(width: 6),
            // Flexible: the note wraps on a phone instead of running off the toolbar.
            Flexible(child: Text(text, style: style)),
          ],
        ),
        if (progress != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, value: progress > 0 ? progress : null)),
          ),
          TextButton(onPressed: () => _downloader?.stop(), child: const Text('Dừng tải')),
        ] else if (!here) ...[
          TextButton.icon(onPressed: _download, icon: const Icon(Icons.download_outlined, size: 18), label: const Text('Tải bài này')),
          TextButton(onPressed: () => context.push(dataSettingsRoute), child: const Text('Tải tất cả…')),
        ],
      ],
    );
  }
}
