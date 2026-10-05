/// Từ Vựng (Tranh) (docs/08 H1–H5): 155 picture pages with numbered hotspots; tap a hotspot
/// to see "english = nghĩa" and hear it; three modes: 0 pick spots (saved), 1 "look at the
/// highlighted spot, type the English", 2 "listen, tap the right spot".
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db_more.dart';
import '../../data/models.dart';
import '../../data/user_db_more.dart';
import '../dictionary/quick_def_sheet.dart';
import '../widgets/shell.dart';

/// Pic5 pages are 700 px high with varying width (595–1319); hotspot pixels refer to the
/// native image size, so the page's real size is read from the decoded image.
const pageH = 700.0;
/// Half of the old app's circle (255 twips = 17 px): offset from `xy` to the dot centre.
const spotCentre = 8.5;

class PictureTopicsPage extends ConsumerWidget {
  const PictureTopicsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(contentDbProvider);
    final topics = db.pictureTopics();
    final withPicks = ref.read(userDbProvider).pictureTopicsWithPicks();
    final last = int.tryParse(ref.read(userDbProvider).progress('pictures', 'last') ?? '');
    return Scaffold(
      appBar: GrammarAppBar(
        title: const Text('Từ Vựng (Tranh)'),
        actions: [IconButton(tooltip: 'Hướng dẫn', icon: const Icon(Icons.help_outline), onPressed: () => context.push('/help/22'))],
      ),
      body: ListView.builder(
        itemCount: topics.length,
        itemBuilder: (context, i) {
          final t = topics[i];
          return ListTile(
            leading: SizedBox(
              width: 56,
              height: 48,
              child: t.page == null
                  ? const Icon(Icons.image_outlined)
                  : ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(db.mediaFile(t.page!), fit: BoxFit.cover, cacheWidth: 112, errorBuilder: (_, _, _) => const Icon(Icons.image_outlined))),
            ),
            title: Text(t.title, style: TextStyle(fontWeight: t.id == last ? FontWeight.w600 : null)),
            subtitle: Text('${t.words.length} từ'),
            trailing: withPicks.contains(t.id) ? Icon(Icons.book, color: Marks.savedWord, size: 18) : null,
            onTap: () => context.push('/pictures/${t.id}'),
          );
        },
      ),
    );
  }
}

class PictureTopicPage extends ConsumerStatefulWidget {
  final int id;
  const PictureTopicPage({super.key, required this.id});
  @override
  ConsumerState<PictureTopicPage> createState() => _PictureTopicPageState();
}

class _PictureTopicPageState extends ConsumerState<PictureTopicPage> {
  PictureTopic? _topic;
  late Set<int> _picks;
  int _mode = 0;
  int? _current;      // highlighted word index
  int? _target;       // practice target
  final _answer = TextEditingController();
  String? _feedback;
  int _right = 0, _wrong = 0;
  final _rnd = Random();
  Size? _imgSize;

