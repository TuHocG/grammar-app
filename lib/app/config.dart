/// Build-time configuration shared by the bootstrap and the pages that open a database.
library;

/// Key of the encrypted content database in release builds (`--dart-define=GRAMMAR_DB_KEY=...`,
/// set by the release workflow from a secret). Empty in development, where the database is plain;
/// a plain database also opens when a key is set (ContentDb.open falls back).
const grammarDbKey = String.fromEnvironment('GRAMMAR_DB_KEY');
