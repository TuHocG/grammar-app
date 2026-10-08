// Cài Đặt → Dữ liệu summaries against the real content (skipped when the data is absent).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/app/providers.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/media_locations.dart';
import 'package:grammar/data/user_db.dart';
import 'package:grammar/platform/tts.dart';
import 'package:grammar/ui/settings/content_sources.dart';

void main() {
  final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
  final has = File('$dir/grammar.db').existsSync();
  final audio = Platform.environment['GRAMMAR_AUDIO_DIR'] ?? r'D:\code\personal\grammar\dist\dataset\audio';
  final video = Platform.environment['GRAMMAR_VIDEO_DIR'] ?? r'D:\english\grammar 3.1\mp4';
  final hasMedia = Directory(audio).existsSync() && Directory(video).existsSync();

  test('summaries count recordings and episodes found in the chosen folders', () {
    final db = ContentDb.open(dir);
    final a = audioSummary(db, audio);
    expect(a.expected, 119);
    expect(a.found, 119);
    final v = videoSummary(db, video);
    expect(v.expected, 210);
    expect(v.found, 210);
    final missing = audioSummary(db, r'Z:\nowhere');
    expect(missing.exists, isFalse);
    expect(missing.found, 0);
    db.close();
  }, skip: !(has && hasMedia));

  testWidgets('section shows version, recordings and videos', (tester) async {
    final db = ContentDb.open(dir);
    final tmp = Directory.systemTemp.createTempSync('grammar_cs');
    final user = UserDb.open('${tmp.path}/user.db')
      ..setSetting(audioDirKey, audio)
      ..setSetting(videoDirKey, video);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        contentDbProvider.overrideWithValue(db),
        userDbProvider.overrideWithValue(user),
        ttsProvider.overrideWithValue(TtsService()),
      ],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ContentSourcesSection()))),
    ));
    await tester.runAsync(() async => tester.pump());   // summaries run after the first frame
    await tester.pump();
    if (db.contentVersion != null) expect(find.textContaining('phiên bản ${db.contentVersion}'), findsOneWidget);
    expect(find.textContaining('119/119 bài có file ghi âm'), findsOneWidget);
    expect(find.textContaining('210/210 tập có file'), findsOneWidget);
    expect(find.text('Chọn thư mục dữ liệu…'), findsOneWidget);
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  }, skip: !(has && hasMedia));
}
