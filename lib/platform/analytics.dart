/// Page views for Google Analytics on the web site (docs/07 §12); nothing on the other platforms.
library;

export 'analytics_io.dart' if (dart.library.js_interop) 'analytics_web.dart';
