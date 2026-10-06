/// Main menu (docs/08 G1): everything the old two-column menu offered, laid out as
/// "continue where you were" cards, four feature cards, the study grid and the nine test sets.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_db.dart';
import '../../data/content_db_more.dart';
import '../../data/reading_loader.dart';
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
    final s = ref.watch(settingsProvider);
    final nWords = ref.watch(userWordsProvider).words.length;
    final counts = db.counts;
    final menus = db.exerciseMenus();
    final exerciseProgress = userDb.progressOf('exercise', prefix: 'menu');

    // "Continue" cards.
    final lastReadingId = int.tryParse(userDb.progress('reading', 'last_reading') ?? '');
    final lastLoaded = lastReadingId == null ? null : loadReading(ref, lastReadingId);
    final lastReading = lastLoaded == null || lastLoaded.sid == 0 ? null : lastLoaded;   // the IPA lesson has its own menu item
    final lastEx = userDb.latestProgress('exercise', prefix: 'menu');
    _ExerciseResume? resume;
    if (lastEx != null) {
      final m = RegExp(r'^menu(\d+)-g(\d+)$').firstMatch(lastEx.$1);
      final st = RegExp(r'"pos":(\d+),"score":(\d+),"done":(\d+)').firstMatch(lastEx.$2);
      if (m != null && st != null) {
        final menu = menus.where((x) => x.idx == int.parse(m.group(1)!)).firstOrNull;
        if (menu != null) {
          resume = _ExerciseResume(menu.name, int.parse(m.group(2)!), int.parse(st.group(1)!), int.parse(st.group(2)!), int.parse(st.group(3)!), (menu.count / groupSize).ceil());
        }
      }
    }

    return Scaffold(
      appBar: GrammarAppBar(
        title: Row(children: [
          Text('Grammar 4.0', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (context.isWide) ...[
            const SizedBox(width: 32),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SearchPill(hint: 'Tra từ nhanh… (gõ ở bất kỳ đâu để tìm)', readOnly: true, onTap: () => context.push('/dict')),
              ),
            ),
          ] else
            const Spacer(),
        ]),
        actions: [
          if (!context.isWide) IconButton(tooltip: 'Tra từ', icon: const Icon(Icons.search), onPressed: () => context.push('/dict')),
          if (context.isWide) TextButton(onPressed: () => context.push('/help'), child: const Text('Hướng dẫn cách học')),
          const SizedBox(width: 4),
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
              Text('Giọng ${s.ttsVoice == null ? 'hệ thống' : 'riêng'} · Tốc độ ${s.ttsSpeed}', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)),
            ]),
          ]),
          if (lastReading != null || resume != null) ...[
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, c) {
              final stacked = c.maxWidth < 760;
              final cards = <Widget>[
                if (lastReading != null)
                  Surface(
                    onTap: () => context.push('/readings/${lastReading.id}'),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(children: [
                      _Thumb(path: lastReading.img == null ? null : (lastReading.id >= userReadingBase ? lastReading.img : db.mediaPath(lastReading.img!))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Đang đọc${lastReading.sid >= 0 ? ' · ${db.section(lastReading.sid)?.title ?? ''}' : ''}', style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(lastReading.title, style: ReadingStyles.line(context).copyWith(fontSize: 20, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${lastReading.sentences.length} câu${lastReading.hasRealAudio ? ' · giọng đọc thật' : ''}', style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(onPressed: () => context.push('/readings/${lastReading.id}'), child: const Text('Tiếp tục')),
                    ]),
                  ),
                if (resume != null)
                  Surface(
                    onTap: () => context.push('/exercises/menu/${menus.firstWhere((m) => m.name == resume!.menuName).idx}/${resume!.group}'),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Bài tập dở dang', style: theme.textTheme.bodySmall),
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
                  if (lastReading != null) Expanded(flex: 2, child: cards.first),
                  if (lastReading != null && resume != null) const SizedBox(width: 16),
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
              'Kế thừa Grammar 3.1 của TuHocTiengAnh.net theo uỷ thác của tác giả. Miễn phí.',
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

class _Thumb extends StatelessWidget {
  final String? path;
  const _Thumb({this.path});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final box = Container(width: 64, height: 64, decoration: BoxDecoration(color: g.lilac, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.menu_book_outlined, color: g.iris));
    if (path == null) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(File(path!), width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, _, _) => box),
    );
  }
}
