/// Hướng dẫn: the 28 in-app help topics + ReadMe (docs/08 G21).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../widgets/shell.dart';

class HelpListPage extends ConsumerWidget {
  const HelpListPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.read(contentDbProvider).helpTopics();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: GrammarAppBar(crumbs: const [Crumb('Hướng Dẫn Cách Học')]),
      body: RailListView(
        maxWidth: 900,
        children: [
          Text('Hướng Dẫn Cách Học', style: theme.textTheme.headlineLarge),
          Text('${topics.length} bài hướng dẫn của app gốc, theo từng mục', style: theme.textTheme.bodyLarge?.copyWith(color: context.g.slate)),
          const SizedBox(height: 20),
          Surface(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              for (final t in topics)
                ListTile(
                  leading: LetterDot('${t.id}', size: 30),
                  title: Text(t.title),
                  trailing: Icon(Icons.chevron_right, color: context.g.fog),
                  onTap: () => context.push('/help/${t.id}'),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class HelpTopicPage extends ConsumerWidget {
  final int id;
  const HelpTopicPage({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.read(contentDbProvider).helpTopic(id);
    if (t == null) return const Scaffold(body: EmptyNote('Không có bài này.'));
    return Scaffold(
      appBar: GrammarAppBar(crumbs: [const Crumb('Hướng Dẫn Cách Học', '/help'), Crumb(t.title)]),
      body: RailListView(
        maxWidth: 900,
        children: [
          Surface(
            padding: const EdgeInsets.all(32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              SelectableText(t.text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.7)),
            ]),
          ),
        ],
      ),
    );
  }
}
