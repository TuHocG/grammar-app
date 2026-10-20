import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import 'video_pages.dart';

List<RouteBase> videoRoutes() => [
  GoRoute(
    path: '/video',
    // A `web` database has no subtitles (docs/09): a typed or restored URL lands on Luyện Nghe.
    redirect: (c, _) => ProviderScope.containerOf(c).read(contentDbProvider).hasVideo ? null : '/listening',
    builder: (_, _) => const VideoListPage(),
    routes: [
      GoRoute(
        path: ':id',
        builder: (_, s) => VideoPlayerPage(id: int.parse(s.pathParameters['id']!)),
      ),
    ],
  ),
];
