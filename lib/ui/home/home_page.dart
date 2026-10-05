/// Main menu: the 18 entries of the old app plus the dictionary (docs/08 G1).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';

class _Item {
  final String title;
  final IconData icon;
  final String? route;
  final String? note;
  const _Item(this.title, this.icon, {this.route, this.note});
}

const _learn = [
  _Item('Từ điển', Icons.search, route: '/dict'),
  _Item('Bài Đọc', Icons.menu_book, route: '/readings'),
  _Item('Từ Vựng Của Bạn', Icons.bookmarks, route: '/words'),
  _Item('Văn Phạm', Icons.account_tree, route: '/grammar'),
  _Item('Luyện Nghe', Icons.headphones, route: '/listening'),
  _Item('Phân Tích Câu', Icons.manage_search, note: 'M5'),
  _Item('Từ Vựng (Tranh)', Icons.image_search, note: 'M5'),
  _Item('Luyện Nói', Icons.record_voice_over, route: '/dialogs'),
  _Item('Cài Đặt', Icons.settings, route: '/settings'),
  _Item('Hướng Dẫn Cách Học', Icons.help_outline, route: '/help'),
];

const _exercises = [
  'ARTICLES', 'CONDITIONAL', 'TENSE', 'PREPOSITION / IDIOMS', 'PRELIMINARY TEST A',
  'PRELIMINARY TEST B', 'TOEFL TEST', 'B+C VOCABULARY', 'WORD FORMS',
];

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final nWords = ref.watch(userWordsProvider).words.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grammar'),
        actions: [
          IconButton(tooltip: 'Tra từ', icon: const Icon(Icons.search), onPressed: () => context.push('/dict')),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final cols = (c.maxWidth / 200).floor().clamp(2, 5);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(child: Text('Học', style: theme.textTheme.titleMedium)),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid.count(
                  crossAxisCount: cols,
                  childAspectRatio: 1.9,
                  children: [
                    for (final it in _learn)
                      _Tile(
                        title: it.title,
                        icon: it.icon,
                        enabled: it.route != null,
                        badge: it.title == 'Từ Vựng Của Bạn' && nWords > 0 ? '$nWords' : it.note,
                        onTap: it.route == null ? null : () => context.push(it.route!),
                      ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                sliver: SliverToBoxAdapter(child: Text('Bài tập', style: theme.textTheme.titleMedium)),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid.count(
                  crossAxisCount: cols,
                  childAspectRatio: 1.9,
                  children: [
                    for (var i = 0; i < _exercises.length; i++)
                      _Tile(
                        title: _exercises[i],
                        icon: i == 8 ? Icons.spellcheck : Icons.edit_note,
                        enabled: true,
                        onTap: () => context.push(i == 8 ? '/exercises/wordforms' : '/exercises/menu/$i'),
                      ),
                  ],
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool enabled;
  final String? badge;
  final VoidCallback? onTap;
  const _Tile({required this.title, required this.icon, required this.enabled, this.badge, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = enabled ? theme.colorScheme.onSurface : theme.colorScheme.outline;
    return Card(
      margin: const EdgeInsets.all(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(icon, color: enabled ? theme.colorScheme.primary : theme.colorScheme.outline),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: fg), maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: enabled ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!, style: theme.textTheme.labelSmall),
              ),
          ]),
        ),
      ),
    );
  }
}
