/// The Video routes (Luyện Nghe → Video). The desktop and mobile apps play files from a folder
/// with `media_kit` (`video_pages.dart`); the web app has no video (docs/07 §12) and no routes,
/// so a typed URL falls through to the router's error page.
library;

export 'video_routes_io.dart' if (dart.library.js_interop) 'video_routes_web.dart';
