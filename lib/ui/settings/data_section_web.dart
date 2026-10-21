/// Cài Đặt → Dữ liệu of the web app (docs/07 §12): what is in the browser, whether it is safe
/// from eviction, a check for new content, the pictures for offline use, and a way to start over.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/restart.dart';
import '../../data/bytes.dart';
import '../../data/download_progress.dart';
import '../../data/content_db.dart';
import '../../data/manifest.dart';
import '../../data/web_media.dart';
import '../../platform/recordings.dart';
import '../../platform/web_download.dart';
import '../../platform/web_store.dart';

class ContentSourcesSection extends ConsumerStatefulWidget {
  const ContentSourcesSection({super.key});
  @override
  ConsumerState<ContentSourcesSection> createState() => _ContentSourcesSectionState();
}

class _ContentSourcesSectionState extends ConsumerState<ContentSourcesSection> {
  final _host = HostLocation.ofApp();
  ({int usage, int quota})? _estimate;
  bool? _persisted;
  int? _imagesCached;
  DownloadProgress? _progress;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final e = await storageEstimate();
    final p = await storagePersisted();
    final n = (await cachedUrls(imagesCache)).length;
    if (!mounted) return;
    setState(() {
      _estimate = e;
      _persisted = p;
      _imagesCached = n;
    });
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _persist() async {
    final ok = await persistStorage();
    _snack(ok ? 'Trình duyệt sẽ giữ dữ liệu.' : 'Trình duyệt không hứa giữ: hãy thêm app vào màn hình chính, hoặc mở thường xuyên.');
    await _refresh();
  }

