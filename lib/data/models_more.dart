/// Models for dialogs, listening, video subtitles, sentence analysis and picture vocabulary.
library;

class DialogTopic {
  final int sid;
  final String title;
  final int position;
  const DialogTopic(this.sid, this.title, this.position);
}

class DialogPair {
  final String a;
  final String b;
  final String avi;
  final String bvi;
  const DialogPair(this.a, this.b, this.avi, this.bvi);
}

class Dialog {
  final int id;
  final int sid;
  final int position;
  final String title;
  final List<DialogPair> pairs;
  const Dialog({required this.id, required this.sid, required this.position, required this.title, required this.pairs});
}

class ListeningItem {
  final int id;
  final int unit;
  final int n;
  final String en;
  final String correct;
  final List<String> options; // options[0] == correct
  const ListeningItem({required this.id, required this.unit, required this.n, required this.en, required this.correct, required this.options});
}

class SubtitleFilm {
  final int id;
  final String code; // "A 1"
  final String group;
  final String title;
  final String? firstLine;
  final String video; // old app's AVI name "A  1.avi"
  final double duration;
  final int lines;
  const SubtitleFilm({required this.id, required this.code, required this.group, required this.title, this.firstLine, required this.video, required this.duration, required this.lines});

  /// File name used by this app: "A 01.mp4" (tools/video/transcode.py).
  String get mp4Name {
    final parts = code.split(' ');
    return '${parts[0]} ${int.parse(parts[1]).toString().padLeft(2, '0')}.mp4';
  }
}

class SubtitleLine {
  final int idx;
  final double s;
  final double e;
  final String en;
  final String vi;
  const SubtitleLine(this.idx, this.s, this.e, this.en, this.vi);
}

class AnalysisWord {
  final String n;
  final String word;
  final String pos;
  final String position;
  final String function;
  final String meaning;
  final String note;
  final List<int> refs;
  const AnalysisWord({required this.n, required this.word, required this.pos, required this.position, required this.function, required this.meaning, required this.note, required this.refs});
}

class PictureWord {
  final String en;
  final String vi;
  final int? x;
  final int? y;
  const PictureWord(this.en, this.vi, this.x, this.y);
  bool get hasSpot => x != null && y != null;
}

class PictureTopic {
  final int id;
  final String title;
  final int first;
  final List<PictureWord> words;
  final String? page;
  const PictureTopic({required this.id, required this.title, required this.first, required this.words, this.page});
}
