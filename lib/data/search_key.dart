/// Normalisation used for dictionary lookup. Mirrors `search_key` in tools/etl
/// (etl/parsers/common.py): lower-case, strip accents, collapse whitespace.
library;

import 'irregular_verbs.dart';

const _accentMap = <String, String>{
  'à': 'a',
  'á': 'a',
  'ả': 'a',
  'ã': 'a',
  'ạ': 'a',
  'ă': 'a',
  'ằ': 'a',
  'ắ': 'a',
  'ẳ': 'a',
  'ẵ': 'a',
  'ặ': 'a',
  'â': 'a',
  'ầ': 'a',
  'ấ': 'a',
  'ẩ': 'a',
  'ẫ': 'a',
  'ậ': 'a',
  'è': 'e',
  'é': 'e',
  'ẻ': 'e',
  'ẽ': 'e',
  'ẹ': 'e',
  'ê': 'e',
  'ề': 'e',
  'ế': 'e',
  'ể': 'e',
  'ễ': 'e',
  'ệ': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'ỉ': 'i',
  'ĩ': 'i',
  'ị': 'i',
  'ï': 'i',
  'î': 'i',
  'ò': 'o',
  'ó': 'o',
  'ỏ': 'o',
  'õ': 'o',
  'ọ': 'o',
  'ô': 'o',
  'ồ': 'o',
  'ố': 'o',
  'ổ': 'o',
  'ỗ': 'o',
  'ộ': 'o',
  'ơ': 'o',
  'ờ': 'o',
  'ớ': 'o',
  'ở': 'o',
  'ỡ': 'o',
  'ợ': 'o',
  'ö': 'o',
  'ù': 'u',
  'ú': 'u',
  'ủ': 'u',
  'ũ': 'u',
  'ụ': 'u',
  'ư': 'u',
  'ừ': 'u',
  'ứ': 'u',
  'ử': 'u',
  'ữ': 'u',
  'ự': 'u',
  'ü': 'u',
  'û': 'u',
  'ỳ': 'y',
  'ý': 'y',
  'ỷ': 'y',
  'ỹ': 'y',
  'ỵ': 'y',
  'đ': 'd',
  'ç': 'c',
  'ñ': 'n',
  'ß': 'ss',
  'æ': 'ae',
  'œ': 'oe',
  '’': "'",
  '‘': "'",
  '`': "'",
};

final _ws = RegExp(r'\s+');

String searchKey(String text) {
  final sb = StringBuffer();
  for (final r in text.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    sb.write(_accentMap[ch] ?? ch);
  }
  return sb.toString().replaceAll(_ws, ' ').trim();
}

/// Strip surrounding punctuation from a tapped token ("ball." -> "ball").
String cleanToken(String token) {
  var t = token.trim();
  t = t.replaceAll(RegExp(r"""^[^A-Za-z0-9À-ɏḀ-ỿ']+"""), '');
  t = t.replaceAll(RegExp(r"""[^A-Za-z0-9À-ɏḀ-ỿ']+$"""), '');
  return t;
}

/// Candidate base forms for an inflected English word, in the order the old app
/// tried them (Doi_ed_ing_TuDien.bas): irregular past forms (came -> come), then
/// -s/-es/-ies, -ed/-ied/-d, -ing, doubled consonant.
List<String> baseFormCandidates(String key) {
  final out = <String>[];
  void add(String s) {
    if (s.length >= 2 && !out.contains(s) && s != key) out.add(s);
  }

  final irr = irregularBase[key];
  if (irr != null) add(irr);
  if (key.endsWith('ies')) add('${key.substring(0, key.length - 3)}y');
  if (key.endsWith('es')) add(key.substring(0, key.length - 2));
  if (key.endsWith('s')) add(key.substring(0, key.length - 1));
  if (key.endsWith('ied')) add('${key.substring(0, key.length - 3)}y');
  if (key.endsWith('ed')) {
    final stem = key.substring(0, key.length - 2);
    add(stem);
    add('${stem}e');
    if (stem.length >= 2 && stem[stem.length - 1] == stem[stem.length - 2]) {
      add(stem.substring(0, stem.length - 1));
    }
  }
  if (key.endsWith('d')) add(key.substring(0, key.length - 1));
  if (key.endsWith('ing')) {
    final stem = key.substring(0, key.length - 3);
    add(stem);
    add('${stem}e');
    if (stem.length >= 2 && stem[stem.length - 1] == stem[stem.length - 2]) {
      add(stem.substring(0, stem.length - 1));
    }
  }
  if (key.endsWith('er')) add(key.substring(0, key.length - 2));
  if (key.endsWith('est')) add(key.substring(0, key.length - 3));
  return out;
}