  /// Fetches latest.json; when the host has newer content, offers to download it. "Để sau"
  /// changes nothing: the installed version stays until the new packs are complete.
  Future<void> _checkUpdate() async {
    if (!onLine) {
      _snack('Không có mạng.');
      return;
    }
    final HostLatest latest;
    final HostManifest manifest;
    try {
      (latest, manifest) = await fetchLatest(_host);
    } on FormatException catch (e) {
      _snack('Máy chủ có dữ liệu bản app này chưa đọc được (${e.message}): tải lại trang để lấy bản app mới.');
      return;
    } catch (e) {
      _snack('Không đọc được máy chủ: $e');
      return;
    }
    final current = ref.read(contentDbProvider).contentVersion;
    if (latest.version == current) {
      _snack('Dữ liệu $current là bản mới nhất.');
      return;
    }
    if (manifest.schema > ContentDb.supportedSchema) {
      _snack('Bản ${latest.version} cần app mới hơn: tải lại trang.');
      return;
    }
    final missing = await missingPackBytes(manifest, _host);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Có dữ liệu ${latest.version}'),
        content: Text('Tải ${formatBytes(missing)}; app mở lại với dữ liệu mới. Tiến độ học và từ đã lưu giữ nguyên.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Để sau')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tải')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = 'Đang tải dữ liệu ${latest.version}…');
    try {
      await installContent(
        latest,
        manifest,
        _host,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      restartApp?.call();
    } catch (e) {
      _snack('$e');
      if (!mounted) return;
      setState(() {
        _busy = null;
        _progress = null;
      });
    }
  }

  Future<void> _prefetchAll() async {
    if (!onLine) {
      _snack('Không có mạng.');
      return;
    }
    setState(() => _busy = 'Đang tải ảnh…');
    try {
      final installed = await loadInstalled(_host);
      if (installed == null) throw StateError('chưa có dữ liệu');
      await prefetchImages(
        installed.$2,
        _host,
        installed.$2.images.keys,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      _snack(onLine ? 'Đã có đủ ảnh để dùng không cần mạng.' : 'Mất mạng giữa chừng; phần đã tải được giữ lại.');
    } catch (e) {
      _snack('Tải không xong: $e');
    }
    if (!mounted) return;
    setState(() {
      _busy = null;
      _progress = null;
    });
    await _refresh();
  }

  RecordingDownloader? _audioDownload;

  @override
  void dispose() {
    _audioDownload?.stop();
    super.dispose();
  }

  /// Downloads every recording not in the browser yet, for listening offline.
  Future<void> _downloadRecordings() async {
    if (!onLine) {
      _snack('Không có mạng.');
      return;
    }
    final db = ref.read(contentDbProvider);
    final d = _audioDownload = RecordingDownloader(db, ref.read(userDbProvider));
    setState(() => _busy = 'Đang tải giọng đọc thật…');
    try {
      await d.fetchAll(
        allRecordings(db),
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _busy = 'Đang tải giọng đọc thật: bài ${p.done < p.total ? p.done + 1 : p.total}/${p.total}…';
            _progress = DownloadProgress((p.fraction * 1000).round(), 1000);
          });
        },
      );
      _snack('Đã tải đủ giọng đọc thật: nghe được cả khi không có mạng.');
    } on RecordingsStopped {
      _snack('Đã dừng; bấm Tải giọng đọc thật để tải tiếp.');
    } catch (e) {
      _snack('Tải không xong: $e');
    }
    _audioDownload = null;
    if (!mounted) return;
    ref.read(recordingsRevisionProvider.notifier).bump();
    setState(() {
      _busy = null;
      _progress = null;
    });
    await _refresh();
  }

  Future<void> _removeRecordings() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xoá giọng đọc thật đã tải?'),
        content: const Text('Các bài sẽ phát giọng thật qua mạng như trước khi tải.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true) return;
    await deleteCache(audioCache);
    final media = ref.read(contentDbProvider).media;
    if (media is WebMediaStore) media.recordingsRemoved();
    if (!mounted) return;
    ref.read(recordingsRevisionProvider.notifier).bump();
    await _refresh();
  }

  Future<void> _wipe() async {
    if (!onLine) {
      _snack('Cần có mạng để tải lại sau khi xoá.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xoá dữ liệu bài học đã tải?'),
        content: const Text('Bài học và ảnh sẽ bị xoá khỏi trình duyệt và tải lại khi mở app. Tiến độ học, từ đã lưu giữ nguyên.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true) return;
    await deleteCache(packsCache);
    await deleteCache(imagesCache);
    await deleteCache(metaCache);
    reloadPage();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final db = ref.read(contentDbProvider);
    final counts = db.counts;
    final date = db.contentDate;
    final e = _estimate;
    final p = _progress;
    ref.watch(recordingsRevisionProvider);
    final recordings = allRecordings(db);
    final recordingsHere = recordings.where((r) => localRecording(ref, r) != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: Text('Bài học ${db.contentVersion ?? ''}${date != null && date.isNotEmpty ? ' · $date' : ''}'),
          subtitle: Text(
            [
              'Từ điển ${counts['dict_entry']} mục',
              'Bài đọc ${counts['reading']}',
              'Luyện nói ${counts['dialog']}',
              'Văn phạm ${counts['grammar_lesson']}',
              'Bài tập ${counts['exercise']}',
              'Từ vựng tranh ${counts['picture_topic']} bài',
            ].join(' · '),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.storage_outlined),
          title: Text(e == null ? 'Dung lượng trong trình duyệt' : 'Đang dùng ${formatBytes(e.usage)} trong ${formatBytes(e.quota)} trình duyệt cho phép'),
          subtitle: Text(
            [
              if (_imagesCached != null) '$_imagesCached ảnh đã có sẵn',
              _persisted == true ? 'Trình duyệt giữ dữ liệu lâu dài.' : 'Trình duyệt có thể xoá khi thiếu chỗ hoặc lâu không mở.',
            ].join(' · '),
            style: muted,
          ),
          trailing: _persisted == true ? null : TextButton(onPressed: _persist, child: const Text('Giữ lâu dài')),
        ),
        ListTile(
          leading: const Icon(Icons.graphic_eq),
          title: Text('Giọng đọc thật: đã tải $recordingsHere/${recordings.length} bài'),
          subtitle: Text(recordingsHere < recordings.length ? 'Bài chưa tải phát qua mạng; tải về để nghe khi không có mạng.' : 'Nghe được cả khi không có mạng.', style: muted),
        ),
        if (_busy != null)
          ListTile(
            title: Text(_busy!),
            subtitle: p == null ? null : LinearProgressIndicator(value: p.fraction),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(onPressed: _busy == null ? _checkUpdate : null, icon: const Icon(Icons.update), label: const Text('Kiểm tra cập nhật')),
              OutlinedButton.icon(onPressed: _busy == null ? _prefetchAll : null, icon: const Icon(Icons.image_outlined), label: const Text('Tải trước toàn bộ ảnh')),
              if (_audioDownload != null)
                OutlinedButton.icon(onPressed: () => _audioDownload?.stop(), icon: const Icon(Icons.stop_outlined), label: const Text('Dừng tải'))
              else if (recordingsHere < recordings.length)
                OutlinedButton.icon(onPressed: _busy == null ? _downloadRecordings : null, icon: const Icon(Icons.download_outlined), label: const Text('Tải giọng đọc thật')),
              if (recordingsHere > 0) TextButton(onPressed: _busy == null ? _removeRecordings : null, child: const Text('Xoá giọng đọc đã tải')),
              TextButton(onPressed: _busy == null ? _wipe : null, child: const Text('Xoá dữ liệu đã tải')),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.computer_outlined),
          title: const Text('Bản đầy đủ cho Windows, Android, macOS'),
          subtitle: const Text('Có video; chạy không cần trình duyệt'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => launchUrl(Uri.parse('https://tuhocg.github.io/'), mode: LaunchMode.externalApplication),
        ),
      ],
    );
  }
}
