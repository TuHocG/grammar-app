import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import '../data/content_db_more.dart';

import '../ui/dictionary/dictionary_page.dart';
import '../ui/dictionary/entry_page.dart';
import '../ui/help/help_page.dart';
import '../data/reading_loader.dart';
import '../ui/readings/ipa_lesson_page.dart';
import '../ui/analysis/analysis_page.dart';
import '../ui/dialogs/dialog_pages.dart';
import '../ui/pictures/picture_pages.dart';
import '../ui/user_readings/user_reading_pages.dart';
import '../ui/vocab/spin_words_page.dart';
import '../ui/exercises/exercise_pages.dart';
import '../ui/listening/listening_page.dart';
import '../ui/video/video_pages.dart';
import '../ui/grammar/grammar_page.dart';
import '../ui/home/home_page.dart';
import '../ui/readings/dialog_practice_page.dart';
import '../ui/readings/dictation_page.dart';
import '../ui/readings/listen_page.dart';
import '../ui/readings/reading_page.dart';
import '../ui/readings/reading_toc_page.dart';
import '../ui/readings/scramble_page.dart';
import '../ui/settings/settings_page.dart';
import '../ui/vocab/my_words_page.dart';

/// Environment variable `GRAMMAR_INITIAL_ROUTE=/dict/word/ball` opens a screen directly (dev/screenshots).
String get _initialRoute => Platform.environment['GRAMMAR_INITIAL_ROUTE'] ?? '/';

