/// Hướng Dẫn Cách Học (docs/08 G21): the help topics of Grammar 4.0 from help_content.dart,
/// listed as cards by group; a topic page renders the small markup of [AppHelpTopic.body].
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../widgets/shell.dart';
import 'help_content.dart';

class HelpListPage extends StatelessWidget {
  const HelpListPage({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: GrammarAppBar(crumbs: const [Crumb('Hướng Dẫn Cách Học')]),
      body: RailListView(
        children: [
          Text('Hướng Dẫn Cách Học', style: theme.textTheme.headlineLarge),
          Text('Cách dùng từng phần của app, trên máy tính và điện thoại', style: theme.textTheme.bodyLarge?.copyWith(color: context.g.slate)),
          for (final section in helpSections) ...[
            const SizedBox(height: 32),
            SectionTitle(section),
            const SizedBox(height: 16),
            AutoGrid(
              minWidth: 280,
              children: [
                for (final t in helpTopics.where((t) => t.section == section))
                  SetCard(icon: t.icon, title: t.title, subtitle: t.summary, subtitleLines: 2, onTap: () => context.push('/help/${t.slug}')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class HelpTopicPage extends StatelessWidget {
  final String slug;
  const HelpTopicPage({super.key, required this.slug});
  @override
  Widget build(BuildContext context) {
    final t = helpTopicBySlug(slug);
    if (t == null) {
      return Scaffold(
        appBar: GrammarAppBar(crumbs: const [Crumb('Hướng Dẫn Cách Học', '/help')]),
        body: const EmptyNote('Không có bài hướng dẫn này.'),
      );
    }
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final i = helpTopics.indexOf(t);
    final prev = i > 0 ? helpTopics[i - 1] : null;
    final next = i < helpTopics.length - 1 ? helpTopics[i + 1] : null;
    return Scaffold(
      appBar: GrammarAppBar(crumbs: [const Crumb('Hướng Dẫn Cách Học', '/help'), Crumb(t.title)]),
      body: RailListView(
        maxWidth: 900,
        children: [
          Surface(
            padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 40, vertical: narrow ? 24 : 32),
            child: SelectionArea(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconTile(t.icon),
                  const SizedBox(width: 14),
                  Expanded(child: Text(t.title, style: theme.textTheme.headlineMedium)),
                ]),
                const SizedBox(height: 8),
                Text(t.summary, style: theme.textTheme.bodyLarge?.copyWith(color: context.g.slate)),
                const SizedBox(height: 8),
                HelpMarkup(t.body),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: PrevNextBar(
        onPrev: prev == null ? null : () => context.pushReplacement('/help/${prev.slug}'),
        onNext: next == null ? null : () => context.pushReplacement('/help/${next.slug}'),
        prevLabel: prev?.title ?? 'Bài trước',
        nextLabel: next?.title ?? 'Bài kế',
      ),
    );
  }
}

/// Renders the help markup: blank line = new paragraph, `## ` = subheading, `- ` = bullet,
/// `**bold**` inline. Consecutive plain lines join into one paragraph.
class HelpMarkup extends StatelessWidget {
  final String text;
  const HelpMarkup(this.text, {super.key});

  static final _bold = RegExp(r'\*\*(.+?)\*\*');

  List<InlineSpan> _inline(String s, TextStyle bold) {
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in _bold.allMatches(s)) {
      if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start)));
      out.add(TextSpan(text: m.group(1), style: bold));
      last = m.end;
    }
    if (last < s.length) out.add(TextSpan(text: s.substring(last)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.g;
    final body = theme.textTheme.bodyLarge!.copyWith(fontSize: 16.5, height: 1.6, color: g.ink);
    final bold = TextStyle(fontWeight: FontWeight.w600, color: g.ink);
    final out = <Widget>[];
    final para = <String>[];

    void flush() {
      if (para.isEmpty) return;
      out.add(Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text.rich(TextSpan(style: body, children: _inline(para.join(' '), bold))),
      ));
      para.clear();
    }

    for (final raw in text.trim().split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        flush();
      } else if (line.startsWith('## ')) {
        flush();
        out.add(Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 2),
          child: Text(line.substring(3).trim(), style: theme.textTheme.titleMedium?.copyWith(color: g.indigo, fontWeight: FontWeight.w700)),
        ));
      } else if (line.startsWith('- ')) {
        flush();
        out.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 22, child: Text('•', style: body.copyWith(color: g.iris, fontWeight: FontWeight.w700))),
            Expanded(child: Text.rich(TextSpan(style: body, children: _inline(line.substring(2).trim(), bold)))),
          ]),
        ));
      } else {
        para.add(line.trim());
      }
    }
    flush();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }
}
