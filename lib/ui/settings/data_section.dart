/// Cài Đặt → Dữ liệu: the folders of the desktop and mobile apps (`content_sources.dart`), or
/// the web app's note until its data layer exists (docs/07 §12).
library;

export 'content_sources.dart' if (dart.library.js_interop) 'data_section_web.dart';
