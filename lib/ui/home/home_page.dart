/// Main menu (docs/08 G1): everything the old two-column menu offered, laid out as
/// "continue where you were" cards, four feature cards, the study grid and the nine test sets.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/config.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/content_db_more.dart';
import '../../data/reading_loader.dart';
import '../analysis/analysis_page.dart' show analysisReadingIds;
import '../exercises/exercise_pages.dart' show groupSize;
import '../widgets/shell.dart';

class _Item {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  const _Item(this.title, this.subtitle, this.icon, this.route);
}

const _learn = [
  _Item('Phân Tích Câu', 'Từ loại, chức năng, vì sao phải có từ này', Icons.manage_search, '/analysis'),
  _Item('Từ Vựng (Tranh)', 'Xem, Luyện 1, Luyện 2 theo trang tranh', Icons.image_outlined, '/pictures'),
  _Item('Video', 'Phụ đề Anh–Việt, lặp câu, tra từ', Icons.movie_outlined, '/video'),
  _Item('Phiên Âm Quốc Tế', 'Ký hiệu IPA và cách đọc tiếng Việt', Icons.spellcheck, '/ipa'),
  _Item('Từ điển', 'Gõ để tìm · phiên âm · họ từ', Icons.search, '/dict'),
];

// Cài Đặt and Hướng Dẫn are in the top bar, so they are not repeated here.
const _personal = [
  _Item('Từ Vựng Của Bạn', 'Từ bạn lưu khi đọc, tô đỏ trong mọi bài', Icons.bookmark_outline, '/words'),
  _Item('Quay Từ', 'Thẻ ghi nhớ từ các từ đã lưu', Icons.style_outlined, '/spin'),
  _Item('Bài Nhập Của Bạn', 'Tự nhập bài, dùng đủ tính năng đọc', Icons.edit_note_outlined, '/my-readings'),
];