  @override
  void initState() {
    super.initState();
    _topic = ref.read(contentDbProvider).pictureTopic(widget.id);
    _picks = ref.read(userDbProvider).picturePicks(widget.id);
    ref.read(userDbProvider).setProgress('pictures', 'last', '${widget.id}');
    final page = _topic?.page;
    if (page != null) {
      final provider = FileImage(ref.read(contentDbProvider).mediaFile(page));
      provider.resolve(const ImageConfiguration()).addListener(ImageStreamListener((info, _) {
        if (mounted) setState(() => _imgSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
      }));
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  List<int> get _pool {
    final spots = [for (var i = 0; i < _topic!.words.length; i++) if (_topic!.words[i].hasSpot) i];
    final picked = spots.where(_picks.contains).toList();
    return picked.isEmpty ? spots : picked;
  }

  void _setMode(int m) {
    setState(() {
      _mode = m;
      _feedback = null;
      _answer.clear();
      _right = 0;
      _wrong = 0;
      _target = null;
      _current = null;
    });
    if (m > 0) _nextTarget();
  }

  void _nextTarget() {
    final pool = _pool;
    if (pool.isEmpty) return;
    var t = pool[_rnd.nextInt(pool.length)];
    if (pool.length > 1 && t == _target) t = pool[(pool.indexOf(t) + 1) % pool.length];
    setState(() {
      _target = t;
      _current = _mode == 1 ? t : null;
      _feedback = null;
      _answer.clear();
    });
    if (_mode == 2) ref.read(ttsProvider).speak(_topic!.words[t].en);
  }

  void _tapSpot(int i) {
    final w = _topic!.words[i];
    if (_mode == 0) {
      setState(() => _current = i);
      ref.read(ttsProvider).speak(w.en);
    } else if (_mode == 2 && _target != null) {
      final ok = i == _target;
      setState(() {
        _current = i;
        _feedback = ok ? 'Đúng: ${w.en} = ${w.vi}' : 'Chưa đúng. Đó là "${w.en}".';
        ok ? _right++ : _wrong++;
      });
      ref.read(ttsProvider).speak(w.en);
      if (ok) Future.delayed(const Duration(milliseconds: 900), () { if (mounted && _mode == 2) _nextTarget(); });
    } else if (_mode == 1) {
      setState(() => _current = i);
    }
  }

  void _togglePick() {
    if (_current == null) return;
    final picked = _picks.contains(_current);
    ref.read(userDbProvider).setPicturePick(widget.id, _current!, !picked);
    setState(() => picked ? _picks.remove(_current) : _picks.add(_current!));
  }

  void _checkTyped() {
    if (_target == null) return;
    final w = _topic!.words[_target!];
    final ok = _answer.text.trim().toLowerCase() == w.en.trim().toLowerCase();
    setState(() {
      _feedback = ok ? 'Đúng: ${w.en} = ${w.vi}' : 'Đáp án: ${w.en} = ${w.vi}';
      ok ? _right++ : _wrong++;
    });
    ref.read(ttsProvider).speak(w.en);
  }

  @override
  Widget build(BuildContext context) {
    final t = _topic;
    if (t == null) return const Scaffold(body: Center(child: Text('Không có chủ đề này.')));
    final db = ref.read(contentDbProvider);
    final theme = Theme.of(context);
    final topics = db.pictureTopics();
    final i = topics.indexWhere((x) => x.id == t.id);
    final prev = i > 0 ? topics[i - 1].id : null;
    final next = i < topics.length - 1 ? topics[i + 1].id : null;
    final cur = _current == null ? null : t.words[_current!];

    return Scaffold(
      appBar: GrammarAppBar(
        title: Text(t.title),
        actions: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('Xem')),
              ButtonSegment(value: 1, label: Text('Luyện 1')),
              ButtonSegment(value: 2, label: Text('Luyện 2')),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => _setMode(v.first),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: t.page == null
              ? const Center(child: Text('Chủ đề này không có trang ảnh.'))
              : LayoutBuilder(
                  builder: (context, c) {
                    final iw = _imgSize?.width ?? 798.0, ih = _imgSize?.height ?? pageH;
                    final scale = min(c.maxWidth / iw, c.maxHeight / ih);
                    final w = iw * scale, h = ih * scale;
                    return Center(
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: InteractiveViewer(
                          maxScale: 4,
                          child: Stack(children: [
                            Image.file(db.mediaFile(t.page!), width: w, height: h, fit: BoxFit.fill),
                            for (var k = 0; k < t.words.length; k++)
                              if (t.words[k].hasSpot)
                                // `xy` is the top-left of the old app's 17 px circle
                                // (Shape D, 255 twips; Hinh.bas:ShowAllDiemChon), so the
                                // white dot printed on the page is centred at xy + 8.5.
                                Positioned(
                                  left: (t.words[k].x! + spotCentre) * scale - 11,
                                  top: (t.words[k].y! + spotCentre) * scale - 11,
                                  child: _Spot(
                                    number: k + 1,
                                    picked: _picks.contains(k),
                                    highlighted: _current == k || (_mode == 1 && _target == k),
                                    hidden: _mode == 2 && _feedback == null ? false : false,
                                    onTap: () => _tapSpot(k),
                                  ),
                                ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_mode == 0)
              Row(children: [
                Expanded(
                  child: cur == null
                      ? Text('Chạm vào một số trên tranh.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))
                      : Text.rich(TextSpan(children: [
                          TextSpan(text: cur.en, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: _picks.contains(_current) ? Marks.savedWord : null)),
                          TextSpan(text: '  =  ${cur.vi}', style: theme.textTheme.titleMedium),
                        ])),
                ),
                if (cur != null) IconButton(tooltip: 'Đọc', icon: const Icon(Icons.volume_up), onPressed: () => ref.read(ttsProvider).speak(cur.en)),
                if (cur != null) IconButton(tooltip: 'Tra từ điển', icon: const Icon(Icons.search), onPressed: () => showQuickDef(context, ref, cur.en, source: 'picture:${t.id}')),
                if (cur != null)
                  IconButton(
                    tooltip: _picks.contains(_current) ? 'Bỏ chọn tiêu điểm' : 'Chọn tiêu điểm để luyện',
                    icon: Icon(_picks.contains(_current) ? Icons.bookmark : Icons.bookmark_border, color: _picks.contains(_current) ? Marks.savedWord : null),
                    onPressed: _togglePick,
                  ),
              ]),
            if (_mode == 1) ...[
              Text('Nhìn tiêu điểm sáng, gõ từ tiếng Anh:', style: theme.textTheme.bodyMedium),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _answer,
                    autofocus: true,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    onSubmitted: (_) => _feedback == null ? _checkTyped() : _nextTarget(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _feedback == null ? _checkTyped : _nextTarget, child: Text(_feedback == null ? 'Kiểm tra' : 'Tiếp')),
              ]),
            ],
            if (_mode == 2)
              Row(children: [
                FilledButton.tonalIcon(onPressed: _target == null ? null : () => ref.read(ttsProvider).speak(t.words[_target!].en), icon: const Icon(Icons.volume_up), label: const Text('Nghe lại')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _target == null ? null : () => setState(() { _current = _target; _feedback = '${t.words[_target!].en} = ${t.words[_target!].vi}'; }), child: const Text('Đáp án')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _nextTarget, child: const Text('Tiếp')),
              ]),
            if (_feedback != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_feedback!, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary))),
            if (_mode > 0) Text('Đúng $_right · sai $_wrong · ${_picks.isEmpty ? 'tất cả' : '${_pool.length} tiêu điểm đã chọn'}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ]),
        ),
        SafeArea(
          top: false,
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: prev == null ? null : () => context.pushReplacement('/pictures/$prev')),
            const Spacer(),
            Text('${i + 1} / ${topics.length}', style: theme.textTheme.bodySmall),
            const Spacer(),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: next == null ? null : () => context.pushReplacement('/pictures/$next')),
          ]),
        ),
      ]),
    );
  }
}

class _Spot extends StatelessWidget {
  final int number;
  final bool picked;
  final bool highlighted;
  final bool hidden;
  final VoidCallback onTap;
  const _Spot({required this.number, required this.picked, required this.highlighted, required this.hidden, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlighted ? theme.colorScheme.primary : (picked ? Marks.savedWord : Colors.black87);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: highlighted ? color : Colors.white.withValues(alpha: 0.85),
          border: Border.all(color: color, width: 2),
        ),
        child: Text('$number', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: highlighted ? Colors.white : color)),
      ),
    );
  }
}
