/// Cài Đặt: voice, speed 1–7, font size, theme (docs/08 G15, G18).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../platform/tts.dart';

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
      appBar: AppBar(title: const Text('Cài Đặt')),
      body: ListView(
        children: [
          const _Header('Giọng đọc'),
          ListTile(
            title: const Text('Giọng'),
            subtitle: Text(s.ttsVoice ?? 'Mặc định của hệ thống'),
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
                          for (final v in _voices!) SimpleDialogOption(onPressed: () => Navigator.pop(c, v.name), child: Text(v.toString())),
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
          const _Header('Dữ liệu'),
          ListTile(
            title: const Text('Thư mục dữ liệu'),
            subtitle: Text(ref.read(contentDbProvider).dataDir),
          ),
          ListTile(
            title: const Text('Nội dung'),
            subtitle: Text(
              'Từ điển ${counts['dict']?['entries']} mục · Bài đọc ${counts['readings']?['readings']} · Luyện nói ${counts['dialogs']?['dialogs']} · '
              'Văn phạm ${counts['grammar']?['lessons']} · Bài tập ${counts['exercises']?['exercises']} · Phụ đề ${counts['subtitles']?['films']} tập',
            ),
          ),
          const _Header('Giới thiệu'),
          const ListTile(
            title: Text('Grammar'),
            subtitle: Text('Nội dung: Grammar 3.1 của TuHocTiengAnh.net, dùng với sự cho phép của tác giả. Miễn phí; không được bán hay phân phối lại dữ liệu.'),
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
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
