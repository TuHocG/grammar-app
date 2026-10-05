/// Word lookup as the old app does it (docs/08 G3–G8, docs/source/C §3):
/// quick definition → full entry → "Xem#x#" redirect → one try at the base form of an
/// inflected word → related forms.
library;

import '../data/content_db.dart';
import '../data/models.dart';
import '../data/search_key.dart';

class LookupResult {
  /// What the user tapped, cleaned.
  final String query;
  /// Key actually found (may differ from the query after stemming/redirect).
  final String key;
  final QuickDef? quick;
  final List<DictEntry> entries;
  final WordFamily? family;
  /// Headword followed through "Xem#x#", if any.
  final String? redirectedFrom;
  const LookupResult({
    required this.query,
    required this.key,
    this.quick,
    required this.entries,
    this.family,
    this.redirectedFrom,
  });

  bool get found => quick != null || entries.isNotEmpty;
  String get headword => entries.isNotEmpty ? entries.first.headword : (quick?.word ?? query);
  String? get ipa => quick?.ipa ?? (entries.isNotEmpty ? entries.first.ipa : null);
}

class LookupService {
  final ContentDb db;
  LookupService(this.db);

  LookupResult lookup(String raw) {
    final query = cleanToken(raw);
    final key = searchKey(query);
    if (key.isEmpty) return LookupResult(query: query, key: key, entries: const []);

    var r = _direct(query, key);
    if (r.found) return r;

    // Variant: the old app retries exactly once with the base form (DoiBienThe).
    for (final cand in baseFormCandidates(key)) {
      r = _direct(query, cand);
      if (r.found) return r;
    }
    // Multi-word phrase: fall back to the first word.
    if (key.contains(' ')) {
      return lookup(key.split(' ').first);
    }
    return LookupResult(query: query, key: key, entries: const []);
  }

  LookupResult _direct(String query, String key, {String? redirectedFrom, int depth = 0}) {
    var entries = db.entriesByKey(key);
    if (entries.isNotEmpty && entries.first.isRedirect && depth < 3) {
      final target = searchKey(entries.first.redirect!);
      final followed = _direct(query, target, redirectedFrom: entries.first.headword, depth: depth + 1);
      if (followed.found) return followed;
    }
    final quick = db.quickDef(key);
    final family = db.familyOf(key) ?? (entries.isNotEmpty ? db.familyOf(entries.first.headword.toLowerCase()) : null);
    return LookupResult(
      query: query,
      key: key,
      quick: quick,
      entries: entries,
      family: family,
      redirectedFrom: redirectedFrom,
    );
  }
}
