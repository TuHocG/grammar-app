/// Bài Nhập Của Bạn (docs/08 N1–N5): the user's own readings, grouped by package, with an
/// editor (title, English text, Vietnamese text, picture). A user reading opens in the normal reading page with every feature.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../data/reading_loader.dart';
import '../../data/user_readings.dart';
import '../widgets/shell.dart';

class UserReadingsPage extends ConsumerStatefulWidget {
  const UserReadingsPage({super.key});
  @override
  ConsumerState<UserReadingsPage> createState() => _UserReadingsPageState();
}

class _UserReadingsPageState extends ConsumerState<UserReadingsPage> {
  @override
  Widget build(BuildContext context) {
    final userDb = ref.read(userDbProvider);
    final all = userDb.userReadings();
    final packages = userDb.userReadingPackages();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: GrammarAppBar(
        title: const Text('Bài Nhập Của Bạn'),
        helpSlug: 'bai-nhap',
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Tạo bài đọc'),
        onPressed: () async { await context.push('/my-readings/new'); setState(() {}); },
      ),
      body: all.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Chưa có bài nào. Bấm "Tạo bài đọc" để soạn bài của bạn (tiếng Anh, tiếng Việt, ảnh).', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge)))
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final pkg in packages) ...[
                  Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4), child: Text(pkg, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary))),
                  for (final r in all.where((x) => x.package == pkg))
                    ListTile(
                      leading: _thumb(r),
                      title: Text(r.title),
                      subtitle: Text('${r.en.fold<int>(0, (a, p) => a + p.length)} câu', style: theme.textTheme.bodySmall),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            await context.push('/my-readings/${r.id}/edit');
                          } else if (v == 'delete') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text('Xoá "${r.title}"?'),
                                actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xoá'))],
                              ),
                            );
                            if (ok == true) userDb.deleteUserReading(r.id);
                          }
                          setState(() {});
                        },
                        itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Sửa bài')), PopupMenuItem(value: 'delete', child: Text('Xoá bài'))],
                      ),
                      onTap: () => context.push('/readings/${userReadingBase + r.id}'),
                    ),
                ],
              ],
            ),
    );
  }
}

/// The reading's header picture, or an icon when it has none (or the file is gone).
Widget _thumb(UserReading r) {
  const icon = IconTile(Icons.article_outlined, size: 56);
  final img = r.img;
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: 56,
      height: 56,
      child: img == null
          ? icon
          : Image(image: FileImage(File(img)), fit: BoxFit.cover, errorBuilder: (_, _, _) => icon),
    ),
  );
}

class UserReadingEditPage extends ConsumerStatefulWidget {
  final int? id;
  const UserReadingEditPage({super.key, this.id});
  @override
  ConsumerState<UserReadingEditPage> createState() => _UserReadingEditPageState();
}

class _UserReadingEditPageState extends ConsumerState<UserReadingEditPage> {
  static const _defaultPackage = 'Bài của tôi';
  final _pkg = TextEditingController(text: _defaultPackage);
  final _title = TextEditingController();
  final _en = TextEditingController();
  final _vi = TextEditingController();
  final _img = TextEditingController();
  UserReading? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _existing = ref.read(userDbProvider).userReading(widget.id!);
      final r = _existing;
      if (r != null) {
        _pkg.text = r.package;
        _title.text = r.title;
        _en.text = r.en.map((p) => p.join('_')).join('\n\n');
        _vi.text = r.vi.map((p) => p.join('_')).join('\n\n');
        _img.text = r.img ?? '';
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_pkg, _title, _en, _vi, _img]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final en = splitText(_en.text);
    final vi = splitText(_vi.text);
    if (_title.text.trim().isEmpty || en.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần tựa đề và nội dung tiếng Anh.')));
      return;
    }
    final db = ref.read(userDbProvider);
    final pkg = _pkg.text.trim().isEmpty ? _defaultPackage : _pkg.text.trim();
    final img = _img.text.trim().isEmpty ? null : _img.text.trim();
    if (_existing == null) {
      db.insertUserReading(package: pkg, title: _title.text.trim(), en: en, vi: vi, img: img);
    } else {
      db.updateUserReading(_existing!.id, package: pkg, title: _title.text.trim(), en: en, vi: vi, img: img);
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickImage() async {
    final current = _img.text.trim();
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Chọn ảnh đầu bài',
      type: FileType.image,
      initialDirectory: current.isEmpty ? null : File(current).parent.path,
    );
    final picked = files.isEmpty ? null : files.first.path;
    if (picked == null) return;
    final path = await _keepImage(picked);
    if (!mounted) return;
    setState(() => _img.text = path);
  }

  /// On Android and iOS the picker hands back a temporary copy (app cache / tmp) that the OS
  /// may clear, so keep our own copy under app support; desktop paths are the user's file.
  static Future<String> _keepImage(String picked) async {
    if (!Platform.isAndroid && !Platform.isIOS) return picked;
    final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'user_images'));
    await dir.create(recursive: true);
    final dest = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_${p.basename(picked)}');
    await File(picked).copy(dest);
    return dest;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final en = splitText(_en.text);
    final vi = splitText(_vi.text);
    final nEn = en.fold<int>(0, (a, p) => a + p.length);
    final nVi = vi.fold<int>(0, (a, p) => a + p.length);
    return Scaffold(
      appBar: GrammarAppBar(
        title: Text(_existing == null ? 'Tạo bài đọc' : 'Sửa bài đọc'),
        actions: [FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Lưu')), const SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            // Pick an existing group, or type a new name to create one.
            Expanded(
              child: DropdownMenu<String>(
                controller: _pkg,
                label: const Text('Gói (nhóm)'),
                expandedInsets: EdgeInsets.zero,
                requestFocusOnTap: true,
                dropdownMenuEntries: [
                  for (final g in {...ref.read(userDbProvider).userReadingPackages(), _defaultPackage}) DropdownMenuEntry(value: g, label: g),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: TextField(controller: _title, decoration: const InputDecoration(labelText: 'Tựa đề', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _en,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Tiếng Anh', helperText: 'Mỗi đoạn cách nhau một dòng trống; câu tự tách theo dấu chấm, hoặc dùng dấu _ để tách câu.', border: OutlineInputBorder(), alignLabelWithHint: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vi,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Tiếng Việt (mỗi câu tương ứng, cùng cách tách)', border: OutlineInputBorder(), alignLabelWithHint: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text('$nEn câu Anh · $nVi câu Việt${nEn != nVi && nVi > 0 ? ' (chưa khớp số câu)' : ''}', style: theme.textTheme.bodySmall?.copyWith(color: nEn != nVi && nVi > 0 ? theme.colorScheme.error : theme.colorScheme.outline)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: _img,
                decoration: InputDecoration(
                  labelText: 'Ảnh đầu bài (tuỳ chọn)',
                  border: const OutlineInputBorder(),
                  suffixIcon: _img.text.isEmpty
                      ? null
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          if (File(_img.text).existsSync()) const Icon(Icons.check, color: Colors.green),
                          IconButton(tooltip: 'Bỏ ảnh', icon: const Icon(Icons.clear), onPressed: () => setState(_img.clear)),
                        ]),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.folder_open), label: const Text('Chọn ảnh…')),
            ),
          ]),
        ],
      ),
    );
  }
}