GoRouter buildRouter() => GoRouter(
  initialLocation: _initialRoute,
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomePage()),
    GoRoute(path: '/ipa', builder: (_, _) => const IpaLessonPage()),
    GoRoute(
      path: '/dict',
      builder: (_, s) => DictionaryPage(initialQuery: s.uri.queryParameters['q']),
      routes: [
        GoRoute(
          path: 'word/:word',
          builder: (_, s) => EntryPage(word: Uri.decodeComponent(s.pathParameters['word']!)),
        ),
        GoRoute(
          path: ':id',
          builder: (_, s) => EntryPage(id: int.tryParse(s.pathParameters['id']!)),
        ),
      ],
    ),
    GoRoute(
      path: '/readings',
      builder: (_, _) => const ReadingTocPage(),
      routes: [
        GoRoute(
          path: 'section/:sid',
          builder: (_, s) => ReadingListPage(sid: int.parse(s.pathParameters['sid']!)),
        ),
        GoRoute(
          path: ':id',
          builder: (context, s) {
            final id = int.parse(s.pathParameters['id']!);
            // Section 0 "Phiên Âm Quốc Tế" is the home-menu lesson at /ipa; old links land there too.
            final r = loadReadingFrom(ProviderScope.containerOf(context), id);
            return r != null && r.sid == 0 ? IpaLessonPage(id: id) : ReadingPage(id: id);
          },
          routes: [
            GoRoute(
              path: 'listen',
              builder: (_, s) => ListenPage(id: int.parse(s.pathParameters['id']!)),
            ),
            GoRoute(
              path: 'scramble',
              builder: (_, s) => ScramblePage(id: int.parse(s.pathParameters['id']!)),
            ),
            GoRoute(
              path: 'dictation',
              builder: (_, s) => DictationPage(id: int.parse(s.pathParameters['id']!)),
            ),
            GoRoute(
              path: 'dialog',
              builder: (context, s) {
                final r = loadReadingFrom(ProviderScope.containerOf(context), int.parse(s.pathParameters['id']!));
                return r == null ? const ReadingPage(id: -1) : DialogPracticePage.forReading(r);
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/grammar',
      builder: (_, _) => const GrammarPage(),
      routes: [
        GoRoute(
          path: ':ref',
          builder: (_, s) => GrammarLessonPage(ref: int.parse(s.pathParameters['ref']!), saved: s.uri.queryParameters['saved'] == '1'),
        ),
      ],
    ),
    GoRoute(path: '/my-grammar', builder: (_, _) => const GrammarPage(savedOnly: true)),
    GoRoute(
      path: '/exercises',
      redirect: (_, s) => s.uri.path == '/exercises' ? '/' : null,
      routes: [
        GoRoute(
          path: 'menu/:menu',
          builder: (_, s) => ExerciseGroupsPage(menuIdx: int.parse(s.pathParameters['menu']!)),
          routes: [
            GoRoute(
              path: ':group',
              builder: (_, s) => ExerciseGroupRunPage(menuIdx: int.parse(s.pathParameters['menu']!), group: int.parse(s.pathParameters['group']!)),
            ),
          ],
        ),
        GoRoute(
          path: 'lessons/:refs',
          builder: (_, s) => LessonExercisesPage(refs: s.pathParameters['refs']!.split(',').map(int.parse).toList()),
        ),
        GoRoute(
          path: 'wordforms',
          builder: (_, _) => const WordFormsPage(),
          routes: [
            GoRoute(
              path: ':positions',
              builder: (_, s) => WordFormsRunPage(positions: s.pathParameters['positions']!.split(',').map(int.parse).toList()),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/dialogs',
      builder: (_, _) => const DialogTopicsPage(),
      routes: [
        GoRoute(
          path: 'topic/:sid',
          builder: (_, s) => DialogListPage(sid: int.parse(s.pathParameters['sid']!)),
          routes: [
            GoRoute(
              path: 'review',
              builder: (context, s) {
                final c = ProviderScope.containerOf(context);
                return topicReview(c.read(contentDbProvider), c.read(userDbProvider), int.parse(s.pathParameters['sid']!));
              },
            ),
          ],
        ),
        GoRoute(
          path: ':id',
          builder: (_, s) => DialogPage(id: int.parse(s.pathParameters['id']!)),
          routes: [
            GoRoute(
              path: 'practice',
              builder: (context, s) {
                final db = ProviderScope.containerOf(context).read(contentDbProvider);
                final d = db.dialog(int.parse(s.pathParameters['id']!));
                return d == null ? const DialogTopicsPage() : dialogPractice(db, d);
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/listening',
      builder: (_, _) => const ListeningUnitsPage(),
      routes: [
        GoRoute(
          path: ':unit',
          builder: (_, s) => ListeningUnitPage(unit: int.parse(s.pathParameters['unit']!)),
        ),
      ],
    ),
    GoRoute(
      path: '/video',
      builder: (_, _) => const VideoListPage(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (_, s) => VideoPlayerPage(id: int.parse(s.pathParameters['id']!)),
        ),
      ],
    ),
    GoRoute(
      path: '/analysis',
      builder: (_, _) => const AnalysisListPage(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, s) {
            // Lesson id -> its reading, opened in analysis mode.
            final lesson = int.parse(s.pathParameters['id']!);
            final db = ProviderScope.containerOf(context).read(contentDbProvider);
            final ids = db.analysisLessonIds();
            final readings = analysisReadingIds(db);
            final i = ids.indexOf(lesson);
            return i >= 0 && i < readings.length ? ReadingPage(id: readings[i], fromAnalysis: true) : const AnalysisListPage();
          },
        ),
      ],
    ),
    GoRoute(
      path: '/pictures',
      builder: (_, _) => const PictureTopicsPage(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (_, s) => PictureTopicPage(id: int.parse(s.pathParameters['id']!)),
        ),
      ],
    ),
    GoRoute(path: '/spin', builder: (_, _) => const SpinWordsPage()),
    GoRoute(
      path: '/my-readings',
      builder: (_, _) => const UserReadingsPage(),
      routes: [
        GoRoute(path: 'new', builder: (_, _) => const UserReadingEditPage()),
        GoRoute(
          path: ':id/edit',
          builder: (_, s) => UserReadingEditPage(id: int.parse(s.pathParameters['id']!)),
        ),
      ],
    ),
    GoRoute(path: '/words', builder: (_, _) => const MyWordsPage()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
    GoRoute(
      path: '/help',
      builder: (_, _) => const HelpListPage(),
      routes: [
        GoRoute(
          path: ':slug',
          builder: (_, s) => HelpTopicPage(slug: s.pathParameters['slug']!),
        ),
      ],
    ),
  ],
);
