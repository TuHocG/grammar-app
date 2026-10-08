// Phone layouts: 360 dp wide (the narrowest phones in use) at the normal text size and at 130 %
// (Cài Đặt → Cỡ chữ, or a large system font). Measured with the app's own fonts, loaded once
// here: the test default, Ahem, draws every letter as a wide square.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar/app/providers.dart';
import 'package:grammar/app/theme.dart';
import 'package:grammar/data/content_db.dart';
import 'package:grammar/data/user_db.dart';
import 'package:grammar/platform/tts.dart';
import 'package:grammar/ui/pictures/picture_pages.dart';
import 'package:grammar/ui/video/video_pages.dart';

const phoneWidth = 360.0;
const textScales = [1.0, 1.3];

Future<void> loadAppFonts() async {
  for (final (family, files) in [
    ('Nunito Sans', ['NunitoSans-Regular', 'NunitoSans-SemiBold', 'NunitoSans-Bold']),
    ('Literata', ['Literata-Regular', 'Literata-SemiBold']),
  ]) {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f.ttf'));
    }
    await loader.load();
  }
}

void main() {
  final dir = Platform.environment['GRAMMAR_DATA_DIR'] ?? 'content';
  final has = File('$dir/grammar.db').existsSync();
  late ContentDb db;
  late UserDb user;
  late Directory tmp;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
    if (!has) return;
    db = ContentDb.open(dir);
    tmp = Directory.systemTemp.createTempSync('grammar_phone');
    user = UserDb.open('${tmp.path}/user.db');
  });
  tearDownAll(() {
    if (!has) return;
    db.close();
    user.close();
    tmp.deleteSync(recursive: true);
  });

  Widget app(Widget child, double scale) => MaterialApp(
        theme: buildTheme(Brightness.light),
        builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: c!),
        home: child,
      );

  Widget wrap(Widget child, double scale) => ProviderScope(
        overrides: [
          contentDbProvider.overrideWithValue(db),
          userDbProvider.overrideWithValue(user),
          ttsProvider.overrideWithValue(TtsService()),
        ],
        child: app(child, scale),
      );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(phoneWidth, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  for (final scale in textScales) {
    final pct = '${(scale * 100).round()} %';

    for (final (name, build) in <(String, Widget Function())>[
      ('Từ Vựng Tranh', () => const PictureTopicPage(id: 1)),
    ]) {
      testWidgets('$name page fits a phone at $pct text', (tester) async {
        phone(tester);
        await tester.pumpWidget(wrap(build(), scale));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());   // dispose (stops the Đàm thoại timer)
      }, skip: !has);
    }

    testWidgets('video control bar fits a phone at $pct text', (tester) async {
      phone(tester);
      void none() {}
      await tester.pumpWidget(app(
        Scaffold(
          bottomNavigationBar: VideoControlBar(position: 'Câu 1/494', playing: false, loop: 0, onPrev: none, onReplay: none, onPlayPause: none, onNext: none, onLoop: (_) {}),
        ),
        scale,
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Số câu lặp'), findsOneWidget);
    });
  }
}
