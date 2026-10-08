/// Luyện Nghe → Video (docs/08 L3–L10): the user points the app at the folder with the
/// MP4 (or original AVI) files; episodes are listed by code with their first line; the
/// player shows the subtitle line for the current time (line i spans [e(i−1), e(i)]),
/// English and Vietnamese toggles, previous / repeat / next sentence, loop of n sentences,
/// and every subtitle word can be looked up or saved.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/providers.dart';
import '../../data/content_db_more.dart';
import '../../data/media_locations.dart';
import '../../data/models.dart';
import '../widgets/word_tap_text.dart';
import '../widgets/shell.dart';

class VideoListPage extends ConsumerStatefulWidget {
  const VideoListPage({super.key});
  @override
  ConsumerState<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends ConsumerState<VideoListPage> {
  String _group = 'A';

  @override
  Widget build(BuildContext context) {
    final db = ref.read(contentDbProvider);
    final films = db.films().where((f) => f.group == _group).toList();
    final dir = videoDir(ref.read(userDbProvider)) ?? '';
    final theme = Theme.of(context);
    return Scaffold(
      appBar: GrammarAppBar(
        title: const Text('Video'),
        actions: [IconButton(tooltip: 'Hướng dẫn', icon: const Icon(Icons.help_outline), onPressed: () => context.push('/help/video'))],
      ),
      body: Column(children: [
        if (dir.isEmpty || !Directory(dir).existsSync())
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Material(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
              child: ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: Text(dir.isEmpty ? 'Chưa chọn thư mục video' : 'Không tìm thấy thư mục video'),
                subtitle: const Text('Chọn thư mục chứa các file A 01.mp4 … trong Cài Đặt → Dữ liệu.'),
                trailing: TextButton(onPressed: () async { await context.push('/settings'); setState(() {}); }, child: const Text('Mở Cài Đặt')),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'A', label: Text('A · 57')),
              ButtonSegment(value: 'B', label: Text('B · 68')),
              ButtonSegment(value: 'C', label: Text('C · 80')),
              ButtonSegment(value: 'F', label: Text('Phim · 5')),
            ],
            selected: {_group},
            onSelectionChanged: (v) => setState(() => _group = v.first),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: films.length,
            itemBuilder: (context, i) {
              final f = films[i];
              final file = dir.isEmpty ? null : findVideoFile(dir, f);
              final mins = (f.duration / 60).round();
              return ListTile(
                leading: CircleAvatar(child: Text(f.code.split(' ').last)),
                title: Text(f.group == 'F' ? f.title : (f.firstLine ?? f.code), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${f.code} · $mins phút · ${f.lines} câu', style: theme.textTheme.bodySmall),
                trailing: file == null ? Icon(Icons.videocam_off_outlined, color: theme.colorScheme.outline) : const Icon(Icons.play_circle_outline),
                onTap: () => context.push('/video/${f.id}'),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class VideoPlayerPage extends ConsumerStatefulWidget {
  final int id;
  const VideoPlayerPage({super.key, required this.id});
  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  late final Player _player = Player();
  late final VideoController _ctl = VideoController(_player);
  SubtitleFilm? _film;
  List<SubtitleLine> _lines = const [];
  File? _file;
  int _idx = -1;
  bool _showEn = true;
  bool _showVi = true;
  int _loop = 0;          // number of sentences to loop (0 = off)
  int _loopStart = 0;
  StreamSubscription<Duration>? _posSub;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    final db = ref.read(contentDbProvider);
    _film = db.film(widget.id);
    if (_film != null) {
      _lines = db.subtitleLines(_film!.id);
      final dir = videoDir(ref.read(userDbProvider));
      _file = dir == null ? null : findVideoFile(dir, _film!);
      _loop = int.tryParse(ref.read(userDbProvider).setting('video_loop') ?? '') ?? 0;
      if (_file != null) {
        _player.open(Media(_file!.path));
        _posSub = _player.stream.position.listen(_onPosition);
        _player.stream.playing.listen((v) { if (mounted) setState(() => _playing = v); });
      }
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _onPosition(Duration d) {
    final t = d.inMilliseconds / 1000.0;
    var i = _idx;
    if (i < 0 || i >= _lines.length || t < _lines[i].s || t >= _lines[i].e) {
      i = _lines.indexWhere((l) => t >= l.s && t < l.e);
    }
    if (_loop > 0 && i >= 0 && i >= _loopStart + _loop) {
      _seekTo(_loopStart);
      return;
    }
    if (i != _idx && mounted) setState(() => _idx = i);
  }

  Future<void> _seekTo(int i) async {
    if (i < 0 || i >= _lines.length) return;
    _idx = i;
    await _player.seek(Duration(milliseconds: (_lines[i].s * 1000).round()));
    if (!_playing) await _player.play();
    if (mounted) setState(() {});
  }

  void _setLoop(int n) {
    _loop = n.clamp(0, 10);
    _loopStart = _idx < 0 ? 0 : _idx;
    ref.read(userDbProvider).setSetting('video_loop', '$_loop');
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seekTo(_idx);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      _seekTo(_idx - 1);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight || e.logicalKey == LogicalKeyboardKey.arrowDown) {
      _seekTo(_idx + 1);
    } else if (e.logicalKey == LogicalKeyboardKey.space) {
      _player.playOrPause();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final f = _film;
    final theme = Theme.of(context);
    if (f == null) return const Scaffold(body: Center(child: Text('Không có tập này.')));
    if (_file == null) {
      return Scaffold(
        appBar: GrammarAppBar(title: Text(f.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Không tìm thấy file "${f.mp4Name}" (hoặc "${f.video}") trong thư mục video. Chọn thư mục video trong Cài Đặt → Dữ liệu.', textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final line = _idx >= 0 && _idx < _lines.length ? _lines[_idx] : null;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: GrammarAppBar(
          title: Text('${f.code} · ${f.group == 'F' ? f.title : (f.firstLine ?? '')}', maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(tooltip: 'Phụ đề Anh (A)', icon: Icon(Icons.subtitles, color: _showEn ? theme.colorScheme.primary : null), onPressed: () => setState(() => _showEn = !_showEn)),
            IconButton(tooltip: 'Phụ đề Việt (V)', icon: Icon(Icons.translate, color: _showVi ? theme.colorScheme.primary : null), onPressed: () => setState(() => _showVi = !_showVi)),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: Video(controller: _ctl, controls: NoVideoControls),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            constraints: const BoxConstraints(minHeight: 92),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (line != null && _showEn) WordTapText(line.en, style: theme.textTheme.titleMedium, context: line.en, source: 'video:${f.code}'),
              if (line != null && _showVi && line.vi.isNotEmpty) Text(line.vi, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (line == null) Text('…', style: theme.textTheme.titleMedium),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Row(children: [
                Text('Câu ${_idx + 1}/${_lines.length}', style: theme.textTheme.bodySmall),
                const Spacer(),
                IconButton(tooltip: 'Câu trước (↑)', icon: const Icon(Icons.skip_previous), onPressed: () => _seekTo(_idx - 1)),
                IconButton(tooltip: 'Nghe lại câu (←)', icon: const Icon(Icons.replay), onPressed: () => _seekTo(_idx)),
                IconButton(iconSize: 40, icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle), onPressed: _player.playOrPause),
                IconButton(tooltip: 'Câu kế (→)', icon: const Icon(Icons.skip_next), onPressed: () => _seekTo(_idx + 1)),
                const Spacer(),
                Text('Số câu lặp', style: theme.textTheme.bodySmall),
                IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove), onPressed: _loop > 0 ? () => _setLoop(_loop - 1) : null),
                Text('$_loop', style: theme.textTheme.titleMedium),
                IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add), onPressed: _loop < 10 ? () => _setLoop(_loop + 1) : null),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
