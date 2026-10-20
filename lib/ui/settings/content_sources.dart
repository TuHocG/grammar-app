/// Cài Đặt → Dữ liệu: choose the lesson database (grammar.db), the real-voice recordings folder
/// and the video folder, each with a short summary of what was found.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../app/restart.dart';
import '../../data/content_db.dart';
import '../../data/content_db_io.dart';
import '../../data/image_pack.dart';
import '../../data/media_locations.dart';
import 'data_picker.dart';

class ContentSourcesSection extends ConsumerStatefulWidget {
  const ContentSourcesSection({super.key});
  @override
  ConsumerState<ContentSourcesSection> createState() => _ContentSourcesSectionState();
}

class _ContentSourcesSectionState extends ConsumerState<ContentSourcesSection> {
  DataSummary? _data;
  FolderSummary? _audio;
  FolderSummary? _video;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Summaries touch the disk (hundreds of files for the videos); compute after the next frame.
  /// That frame is asked for explicitly: after a native folder dialog closes nothing else asks
  /// for one on desktop, and the callback would wait until the mouse hovers something.
  void _refresh() {
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final db = ref.read(contentDbProvider);
      final user = ref.read(userDbProvider);
      setState(() {
        _data = dataSummary(db);
        _audio = audioSummary(db, audioDir(db, user));
        _video = db.hasVideo ? videoSummary(db, videoDir(db, user)) : null;
      });
    });
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Nearest existing folder at or above [dir]. The Windows picker throws (and opens nothing)
  /// when its initial folder is missing, e.g. the default audio/ next to grammar.db before the
  /// recordings are downloaded.
  static String? _existingDir(String? dir) {
    if (dir == null || dir.isEmpty) return null;
    var d = p.normalize(p.absolute(dir));
    while (!Directory(d).existsSync()) {
      final parent = p.dirname(d);
      if (parent == d) return null;
      d = parent;
    }
    return d;
  }

  // ---- lesson data ----------------------------------------------------------------------

  Future<void> _pickDatabase() async {
    final current = ref.read(contentDbProvider).dataDir;
    final String? dir;
    try {
      dir = await pickDataFolder(context, initialDirectory: isPickerCopy(current) ? null : _existingDir(current));
    } catch (e) {
      _snack('Không mở được hộp thoại chọn thư mục: $e');
      return;
    }
    if (dir == null || !mounted) return;
    final path = p.join(dir, 'grammar.db');
    if (!File(path).existsSync()) {
      _snack('Không thấy grammar.db trong thư mục $dir.');
      return;
    }
    String? version;
    int schema;
    Map<String, dynamic> counts;
    try {
      final probe = ContentDb.open(dir);
      version = probe.contentVersion;
      schema = probe.schemaVersion;
      counts = probe.counts;
      probe.close();
    } catch (e) {
      _snack('Không mở được file này: $e');
      return;
    }
    if (schema > ContentDb.supportedSchema) {
      _snack('File dùng lược đồ $schema, bản app này chỉ đọc được tới lược đồ ${ContentDb.supportedSchema}. Hãy cập nhật app.');
      return;
    }
    if (!mounted) return;
    final images = describeImages(dir);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Dùng nội dung ${version ?? '(chưa ghi phiên bản)'}?'),
        content: Text(
          '$path\n\n'
          'Bài đọc ${counts['reading']} · Luyện nói ${counts['dialog']} · Bài tập ${counts['exercise']}\n'
          '$images\n\n'
          'App sẽ mở lại trang chủ với dữ liệu này.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Dùng dữ liệu này')),
        ],
      ),
    );
    if (ok != true) return;
    ref.read(userDbProvider).setSetting('data_dir', dir);
    restartApp?.call();
  }

  // ---- folders --------------------------------------------------------------------------

  Future<void> _pickFolder(String key, String title, String? initial) async {
    final String? dir;
    try {
      dir = await pickFolder(context, title: title, initialDirectory: _existingDir(initial));
    } catch (e) {
      _snack('Không mở được hộp thoại chọn thư mục: $e');
      return;
    }
    if (dir == null || !mounted) return;
    ref.read(userDbProvider).setSetting(key, dir);
    _refresh();
  }

  void _clear(String key) {
    ref.read(userDbProvider).setSetting(key, '');
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final d = _data;
    final a = _audio;
    final v = _video;
    final user = ref.read(userDbProvider);
    final customAudio = (user.setting(audioDirKey) ?? '').isNotEmpty;
    final customVideo = (user.setting(videoDirKey) ?? '').isNotEmpty;

    // Name of a file of the data folder, heading the lines about it.
    Widget fileHeading(String name) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(name, style: theme.textTheme.labelLarge),
    );

    Widget card({required IconData icon, required String title, required List<Widget> lines, required List<Widget> actions}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 16),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                ...lines,
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: actions),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(
          icon: Icons.storage_outlined,
          title: d?.version == null ? 'Dữ liệu bài học' : 'Dữ liệu bài học · phiên bản ${d!.version}',
          lines: d == null
              ? [Text('Đang đọc…', style: muted)]
              : [
                  SelectableText(p.dirname(d.dbPath), style: muted),
                  if (isPickerCopy(d.dbPath))
                    Text('Đây là bản sao tạm của file nên app không thấy ảnh, âm thanh cạnh nó. Hãy chọn lại thư mục chứa grammar.db.', style: muted?.copyWith(color: theme.colorScheme.error)),
                  fileHeading('grammar.db'),
                  Text([if (d.date != null && d.date!.isNotEmpty) 'Phát hành ${d.date}', formatBytes(d.dbBytes), 'schema ${d.schema}'].join(' · '), style: muted),
                  Text(
                    [
                      'Từ điển ${d.counts['dict_entry']} mục',
                      'Bài đọc ${d.counts['reading']}',
                      'Luyện nói ${d.counts['dialog']}',
                      'Văn phạm ${d.counts['grammar_lesson']}',
                      'Bài tập ${d.counts['exercise']}',
                      if (d.counts['subtitle_film'] case final n?) 'Phụ đề $n tập',
                      'Từ vựng tranh ${d.counts['picture_topic']} bài',
                    ].join(' · '),
                    style: muted,
                  ),
                  fileHeading(imagePackName),
                  Text(
                    d.imagePackBroken
                        ? 'File bị hỏng (có thể tải chưa xong), hãy tải lại: bài đọc đang không có ảnh minh hoạ.'
                        : d.imagePack
                        ? '${d.images} ảnh minh hoạ · ${formatBytes(d.imagePackBytes)}'
                        : d.images > 0
                        ? 'Không có; đang đọc ${d.images} ảnh minh hoạ từ thư mục img/.'
                        : 'Không có: bài đọc sẽ không có ảnh minh hoạ.',
                    style: d.imagePackBroken ? muted?.copyWith(color: theme.colorScheme.error) : muted,
                  ),
                ],
          actions: [OutlinedButton.icon(onPressed: _pickDatabase, icon: const Icon(Icons.folder_open_outlined), label: const Text(pickDataLabel))],
        ),
        const Divider(indent: 16, endIndent: 16),
        card(
          icon: Icons.graphic_eq,
          title: 'Âm thanh thực (giọng đọc thật)',
          lines: a == null
              ? [Text('Đang đọc…', style: muted)]
              : [
                  SelectableText(a.dir + (customAudio ? '' : '  (mặc định: thư mục audio cạnh grammar.db)'), style: muted),
                  Text(
                    !a.exists
                        ? 'Chưa có thư mục này: các bài sẽ đọc bằng giọng máy.'
                        : '${a.found}/${a.expected} bài có file ghi âm · ${formatBytes(a.bytes)}'
                              '${a.found < a.expected ? ' · bài thiếu file đọc bằng giọng máy' : ''}',
                    style: muted,
                  ),
                ],
          actions: [
            OutlinedButton.icon(
              onPressed: () => _pickFolder(audioDirKey, 'Chọn thư mục âm thanh thực (1.mp3, 2.mp3 …)', a?.dir),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Chọn thư mục…'),
            ),
            if (customAudio) TextButton(onPressed: () => _clear(audioDirKey), child: const Text('Dùng mặc định')),
          ],
        ),
        if (ref.read(contentDbProvider).hasVideo) ...[
          const Divider(indent: 16, endIndent: 16),
          card(
            icon: Icons.movie_outlined,
            title: 'Video (Luyện Nghe)',
            lines: v == null
                ? [Text('Đang đọc…', style: muted)]
                : [
                    SelectableText(v.dir + (customVideo ? '' : '  (mặc định: thư mục video cạnh grammar.db)'), style: muted),
                    Text(
                      !v.exists ? 'Chưa có thư mục này: trang Video không phát được (cần A 01.mp4 … hoặc A  1.avi …).' : '${v.found}/${v.expected} tập có file · ${formatBytes(v.bytes)}',
                      style: muted,
                    ),
                  ],
            actions: [
              OutlinedButton.icon(onPressed: () => _pickFolder(videoDirKey, 'Chọn thư mục video', v?.dir), icon: const Icon(Icons.folder_open_outlined), label: const Text('Chọn thư mục…')),
              if (customVideo) TextButton(onPressed: () => _clear(videoDirKey), child: const Text('Dùng mặc định')),
            ],
          ),
        ],
      ],
    );
  }
}
