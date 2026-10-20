import 'package:flutter/material.dart';

import 'grammar_app.dart';
import 'theme.dart';

/// The web app's data layer (download into the browser, docs/07 §12) is not written yet: a
/// note instead of the app. [startApp] is referenced so that the web build compiles the whole
/// app (dart2js only compiles what main reaches) and `flutter build web` is a real check.
Future<void> bootstrap() async {
  final _ = startApp;
  runApp(
    MaterialApp(
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Grammar 4.0 trên web đang được xây dựng.\nBản cài đặt: https://github.com/TuHocG/grammar-app/releases', textAlign: TextAlign.center),
          ),
        ),
      ),
    ),
  );
}
