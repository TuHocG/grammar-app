/// Cài Đặt → Dữ liệu: choose the lesson database (grammar.db), the real-voice recordings folder
/// and the video folder, each with a short summary of what was found.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/config.dart';
import '../../app/providers.dart';
import '../../app/restart.dart';
import '../../data/content_db.dart';
import '../../data/media_locations.dart';

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

  /// Summaries touch the disk (hundreds of files for the videos); compute after the first frame.
  void _refresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final db = ref.read(contentDbProvider);
      final user = ref.read(userDbProvider);
      final v = videoDir(user);
      setState(() {
        _data = dataSummary(db);
        _audio = audioSummary(db, audioDir(db, user));
        _video = v == null ? null : videoSummary(db, v);
      });
    });
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---- lesson data ----------------------------------------------------------------------

  Future<void> _pickDatabase() async {
    final current = ref.read(contentDbProvider).dataDir;
    final f = await FilePicker.pickFile(
      dialogTitle: 'Chọn file dữ liệu grammar.db',
      type: FileType.custom,
      allowedExtensions: const ['db'],
      initialDirectory: current,
    );
    final path = f?.path;
    if (path == null || !mounted) return;
    if (p.basename(path).toLowerCase() != 'grammar.db') {
      _snack('Hãy chọn file tên grammar.db.');
      return;
    }
    final dir = p.dirname(path);
    String? version;
    int schema;
    Map<String, dynamic> counts;
    try {
      final probe = ContentDb.open(dir, key: grammarDbKey);
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
    final hasImages = Directory(illustrationsDir(dir)).existsSync();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Dùng nội dung ${version ?? '(chưa ghi phiên bản)'}?'),
        content: Text(
          '$path\n\n'
          'Bài đọc ${counts['reading']} · Luyện nói ${counts['dialog']} · Bài tập ${counts['exercise']}\n'
          '${hasImages ? 'Có thư mục ảnh minh hoạ img/ cạnh file.' : 'Không thấy thư mục ảnh minh hoạ img/ cạnh file: bài đọc sẽ không có ảnh minh hoạ (ảnh Từ vựng tranh nằm sẵn trong file).'}\n\n'
          'App sẽ mở lại trang chủ với dữ liệu này.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Dùng file này')),
        ],
      ),
    );
    if (ok != true) return;
    ref.read(userDbProvider).setSetting('data_dir', dir);
    restartApp?.call();
  }

  // ---- folders --------------------------------------------------------------------------

  Future<void> _pickFolder(String key, String title, String? initial) async {
    final dir = await FilePicker.getDirectoryPath(dialogTitle: title, initialDirectory: initial);
    if (dir == null) return;
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

    Widget card({required IconData icon, required String title, required List<Widget> lines, required List<Widget> actions}) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 2, right: 16), child: Icon(icon, color: theme.colorScheme.primary)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                ...lines,
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: actions),
              ]),
            ),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      card(
        icon: Icons.storage_outlined,
        title: d?.version == null ? 'Dữ liệu bài học' : 'Dữ liệu bài học · phiên bản ${d!.version}',
        lines: d == null
            ? [Text('Đang đọc…', style: muted)]
            : [
                SelectableText(d.dbPath, style: muted),
                Text(
                  [
                    if (d.date != null && d.date!.isNotEmpty) 'Phát hành ${d.date}',
                    formatBytes(d.dbBytes),
                    'lược đồ ${d.schema}',
                    if (d.embedded > 0) '${d.embedded} ảnh tranh trong file',
                    '${d.images} ảnh minh hoạ',
                  ].join(' · '),
                  style: muted,
                ),
                Text(
                  'Từ điển ${d.counts['dict_entry']} mục · Bài đọc ${d.counts['reading']} · Luyện nói ${d.counts['dialog']} · '
                  'Văn phạm ${d.counts['grammar_lesson']} · Bài tập ${d.counts['exercise']} · Phụ đề ${d.counts['subtitle_film']} tập',
                  style: muted,
                ),
              ],
        actions: [OutlinedButton.icon(onPressed: _pickDatabase, icon: const Icon(Icons.file_open_outlined), label: const Text('Chọn file grammar.db…'))],
      ),
      const Divider(indent: 16, endIndent: 16),
      card(
        icon: Icons.graphic_eq,
        title: 'Âm thanh thực (giọng đọc thật)',
        lines: a == null
            ? [Text('Đang đọc…', style: muted)]
            : [
                SelectableText(a.dir + (customAudio ? '' : '  (mặc định: dataset/audio cạnh grammar.db)'), style: muted),
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
            onPressed: () => _pickFolder(audioDirKey, 'Chọn thư mục âm thanh thực (1.mp3, 2.wav …)', a?.dir),
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Chọn thư mục…'),
          ),
          if (customAudio) TextButton(onPressed: () => _clear(audioDirKey), child: const Text('Dùng mặc định')),
        ],
      ),
      const Divider(indent: 16, endIndent: 16),
      card(
        icon: Icons.movie_outlined,
        title: 'Video (Luyện Nghe)',
        lines: v == null
            ? [Text('Chưa chọn thư mục video (A 01.mp4 … hoặc A  1.avi …).', style: muted)]
            : [
                SelectableText(v.dir, style: muted),
                Text(
                  !v.exists ? 'Không tìm thấy thư mục này.' : '${v.found}/${v.expected} tập có file · ${formatBytes(v.bytes)}',
                  style: muted,
                ),
              ],
        actions: [
          OutlinedButton.icon(
            onPressed: () => _pickFolder(videoDirKey, 'Chọn thư mục video', v?.dir),
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Chọn thư mục…'),
          ),
          if (v != null) TextButton(onPressed: () => _clear(videoDirKey), child: const Text('Bỏ chọn')),
        ],
      ),
    ]);
  }
}
