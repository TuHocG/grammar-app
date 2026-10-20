/// The app's folders on the desktop and mobile apps (`path_provider`); none on the web.
library;

export 'app_dirs_io.dart' if (dart.library.js_interop) 'app_dirs_web.dart';
