/// Build-time configuration shared by the bootstrap and the pages that open a database.
library;

/// Key of the encrypted content database in release builds (`--dart-define=GRAMMAR_DB_KEY=...`,
/// set by the release workflow from a secret). Empty in development, where the database is plain;
/// a plain database also opens when a key is set (ContentDb.open falls back).
const grammarDbKey = String.fromEnvironment('GRAMMAR_DB_KEY');

/// `version` of pubspec.yaml without the build number; `flutter run` and `flutter build` pass it
/// as FLUTTER_BUILD_NAME. Empty under `flutter test`.
const appVersion = String.fromEnvironment('FLUTTER_BUILD_NAME');

/// "Grammar 4.0 - Phiên bản 1.0.1", shown on the home page and in Settings › Giới thiệu.
const appTitleWithVersion = appVersion == '' ? 'Grammar 4.0' : 'Grammar 4.0 - Phiên bản $appVersion';

/// Build number after the `+` of the pubspec version, passed like [appVersion].
const appBuildNumber = String.fromEnvironment('FLUTTER_BUILD_NUMBER');

/// Short hash of the commit the app was built from (`--dart-define=GIT_COMMIT=...`, set by the
/// release workflow). Empty in local builds unless passed by hand.
const gitCommit = String.fromEnvironment('GIT_COMMIT');

/// Subject line of that commit (`--dart-define=GIT_COMMIT_MESSAGE=...`, set alongside [gitCommit]).
const gitCommitMessage = String.fromEnvironment('GIT_COMMIT_MESSAGE');
