/// User state for Luyện Nói picks (old DataSpChon), picture-vocabulary picks
/// (old dataHH.xy `Chon` byte) and bookmarked grammar lessons (Ngữ Pháp Của Bạn).
library;

import 'user_db.dart';

extension UserDbMore on UserDb {
  /// Grammar lessons the user bookmarked (lesson refs).
  Set<int> grammarMarks() => {for (final r in raw.select('SELECT ref FROM user_grammar_mark')) r['ref'] as int};

  void setGrammarMark(int ref, bool marked) => marked
      ? raw.execute('INSERT OR IGNORE INTO user_grammar_mark(ref, added_at) VALUES (?, ?)', [ref, DateTime.now().millisecondsSinceEpoch])
      : raw.execute('DELETE FROM user_grammar_mark WHERE ref = ?', [ref]);

  /// (dialogId, pairIdx) picked among the given dialogs, in pick order.
  List<(int, int)> dialogPicks(List<int> dialogIds) {
    if (dialogIds.isEmpty) return const [];
    final q = List.filled(dialogIds.length, '?').join(',');
    return [for (final r in raw.select('SELECT dialog_id, pair_idx FROM user_dialog_pick WHERE dialog_id IN ($q) ORDER BY ord', dialogIds)) (r['dialog_id'] as int, r['pair_idx'] as int)];
  }

  Set<String> dialogPickKeys() => {for (final r in raw.select('SELECT dialog_id, pair_idx FROM user_dialog_pick')) '${r['dialog_id']}:${r['pair_idx']}'};

  void setDialogPick(int dialogId, int pairIdx, bool picked) {
    if (picked) {
      final maxOrd = raw.select('SELECT COALESCE(MAX(ord), 0) AS m FROM user_dialog_pick').first['m'] as int;
      raw.execute('INSERT OR IGNORE INTO user_dialog_pick(dialog_id, pair_idx, ord) VALUES (?, ?, ?)', [dialogId, pairIdx, maxOrd + 1]);
    } else {
      raw.execute('DELETE FROM user_dialog_pick WHERE dialog_id = ? AND pair_idx = ?', [dialogId, pairIdx]);
    }
  }

  Set<int> picturePicks(int topicId) => {
    for (final r in raw.select('SELECT word_idx FROM user_picture_pick WHERE topic_id = ?', [topicId])) r['word_idx'] as int,
  };

  Set<int> pictureTopicsWithPicks() => {for (final r in raw.select('SELECT DISTINCT topic_id FROM user_picture_pick')) r['topic_id'] as int};

  void setPicturePick(int topicId, int wordIdx, bool picked) {
    if (picked) {
      raw.execute('INSERT OR IGNORE INTO user_picture_pick(topic_id, word_idx) VALUES (?, ?)', [topicId, wordIdx]);
    } else {
      raw.execute('DELETE FROM user_picture_pick WHERE topic_id = ? AND word_idx = ?', [topicId, wordIdx]);
    }
  }
}
