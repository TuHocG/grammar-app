// Encrypts a copy of grammar.db with SQLite3MultipleCiphers (docs/07 §11).
//
//   dart run tool/encrypt_db.dart <plain grammar.db> <output.db> <key>
//
// Uses the same package:sqlite3 build as the app (hooks user_defines: source sqlite3mc), so the
// output opens in the app with `PRAGMA key`. `PRAGMA rekey` on a plain database encrypts it.
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln('usage: dart run tool/encrypt_db.dart <plain.db> <out.db> <key>');
    exit(2);
  }
  final src = File(args[0]);
  final out = File(args[1]);
  if (out.existsSync()) out.deleteSync();
  src.copySync(out.path);
  final db = sqlite3.open(out.path);
  db.execute("PRAGMA rekey = '${args[2].replaceAll("'", "''")}'");
  db.close();
  final check = sqlite3.open(out.path);
  try {
    check.select('SELECT 1 FROM meta');
    stderr.writeln('ERROR: output still opens without a key');
    exit(1);
  } catch (_) {
    // expected: unreadable without the key
  }
  check.close();
  final keyed = sqlite3.open(out.path)..execute("PRAGMA key = '${args[2].replaceAll("'", "''")}'");
  final n = keyed.select('SELECT COUNT(*) AS n FROM dict_entry').first['n'];
  keyed.close();
  stdout.writeln('encrypted ${out.path} (${(out.lengthSync() / 1048576).toStringAsFixed(1)} MB), dict_entry=$n');
}
