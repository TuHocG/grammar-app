/// Process environment of the desktop apps (none on the web).
library;

export 'env_io.dart' if (dart.library.js_interop) 'env_web.dart';
