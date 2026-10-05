/// Hướng dẫn: the 28 in-app help topics + ReadMe (docs/08 G21).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';

class HelpListPage extends ConsumerWidget {
  const HelpListPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.read(contentDbProvider).helpTopics();
    return Scaffold(
      appBar: AppBar(title: const Text('Hướng Dẫn Cách Học')),
      body: ListView(
        children: [
          for (final t in topics)
            ListTile(
              leading: Text('${t.id}', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
              title: Text(t.title),
              onTap: () => context.push('/help/${t.id}'),
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
    if (t == null) return const Scaffold(body: Center(child: Text('Không có bài này.')));
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(t.text, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