const _menuHints = {
  'ARTICLES': 'điền dạng đúng',
  'CONDITIONAL': 'điền dạng đúng',
  'TENSE': 'hội thoại nhiều chỗ trống',
  'PREPOSITION / IDIOMS': 'điền giới từ hoặc để trống',
  'PRELIMINARY TEST A': 'trắc nghiệm a–d',
  'PRELIMINARY TEST B': 'trắc nghiệm a–d',
  'TOEFL TEST': 'giải thích từng phương án',
  'B+C VOCABULARY': 'gợi ý nghĩa từng phương án',
  'WORD FORMS': 'điền dạng đúng của từ gốc',
};

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final g = context.g;
    final db = ref.read(contentDbProvider);
    final userDb = ref.read(userDbProvider);
    ref.watch(progressRevisionProvider);
    final s = ref.watch(settingsProvider);
    final nWords = ref.watch(userWordsProvider).words.length;
    final counts = db.counts;
    final menus = db.exerciseMenus();
    final exerciseProgress = userDb.progressOf('exercise', prefix: 'menu');

    // "Continue" cards.
    final activity = _latestActivity(ref, context.isWide);
    final lastEx = userDb.latestProgress('exercise', prefix: 'menu');
    _ExerciseResume? resume;
    if (lastEx != null) {
      final m = RegExp(r'^menu(\d+)-g(\d+)$').firstMatch(lastEx.$1);
      final st = RegExp(r'"pos":(\d+),"score":(\d+),"done":(\d+)').firstMatch(lastEx.$2);
      if (m != null && st != null) {
        final menu = menus.where((x) => x.idx == int.parse(m.group(1)!)).firstOrNull;
        final group = int.parse(m.group(2)!);
        final done = int.parse(st.group(3)!);
        // A group whose every question is answered is finished, not "dở dang".
        if (menu != null && done < min(groupSize, menu.count - group * groupSize)) {
          resume = _ExerciseResume(menu.name, group, int.parse(st.group(1)!), int.parse(st.group(2)!), done, (menu.count / groupSize).ceil());
        }
      }
    }

    return Scaffold(
      appBar: GrammarAppBar(
        title: Row(children: [
          Flexible(child: Text('Grammar 4.0', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
          if (context.isWide) ...[
            const SizedBox(width: 32),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SearchPill(hint: 'Tra từ nhanh… (gõ ở bất kỳ đâu để tìm)', readOnly: true, onTap: () => context.push('/dict')),
              ),
            ),
          ],
        ]),
        // Wide: the search pill above replaces the 🔍 button, and help is spelled out.
        search: !context.isWide,
        onHelp: context.isWide ? null : () => context.push('/help'),
        actions: [
          if (context.isWide) TextButton(onPressed: () => context.push('/help'), child: const Text('Hướng dẫn cách học')),
          if (context.isWide) const SizedBox(width: 4),
          RoundIconButton(icon: Icons.settings_outlined, tooltip: 'Cài đặt', onPressed: () => context.push('/settings')),
        ],
      ),
      body: RailListView(
        children: [
          // ---- greeting + continue -------------------------------------------------
          Wrap(crossAxisAlignment: WrapCrossAlignment.end, alignment: WrapAlignment.spaceBetween, runSpacing: 8, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hôm nay học gì?', style: theme.textTheme.headlineLarge),
              Text('Tiếp tục nơi bạn dừng lại, hoặc chọn một mục bên dưới.', style: theme.textTheme.bodyLarge?.copyWith(color: g.slate)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.volume_up_outlined, size: 18, color: g.slate),
              const SizedBox(width: 6),
              Flexible(child: Text('Giọng ${s.ttsVoice == null ? 'hệ thống' : 'riêng'} · Tốc độ ${s.ttsSpeed}', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate))),
            ]),
          ]),
          if (activity != null || resume != null) ...[
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, c) {
              final stacked = c.maxWidth < 760;
              final cards = <Widget>[
                if (activity != null)
                  Surface(
                    onTap: () => context.push(activity.route),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(children: [
                      _Thumb(image: activity.image, icon: activity.icon),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Đang học · ${activity.label}', style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(activity.title, style: ReadingStyles.line(context).copyWith(fontSize: 20, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (activity.detail.isNotEmpty) Text(activity.detail, style: theme.textTheme.bodyMedium?.copyWith(color: g.slate), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(onPressed: () => context.push(activity.route), child: const Text('Tiếp tục')),
                    ]),
                  ),
                if (resume != null)
                  Surface(
                    onTap: () => context.push('/exercises/menu/${menus.firstWhere((m) => m.name == resume!.menuName).idx}/${resume!.group}'),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Bài tập đang luyện', style: theme.textTheme.bodySmall),
                      Text('${resume.menuName} · Bài Tập ${resume.group + 1}', style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('Câu ${resume.pos + 1}/$groupSize · đúng ${resume.score}', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)),
                      const SizedBox(height: 8),
                      ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: resume.done / groupSize, minHeight: 4)),
                    ]),
                  ),
              ];
              if (stacked) return Column(children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)]);
              return IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (activity != null) Expanded(flex: 2, child: cards.first),
                  if (activity != null && resume != null) const SizedBox(width: 16),
                  if (resume != null) Expanded(child: cards.last),
                ]),
              );
            }),
          ],
          const SizedBox(height: 32),

          // ---- four feature cards ---------------------------------------------------
          AutoGrid(
            minWidth: 230,
            rowHeight: 264,
            children: [
              FeatureCard(
                title: 'Bài Đọc',
                icon: Icons.menu_book_outlined,
                tint: Tokens.pastelCyan,
                onTap: () => context.push('/readings'),
                caption: 'Chạm từ để tra, chạm câu để dịch · Nghe, Xếp từ, Đàm thoại, Nghe viết',
                preview: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Red Rubber Ball', style: ReadingStyles.line(context).copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Fred had a red '),
                    TextSpan(text: 'rubber', style: TextStyle(color: g.savedWord, fontWeight: FontWeight.w600)),
                    const TextSpan(text: ' ball. He kicked the ball…'),
                  ]), maxLines: 3, overflow: TextOverflow.ellipsis),
                ]),
              ),
              FeatureCard(
                title: 'Văn Phạm',
                icon: Icons.account_tree_outlined,
                tint: Tokens.pastelViolet,
                onTap: () => context.push('/grammar'),
                caption: 'Bài lý thuyết có liên kết thẳng tới bài tập',
                preview: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final t in const ['Thì', 'Động Từ Bất Quy Tắc', 'Đại Từ', 'Danh Từ…']) Text(t, style: TextStyle(color: g.ink)),
                ]),
              ),
              FeatureCard(
                title: 'Luyện Nghe',
                icon: Icons.headphones_outlined,
                tint: Tokens.pastelPeach,
                onTap: () => context.push('/listening'),
                caption: 'Unit 1–20 · nghe câu tiếng Anh, chọn câu Việt đúng',
                preview: Builder(builder: (context) {
                  final units = db.listeningUnits();
                  final item = units.isEmpty ? null : db.listeningItems(units.first).firstOrNull;
                  if (item == null) return const Text('Nghe câu tiếng Anh, chọn câu Việt đúng.');
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.en, style: TextStyle(color: g.ink), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    // One distractor ("Steve và Yaser không phải là bạn thân…") then the right answer.
                    for (final (i, o) in [item.options.length > 3 ? item.options[3] : item.options.last, item.correct].indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '${String.fromCharCode(97 + i)}) $o',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: o == item.correct ? g.iris : g.slate, fontWeight: o == item.correct ? FontWeight.w600 : FontWeight.w400),
                        ),
                      ),
                  ]);
                }),
              ),
              FeatureCard(
                title: 'Luyện Nói',
                icon: Icons.record_voice_over_outlined,
                tint: Tokens.pastelPink,
                onTap: () => context.push('/dialogs'),
                caption: 'Đàm thoại A→B theo chủ đề · Chọn câu để ôn tập',
                preview: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(children: [TextSpan(text: 'A: ', style: TextStyle(color: g.iris, fontWeight: FontWeight.w600)), TextSpan(text: 'Has she ever been in love?', style: TextStyle(color: g.ink))])),
                  Text.rich(TextSpan(children: [TextSpan(text: 'B: ', style: TextStyle(color: g.iris, fontWeight: FontWeight.w600)), TextSpan(text: 'No, she has never loved anyone.', style: TextStyle(color: g.ink))])),
                  const SizedBox(height: 2),
                  const Text('Cô ấy chưa hề yêu ai.', style: TextStyle(fontSize: 12)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // ---- study grid -----------------------------------------------------------
          const SectionTitle('Học'),
          const SizedBox(height: 16),
          AutoGrid(
            minWidth: 250,
            children: [
              for (final it in _learn)
                SetCard(
                  icon: it.icon,
                  title: it.title,
                  subtitle: it.title == 'Từ điển' ? '${counts['dict_entry']} mục · phiên âm · họ từ' : it.subtitle,
                  subtitleLines: 2,
                  onTap: () => context.push(it.route),
                ),
            ],
          ),
          const SizedBox(height: 40),

          // ---- test sets ------------------------------------------------------------
          const SectionTitle('Bài tập', hint: 'Mỗi bộ đề gồm nhiều Bài Tập 25 câu; điểm được lưu lại'),
          const SizedBox(height: 16),
          AutoGrid(
            minWidth: 300,
            children: [
              for (final m in menus)
                Builder(builder: (context) {
                  final groups = (m.count / groupSize).ceil();
                  var done = 0;
                  var score = 0;
                  for (final e in exerciseProgress.entries) {
                    if (!e.key.startsWith('menu${m.idx}-g')) continue;
                    final st = RegExp(r'"score":(\d+),"done":(\d+)').firstMatch(e.value);
                    if (st != null) {
                      score += int.parse(st.group(1)!);
                      done += int.parse(st.group(2)!);
                    }
                  }
                  final isWordForms = m.name.trim().toUpperCase() == 'WORD FORMS';
                  return SetCard(
                    title: m.name,
                    subtitle: '${isWordForms ? '${m.count} câu' : '$groups bài'} · ${_menuHints[m.name.trim().toUpperCase()] ?? ''}${done > 0 ? ' · đúng $score/$done' : ''}',
                    progress: m.count == 0 ? 0 : (done / m.count).clamp(0, 1),
                    subtitleLines: 1,
                    onTap: () => context.push(isWordForms ? '/exercises/wordforms' : '/exercises/menu/${m.idx}'),
                  );
                }),
            ],
          ),
          const SizedBox(height: 40),

          // ---- personal -------------------------------------------------------------
          const SectionTitle('Cá nhân'),
          const SizedBox(height: 16),
          AutoGrid(
            minWidth: 250,
            children: [
              for (final it in _personal)
                SetCard(
                  icon: it.icon,
                  title: it.title,
                  subtitle: it.title == 'Từ Vựng Của Bạn' && nWords == 0 ? 'Chưa có từ nào; chạm một từ trong bài để lưu' : it.subtitle,
                  badge: it.title == 'Từ Vựng Của Bạn' && nWords > 0 ? '$nWords' : null,
                  subtitleLines: 2,
                  onTap: () => context.push(it.route),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              appTitleWithVersion,
              style: theme.textTheme.bodySmall?.copyWith(color: g.fog),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseResume {
  final String menuName;
  final int group, pos, score, done, groups;
  const _ExerciseResume(this.menuName, this.group, this.pos, this.score, this.done, this.groups);
}

/// The most recent study activity for the "Đang học" card (U5).
class _Activity {
  final String label;   // group, and its section when there is one
  final String title;
  final String detail;
  final IconData icon;
  final ImageProvider? image;
  final String route;
  const _Activity(this.label, this.title, this.detail, this.icon, this.route, [this.image]);
}

/// Picks whichever of the seven study groups was opened last: Bài Đọc, Văn Phạm, Luyện
/// Nghe, Luyện Nói, Phân Tích Câu, Từ Vựng (Tranh), Video.
_Activity? _latestActivity(WidgetRef ref, bool wide) {
  final db = ref.read(contentDbProvider);
  final userDb = ref.read(userDbProvider);

  _Activity? reading() {
    final id = int.tryParse(userDb.progress('reading', 'last_reading') ?? '');
    final r = id == null ? null : loadReading(ref, id);
    if (r == null || r.sid == 0) return null;   // the IPA lesson has its own menu item
    final section = r.sid >= 0 ? db.section(r.sid)?.title : null;
    final image = r.img == null ? null : (r.id >= userReadingBase ? FileImage(File(r.img!)) : db.imageProvider(r.img!));
    return _Activity(section == null ? 'Bài Đọc' : 'Bài Đọc · $section', r.title, '${r.sentences.length} câu${r.hasRealAudio ? ' · giọng đọc thật' : ''}', Icons.menu_book_outlined, '/readings/${r.id}', image);
  }

  _Activity? analysis() {
    final lesson = int.tryParse(userDb.progress('analysis', 'last') ?? '');
    final i = lesson == null ? -1 : db.analysisLessonIds().indexOf(lesson);
    final ids = analysisReadingIds(db);
    final r = i < 0 || i >= ids.length ? null : db.reading(ids[i]);
    if (r == null) return null;
    return _Activity('Phân Tích Câu', r.title, 'Bài ${i + 1}', Icons.manage_search, '/analysis/$lesson', r.img == null ? null : db.imageProvider(r.img!));
  }

  _Activity? grammar() {
    final n = int.tryParse(userDb.progress('grammar', 'last_lesson') ?? '');
    final l = n == null ? null : db.grammarLesson(n);
    if (l == null) return null;
    // Wide screens show lessons inside the tree page, which reopens the last lesson.
    return _Activity('Văn Phạm', l.title, '', Icons.account_tree_outlined, wide ? '/grammar' : '/grammar/${l.ref}');
  }

  _Activity? listening() {
    final u = int.tryParse(userDb.progress('listening', 'last') ?? '');
    if (u == null || !db.listeningUnits().contains(u)) return null;
    final source = db.listeningReadingTitle(u);
    final img = source == null ? null : db.reading(source.id)?.img;   // the unit's reading
    return _Activity('Luyện Nghe', source == null ? 'Unit $u' : 'Unit $u · ${source.title}', userDb.progress('listening', 'unit$u') ?? '${db.listeningCount(u)} câu', Icons.hearing_outlined, '/listening/$u', img == null ? null : db.imageProvider(img));
  }

  _Activity? dialog() {
    final id = int.tryParse(userDb.progress('dialog', 'last') ?? '');
    final d = id == null ? null : db.dialog(id);
    if (d == null) return null;
    final topic = db.dialogTopic(d.sid)?.title;
    final img = db.dialogPageImage(d.id);   // the picture the dialog page shows
    return _Activity(topic == null ? 'Luyện Nói' : 'Luyện Nói · $topic', d.title, '${d.pairs.length} cặp câu', Icons.record_voice_over_outlined, '/dialogs/${d.id}', img == null ? null : db.imageProvider(img));
  }

  _Activity? pictures() {
    final id = int.tryParse(userDb.progress('pictures', 'last') ?? '');
    final t = id == null ? null : db.pictureTopic(id);
    if (t == null) return null;
    return _Activity('Từ Vựng (Tranh)', t.title, '${t.words.length} từ', Icons.image_outlined, '/pictures/${t.id}', t.page == null ? null : db.imageProvider(t.page!));
  }

  _Activity? video() {
    final id = int.tryParse(userDb.progress('video', 'last') ?? '');
    final f = id == null ? null : db.film(id);
    if (f == null) return null;
    return _Activity('Video', f.title, '${f.code} · ${f.lines} câu phụ đề', Icons.movie_outlined, '/video/${f.id}');
  }

  // Analysis comes before reading: opening an analysis lesson also records its reading in
  // the same instant, and the earlier entry wins a tie.
  final candidates = <(String, String, _Activity? Function())>[
    ('analysis', 'last', analysis),
    ('reading', 'last_reading', reading),
    ('grammar', 'last_lesson', grammar),
    ('listening', 'last', listening),
    ('dialog', 'last', dialog),
    ('pictures', 'last', pictures),
    ('video', 'last', video),
  ];
  final byTime = [
    for (final (kind, item, build) in candidates)
      if (userDb.progressTime(kind, item) case final t?) (t, build),
  ]..sort((a, b) => b.$1.compareTo(a.$1));   // stable: ties keep the order above
  for (final (_, build) in byTime) {
    final a = build();
    if (a != null) return a;
  }
  return null;
}

class _Thumb extends StatelessWidget {
  final ImageProvider? image;
  final IconData icon;
  const _Thumb({this.image, this.icon = Icons.menu_book_outlined});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final box = Container(width: 64, height: 64, decoration: BoxDecoration(color: g.lilac, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: g.iris));
    if (image == null) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image(image: image!, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, _, _) => box),
    );
  }
}
