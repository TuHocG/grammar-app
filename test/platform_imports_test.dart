// The web build (docs/07 §12) compiles everything under lib/ except what sits behind a
// conditional import. `dart:io` compiles for the web and only fails when it runs, so the build
// does not catch it: this test does. Anything that needs a file system, the native SQLite library
// or a native-only plugin must stay in a `*_io.dart` file or in one of the files listed here,
// which only `*_io.dart` files (or each other) import.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Files the web build never reaches (imported only from `*_io.dart` files or from each other).
const nativeOnly = {
  'lib/data/content_db_io.dart',
  'lib/data/folder_media.dart',
  'lib/data/image_pack.dart',
  'lib/data/media_locations.dart',
  'lib/platform/storage_access.dart',
  'lib/ui/settings/content_sources.dart',
  'lib/ui/settings/data_picker.dart',
  'lib/ui/setup/download_dialog.dart',
  'lib/ui/setup/setup_page.dart',
  'lib/ui/video/video_pages.dart',
};

const nativeLibraries = ['dart:io', 'dart:ffi', 'package:path_provider/', 'package:sqlite3/sqlite3.dart', 'package:media_kit', 'package:permission_handler'];

/// Every `import` or `export` directive of a Dart source: the default URI and what follows it.
final _directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]([^;]*);''', multiLine: true);

/// The imported URI as a repo path (`lib/...`), for the app's own files; null for other packages.
String? _localPath(String from, String uri) {
  if (uri.startsWith('package:grammar/')) return 'lib/${uri.substring('package:grammar/'.length)}';
  if (uri.contains(':')) return null;
  return p.posix.normalize(p.posix.join(p.posix.dirname(from), uri));
}

Iterable<(String, List<String>)> _sharedFiles() sync* {
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
    final rel = p.posix.joinAll(p.split(f.path));
    if (!rel.endsWith('.dart') || rel.endsWith('_io.dart') || nativeOnly.contains(rel)) continue;
    // A conditional directive names the native file as its default: the web build never loads it.
    yield (
      rel,
      [
        for (final m in _directive.allMatches(f.readAsStringSync()))
          if (!m.group(2)!.contains('if (')) m.group(1)!,
      ],
    );
  }
}

void main() {
  test('dart:io and native-only packages stay behind conditional imports', () {
    final offenders = [
      for (final (file, uris) in _sharedFiles())
        for (final u in uris)
          if (nativeLibraries.any(u.startsWith)) '$file → $u',
    ];
    expect(offenders, isEmpty, reason: 'move the native part to a *_io.dart file (see lib/platform/) or list the file in nativeOnly');
  });

  test('native-only files are reached only from native-only or *_io.dart files', () {
    final offenders = [
      for (final (file, uris) in _sharedFiles())
        for (final u in uris)
          if (nativeOnly.contains(_localPath(file, u))) '$file → $u',
    ];
    expect(offenders, isEmpty);
  });

  test('the native-only list names existing files', () {
    expect(nativeOnly.where((f) => !File(f).existsSync()), isEmpty);
  });
}
