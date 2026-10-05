import 'package:go_router/go_router.dart';

import '../ui/dictionary/dictionary_page.dart';
import '../ui/dictionary/entry_page.dart';
import '../ui/help/help_page.dart';
import '../ui/home/home_page.dart';
import '../ui/settings/settings_page.dart';
import '../ui/vocab/my_words_page.dart';

GoRouter buildRouter() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(
          path: '/dict',
          builder: (_, s) => DictionaryPage(initialQuery: s.uri.queryParameters['q']),
          routes: [
            GoRoute(path: 'word/:word', builder: (_, s) => EntryPage(word: Uri.decodeComponent(s.pathParameters['word']!))),
            GoRoute(path: ':id', builder: (_, s) => EntryPage(id: int.tryParse(s.pathParameters['id']!))),
          ],
        ),
        GoRoute(path: '/words', builder: (_, _) => const MyWordsPage()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        GoRoute(
          path: '/help',
          builder: (_, _) => const HelpListPage(),
          routes: [GoRoute(path: ':id', builder: (_, s) => HelpTopicPage(id: int.parse(s.pathParameters['id']!)))],
        ),
      ],
    );
