/// Bài Nhập Của Bạn (docs/08 N1–N5): the user's own readings, grouped by package, with an
/// editor (title, English text, Vietnamese text, picture, optional grammar-lesson list for
/// "Ngu Phap"). A user reading opens in the normal reading page with every feature.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/content_db.dart';
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
        actions: [IconButton(tooltip: 'Hướng dẫn', icon: const Icon(Icons.help_outline), onPressed: () => context.push('/help/bai-nhap'))],
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
                      leading: r.grammarRefs.isNotEmpty ? const Icon(Icons.account_tree) : const Icon(Icons.article_outlined),
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
                      onTap: () => r.grammarRefs.isNotEmpty ? context.push('/my-readings/${r.id}/grammar') : context.push('/readings/${userReadingBase + r.id}'),
                    ),
                ],
              ],
            ),
    );
  }
}

class UserReadingEditPage extends ConsumerStatefulWidget {
  final int? id;
  const UserReadingEditPage({super.key, this.id});
  @override
  ConsumerState<UserReadingEditPage> createState() => _UserReadingEditPageState();
}

class _UserReadingEditPageState extends ConsumerState<UserReadingEditPage> {
  final _pkg = TextEditingController(text: 'Bài của tôi');
  final _title = TextEditingController();
  final _en = TextEditingController();
  final _vi = TextEditingController();
  final _img = TextEditingController();
  final _refs = TextEditingController();
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
        _refs.text = r.grammarRefs.join(',');
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_pkg, _title, _en, _vi, _img, _refs]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final en = splitText(_en.text);
    final vi = splitText(_vi.text);
    final refs = _refs.text.split(RegExp(r'[,\s]+')).map(int.tryParse).whereType<int>().toList();
    if (_title.text.trim().isEmpty || (en.isEmpty && refs.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần tựa đề và nội dung tiếng Anh (hoặc danh sách bài văn phạm).')));
      return;
    }
    final db = ref.read(userDbProvider);
    final img = _img.text.trim().isEmpty ? null : _img.text.trim();
    if (_existing == null) {
      db.insertUserReading(package: _pkg.text.trim().isEmpty ? 'Bài của tôi' : _pkg.text.trim(), title: _title.text.trim(), en: en, vi: vi, img: img, grammarRefs: refs);
    } else {
      db.updateUserReading(_existing!.id, package: _pkg.text.trim(), title: _title.text.trim(), en: en, vi: vi, img: img, grammarRefs: refs);
    }
    Navigator.of(context).pop();
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
            Expanded(child: TextField(controller: _pkg, decoration: const InputDecoration(labelText: 'Gói (nhóm)', border: OutlineInputBorder()))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: TextField(controller: _title, decoration: const InputDecoration(labelText: 'Tựa đề', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _en,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Tiếng Anh', helperText: 'Mỗi đoạn cách nhau một dòng trống; câu tự tách theo dấu chấm, hoặc dùng _ để tách câu như app gốc.', border: OutlineInputBorder(), alignLabelWithHint: true),
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
          TextField(
            controller: _img,
            decoration: InputDecoration(
              labelText: 'Ảnh đầu bài (đường dẫn file)',
              border: const OutlineInputBorder(),
              suffixIcon: _img.text.isNotEmpty && File(_img.text).existsSync() ? const Icon(Icons.check, color: Colors.green) : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(controller: _refs, decoration: const InputDecoration(labelText: 'Bài "Ngu Phap": danh sách số bài văn phạm, ví dụ 1,5,12', border: OutlineInputBorder())),
        ],
      ),
    );
  }
}

/// A "Ngu Phap" user reading: a list of grammar lessons the user collected.
class UserGrammarListPage extends ConsumerWidget {
  final int id;
  const UserGrammarListPage({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.read(userDbProvider).userReading(id);
    final db = ref.read(contentDbProvider);
    if (r == null) return const Scaffold(body: Center(child: Text('Không có bài này.')));
    return Scaffold(
      appBar: GrammarAppBar(title: Text(r.title)),
      body: ListView(
        children: [
          for (final ref_ in r.grammarRefs)
            ListTile(
              leading: Text('$ref_'),
              title: Text(db.grammarLesson(ref_)?.title ?? 'Bài $ref_'),
              onTap: () => context.push('/grammar/$ref_'),
            ),
        ],
      ),
    );
  }
}
