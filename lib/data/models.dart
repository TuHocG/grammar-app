/// Content models, mirroring the JSON shapes documented in docs/05 part B and
/// the SQLite columns in docs/09.
library;

import 'dart:convert';

export 'models_more.dart';

class Seg {
  /// 'pos' | 'm' | 'ex' | 'dom' | 'ref' | 'ipa'
  final String kind;
  final String text;
  final String vi;
  const Seg(this.kind, this.text, [this.vi = '']);

  static List<Seg> listFromJson(String json) {
    final raw = jsonDecode(json) as List;
    return [
      for (final e in raw.cast<Map<String, dynamic>>())
        Seg(e['k'] as String, (e['t'] ?? '') as String, (e['vi'] ?? '') as String),
    ];
  }
}

class QuickDef {
  final String word;
  final String? ipa;
  /// Vietnamese-style respelling shown after the IPA in the old app ("ráp bờ").
  final String? respell;
  final String? pos;
  final String vi;
  const QuickDef({required this.word, this.ipa, this.respell, this.pos, required this.vi});
}

class DictEntry {
  final int id;
  final String headword;
  final String key;
  final String? ipa;
  final List<Seg> segs;
  final QuickDef? quick;
  /// Target headword when the original body is "Xem#target#".
  final String? redirect;
  const DictEntry({
    required this.id,
    required this.headword,
    required this.key,
    this.ipa,
    required this.segs,
    this.quick,
    this.redirect,
  });

  bool get isRedirect => redirect != null && redirect!.isNotEmpty;

  /// First short meaning, for list previews.
  String get preview {
    if (isRedirect) return '→ $redirect';
    for (final s in segs) {
      if (s.kind == 'm') return s.text;
    }
    for (final s in segs) {
      if (s.kind == 'ex') return s.vi;
    }
    return '';
  }
}

class DictHit {
  final int id;
  final String headword;
  final String key;
  final String? ipa;
  final String preview;
  const DictHit(this.id, this.headword, this.key, this.ipa, this.preview);
}

class WordForm {
  final String word;
  final String pos;
  const WordForm(this.word, this.pos);
}

class WordFamily {
  final int id;
  final List<WordForm> members;
  const WordFamily(this.id, this.members);
}

class HelpTopic {
  final int id;
  final String title;
  final String text;
  const HelpTopic(this.id, this.title, this.text);
}

/// A word the user saved (Từ Vựng Của Bạn).
class UserWord {
  final int id;
  final String headword;
  final String key;
  /// User-written meaning; null means "use the dictionary".
  final String? meaning;
  final String? ipa;
  final String? context;
  final String? source;
  final DateTime addedAt;
  final bool marked;
  const UserWord({
    required this.id,
    required this.headword,
    required this.key,
    this.meaning,
    this.ipa,
    this.context,
    this.source,
    required this.addedAt,
    required this.marked,
  });
}

// ---- readings ----------------------------------------------------------------

class ReadingSection {
  final int sid;
  final int? parentSid;
  final String title;
  final int depth;
  final int position;
  final List<ReadingSection> children = [];
  int readingCount = 0;
  ReadingSection({required this.sid, this.parentSid, required this.title, required this.depth, required this.position});

  bool get isLeaf => children.isEmpty;
  int get totalReadings => readingCount + children.fold(0, (a, c) => a + c.totalReadings);
}

class ReadingSummary {
  final int id;
  final int sid;
  final int position;
  final String title;
  final String? img;
  final bool hasAudio;
  const ReadingSummary({required this.id, required this.sid, required this.position, required this.title, this.img, required this.hasAudio});
}

class Sentence {
  final int idx;   // 0-based, continuous across paragraphs
  final int para;
  final String en;
  final String vi;
  const Sentence(this.idx, this.para, this.en, this.vi);
  int get wordCount => en.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
}

class Reading {
  final int id;
  final int sid;
  final int position;
  final String title;
  final String? img;       // relative to dataset/
  final String? audio;     // relative to dataset/
  /// Start time of each sentence, plus a final end mark (seconds). Null when TTS is used.
  final List<double>? times;
  /// The recording reads the title before sentence 0 (plays from 0 to times[0]).
  final bool titleAudio;
  final String? page;
  final List<Sentence> sentences;
  const Reading({
    required this.id,
    required this.sid,
    required this.position,
    required this.title,
    this.img,
    this.audio,
    this.times,
    required this.titleAudio,
    this.page,
    required this.sentences,
  });

  bool get hasRealAudio => audio != null && times != null && times!.length == sentences.length + 1;
  List<List<Sentence>> get paragraphs {
    final out = <List<Sentence>>[];
    for (final s in sentences) {
      if (out.isEmpty || out.last.first.para != s.para) out.add([]);
      out.last.add(s);
    }
    return out;
  }
}

// ---- grammar & exercises ----------------------------------------------------------

class GrammarLesson {
  final int ref;        // 1-based; what every `?n` reference uses
  final String title;
  final bool chapter;   // chapter heading (intro text)
  final bool drills;    // has exercises
  final String body;    // light Markdown (docs/05)
  const GrammarLesson({required this.ref, required this.title, required this.chapter, required this.drills, required this.body});
}

class ExerciseMenu {
  final int idx;
  final String name;
  final int start;
  final int end;   // exclusive
  const ExerciseMenu(this.idx, this.name, this.start, this.end);
  int get count => end - start;
}

class Blank {
  final String answer;
  final List<String> alts;
  final int n;   // width hint (always even: "__" per token)
  const Blank(this.answer, this.alts, this.n);
  List<String> get accepted => [answer, ...alts];
}

class ExplBlock {
  final String head;
  final List<String> lines;
  final List<int> refs;
  const ExplBlock(this.head, this.lines, this.refs);
}

class Exercise {
  final int id;
  final int? menu;
  final int? lessonRef;
  final String g;
  /// 'fill' | 'choice' | 'error' | 'sentences' | 'text'
  final String kind;
  final int? tt;
  final String text;        // with {0}, {1} placeholders for fill/error
  final List<Blank> blanks;
  final List<String> given;
  final List<String> choices;
  final String? answer;     // 'a'..'d' for choice/error
  final String? vi;
  final List<ExplBlock> expl;
  final List<int> refs;
  const Exercise({
    required this.id, this.menu, this.lessonRef, required this.g, required this.kind, this.tt, required this.text,
    required this.blanks, required this.given, required this.choices, this.answer, this.vi, required this.expl, required this.refs,
  });

  bool get isEmpty => text.trim().isEmpty && choices.isEmpty;
  int get answerIndex => answer == null || answer!.isEmpty ? -1 : answer!.toLowerCase().codeUnitAt(0) - 97;
}

class WordformRoot {
  final int position;
  final String root;
  final int start;   // 1-based inside the WORD FORMS menu
  final int count;
  final bool common;
  const WordformRoot(this.position, this.root, this.start, this.count, this.common);
}
