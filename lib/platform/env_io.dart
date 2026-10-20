import 'dart:io';

/// Environment variable `GRAMMAR_INITIAL_ROUTE=/dict/word/ball` opens a screen directly (dev/screenshots).
String initialRoute() => Platform.environment['GRAMMAR_INITIAL_ROUTE'] ?? '/';
