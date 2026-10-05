import 'package:flutter/material.dart';

const seed = Color(0xFF2F6F8F);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
    listTileTheme: const ListTileThemeData(dense: false),
    textTheme: base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
    ),
  );
}

/// Colours with the same meaning as in the old app.
class Marks {
  static const savedWord = Color(0xFFC62828); // từ đã lưu: đỏ
  static const highlight = Color(0xFFFFF59D); // câu đang đọc
}
