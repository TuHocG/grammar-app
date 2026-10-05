/// Cài Đặt: voice, speed 1–7, font size, theme (docs/08 G15, G18).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../data/backup.dart';
import '../../platform/tts.dart';
import '../widgets/shell.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  List<TtsVoice>? _voices;

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
    final counts = ref.read(contentDbProvider).counts;

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
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Hệ thống')),
                ButtonSegment(value: ThemeMode.light, label: Text('Sáng')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Tối')),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => n.setThemeMode(v.first),
            ),
          ),
          const _Header('Sao lưu'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Xuất dữ liệu học tập ra file'),
            subtitle: const Text('Từ đã lưu, đánh dấu, tiến độ, câu đã chọn, bài tự nhập, cài đặt → một file JSON trong thư mục Documents'),
            onTap: () async {
              final dir = await getApplicationDocumentsDirectory();
              final file = File(p.join(dir.path, 'grammar-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json'));
              await file.writeAsString(exportBackup(ref.read(userDbProvider)));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã ghi ${file.path}')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Khôi phục từ file sao lưu'),
            subtitle: const Text('Nhập đường dẫn file JSON; dữ liệu hiện tại sẽ bị thay thế'),
            onTap: () async {
              final ctl = TextEditingController();
              final path = await showDialog<String>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('File sao lưu'),
                  content: TextField(controller: ctl, decoration: const InputDecoration(hintText: 'C:\\...\\grammar-backup-....json')),
                  actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Huỷ')), FilledButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('Khôi phục'))],
                ),
              );
              if (path == null || path.isEmpty) return;
              try {
                final n = importBackup(ref.read(userDbProvider), await File(path).readAsString());
                ref.invalidate(userWordsProvider);
                ref.invalidate(settingsProvider);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã khôi phục $n dòng')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không khôi phục được: $e')));
              }
            },
          ),
          const _Header('Dữ liệu'),
          ListTile(
            title: const Text('Thư mục dữ liệu'),
            subtitle: Text(ref.read(contentDbProvider).dataDir),
          ),
          ListTile(
            title: const Text('Nội dung'),
            subtitle: Text(
              'Từ điển ${counts['dict_entry']} mục · Bài đọc ${counts['reading']} · Luyện nói ${counts['dialog']} · '
              'Văn phạm ${counts['grammar_lesson']} · Bài tập ${counts['exercise']} · Phụ đề ${counts['subtitle_film']} tập',
            ),
          ),
          const _Header('Giới thiệu'),
          const ListTile(
            title: Text('Grammar'),
            subtitle: Text('Nội dung: Grammar 3.1 của TuHocTiengAnh.net, dùng với sự cho phép của tác giả. Miễn phí; không được bán hay phân phối lại dữ liệu.'),
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
