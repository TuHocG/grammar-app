/// Startup: where user.db and the content come from differs between the desktop and mobile apps
/// (files, `bootstrap_io.dart`) and the web app (the browser's storage, `bootstrap_web.dart`);
/// both end in [startApp].
library;

export 'bootstrap_io.dart' if (dart.library.js_interop) 'bootstrap_web.dart';
