/// SQLite and the content folder on the desktop and mobile apps (`dart:io`, `dart:ffi`); the web
/// build gets stubs that throw, since its data comes from elsewhere (docs/07 §12).
library;

export 'native_io.dart' if (dart.library.js_interop) 'native_web.dart';
