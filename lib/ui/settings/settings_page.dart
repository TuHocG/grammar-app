/// Cài Đặt: voice, speed 1–7, font size, theme (docs/08 G15, G18).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../data/backup.dart';
import '../../platform/tts.dart';
import '../widgets/shell.dart';
import 'content_sources.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  List<TtsVoice>? _voices;

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Save dialog of the platform, starting in Documents with a dated file name.
  Future<void> _export() async {
    final bytes = Uint8List.fromList(utf8.encode(exportBackup(ref.read(userDbProvider))));
    String? docs;
    try {
      docs = (await getApplicationDocumentsDirectory()).path;
    } catch (_) {}
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Xuất dữ liệu học tập',
        fileName: 'grammar-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json',
        bytes: bytes,
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        initialDirectory: docs,
      );
      if (uri == null) return;
      _snack('Đã ghi ${uri.scheme == 'file' ? uri.toFilePath() : uri}');
    } catch (e) {
      _snack('Không xuất được: $e');
    }
  }

  /// Open dialog of the platform (JSON files), confirm, then replace the user data.
  Future<void> _restore() async {
    try {
      final f = await FilePicker.pickFile(dialogTitle: 'Chọn file sao lưu', type: FileType.custom, allowedExtensions: const ['json']);
      if (f == null || !mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Khôi phục dữ liệu?'),
          content: Text('Dữ liệu học tập hiện tại sẽ được thay bằng nội dung của "${f.name}".'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Khôi phục')),
          ],
        ),
      );
      if (ok != true) return;
      final n = importBackup(ref.read(userDbProvider), utf8.decode(await f.readAsBytes()));
      ref.invalidate(userWordsProvider);
      ref.invalidate(settingsProvider);
      _snack('Đã khôi phục $n dòng');
    } catch (e) {
      _snack('Không khôi phục được: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    ref.read(ttsProvider).voices().then((v) {
      if (mounted) setState(() => _voices = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final tts = ref.read(ttsProvider);

    return Scaffold(
      appBar: GrammarAppBar(title: const Text('Cài Đặt')),
      body: RailListView(
        maxWidth: 880,
        children: [
          Text('Cài Đặt', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 16),
          Surface(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _Header('Giọng đọc'),
          ListTile(
            title: const Text('Giọng'),
            subtitle: Text(_voices?.where((v) => v.id == s.ttsVoice).firstOrNull?.toString() ?? (s.ttsVoice ?? 'Mặc định của hệ thống')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _voices == null
                ? null
                : () async {
                    final picked = await showDialog<String?>(
                      context: context,
                      builder: (c) => SimpleDialog(
                        title: const Text('Chọn giọng tiếng Anh'),
                        children: [
                          SimpleDialogOption(onPressed: () => Navigator.pop(c, ''), child: const Text('Mặc định của hệ thống')),
                          for (final v in _voices!) SimpleDialogOption(onPressed: () => Navigator.pop(c, v.id), child: Text(v.toString())),
                        ],
                      ),
                    );
                    if (picked != null) await n.setTtsVoice(picked.isEmpty ? null : picked);
                  },
          ),
          ListTile(
            title: Text('Tốc độ đọc: ${s.ttsSpeed} / 7'),
            subtitle: Slider(
              value: s.ttsSpeed.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              label: '${s.ttsSpeed}',
              onChanged: (v) => n.setTtsSpeed(v.round()),
            ),
            trailing: IconButton(tooltip: 'Nghe thử', icon: const Icon(Icons.volume_up), onPressed: () => tts.speak('This is my house. It is not big, and it is not small.')),
          ),
          const _Header('Hiển thị'),
          ListTile(
            title: Text('Cỡ chữ: ${(s.fontScale * 100).round()} %'),
            subtitle: Slider(value: s.fontScale, min: 0.8, max: 1.6, divisions: 8, onChanged: n.setFontScale),
          ),
          ListTile(
            title: const Text('Giao diện'),
            // Below the title, not `trailing`: three labelled segments don't fit beside it on a phone.
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('Hệ thống', maxLines: 1, softWrap: false)),
                    ButtonSegment(value: ThemeMode.light, label: Text('Sáng', maxLines: 1, softWrap: false)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Tối', maxLines: 1, softWrap: false)),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => n.setThemeMode(v.first),
                ),
              ),
            ),
          ),
          const _Header('Sao lưu'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Xuất dữ liệu học tập ra file'),
            subtitle: const Text('Từ đã lưu, đánh dấu, tiến độ, câu đã chọn, bài tự nhập, cài đặt → một file JSON; chọn nơi lưu'),
            onTap: _export,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Khôi phục từ file sao lưu'),
            subtitle: const Text('Chọn file JSON đã xuất; dữ liệu hiện tại sẽ bị thay thế'),
            onTap: _restore,
          ),
          const _Header('Dữ liệu'),
          const ContentSourcesSection(),
          const _Header('Giới thiệu'),
          const ListTile(
            title: Text('Grammar 4.0'),
            subtitle: Text('Kế thừa và tiếp tục phát triển Grammar 3.1 của TuHocTiengAnh.net theo uỷ thác của tác giả. Miễn phí; không được bán hay phân phối lại dữ liệu.'),
          ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
        child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.6)),
      );
}
