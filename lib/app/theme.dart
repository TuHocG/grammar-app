/// Visual system of the app (DESIGN.md: cool-gray canvas, white cards, one violet accent,
/// pill buttons). UI text is Nunito Sans; English content that is *read* (passages, headwords,
/// exercise sentences) is Literata. Two colours keep the meaning they had in the old app:
/// saved words are red, the sentence being read is highlighted (now lilac instead of yellow).
library;

import 'package:flutter/material.dart';

/// Raw design tokens (light theme values; the dark set lives in [GrammarColors.dark]).
abstract final class Tokens {
  static const iris = Color(0xFF4255FF);
  static const irisPressed = Color(0xFF3546E0);
  static const ink = Color(0xFF282E3E);
  static const indigo = Color(0xFF2E3856);
  static const slate = Color(0xFF586380);
  static const fog = Color(0xFF939BB4);
  static const canvas = Color(0xFFF6F7FB);
  static const paper = Color(0xFFFFFFFF);
  static const lilac = Color(0xFFEDEFFF);
  static const mist = Color(0xFFD9DDE8);
  static const savedRed = Color(0xFFB42318);
  static const savedTint = Color(0xFFFDECEB);

  // Pastel fills of the four feature cards on the home page only.
  static const pastelCyan = Color(0xFFCDEEF5);
  static const pastelViolet = Color(0xFFDBDFFF);
  static const pastelPeach = Color(0xFFFFE4CF);
  static const pastelPink = Color(0xFFFFD9E8);

  static const uiFont = 'Nunito Sans';
  static const readingFont = 'Literata';

  /// Glyphs the two families lack (IPA letters, arrows and marks); see pubspec.yaml.
  static const fallbackFonts = ['Noto Sans IPA', 'Noto Sans Symbols'];

  static const radiusInput = 4.0;
  static const radiusCard = 8.0;
  static const radiusFeature = 24.0;
  static const pageMaxWidth = 1200.0;
}

/// Colours that pages read through `context.g` so light and dark stay in one place.
@immutable
class GrammarColors extends ThemeExtension<GrammarColors> {
  final Color canvas;
  final Color card;
  final Color lilac;
  final Color border;
  final Color ink;
  final Color indigo;
  final Color slate;
  final Color fog;
  final Color iris;
  final Color irisPressed;
  final Color savedWord;
  final Color savedTint;
  final Color shadow;

  const GrammarColors({
    required this.canvas,
    required this.card,
    required this.lilac,
    required this.border,
    required this.ink,
    required this.indigo,
    required this.slate,
    required this.fog,
    required this.iris,
    required this.irisPressed,
    required this.savedWord,
    required this.savedTint,
    required this.shadow,
  });

  static const light = GrammarColors(
    canvas: Tokens.canvas,
    card: Tokens.paper,
    lilac: Tokens.lilac,
    border: Tokens.mist,
    ink: Tokens.ink,
    indigo: Tokens.indigo,
    slate: Tokens.slate,
    fog: Tokens.fog,
    iris: Tokens.iris,
    irisPressed: Tokens.irisPressed,
    savedWord: Tokens.savedRed,
    savedTint: Tokens.savedTint,
    shadow: Color(0x1A282E3E),
  );

  static const dark = GrammarColors(
    canvas: Color(0xFF141826),
    card: Color(0xFF1C2134),
    lilac: Color(0xFF262C48),
    border: Color(0xFF2B3147),
    ink: Color(0xFFE6E8F2),
    indigo: Color(0xFFC9CEE0),
    slate: Color(0xFF9AA3BF),
    fog: Color(0xFF6B7390),
    iris: Color(0xFF7C8CFF),
    irisPressed: Color(0xFF93A0FF),
    savedWord: Color(0xFFFF8A80),
    savedTint: Color(0xFF3A2426),
    shadow: Color(0x66000000),
  );

  /// Pastel fill for a feature card; in the dark theme the pastel becomes a quiet tint.
  Color pastel(Color light) => canvas == Tokens.canvas ? light : Color.alphaBlend(light.withValues(alpha: 0.18), card);

  @override
  GrammarColors copyWith() => this;

  @override
  GrammarColors lerp(GrammarColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return GrammarColors(
      canvas: l(canvas, other.canvas),
      card: l(card, other.card),
      lilac: l(lilac, other.lilac),
      border: l(border, other.border),
      ink: l(ink, other.ink),
      indigo: l(indigo, other.indigo),
      slate: l(slate, other.slate),
      fog: l(fog, other.fog),
      iris: l(iris, other.iris),
      irisPressed: l(irisPressed, other.irisPressed),
      savedWord: l(savedWord, other.savedWord),
      savedTint: l(savedTint, other.savedTint),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension GrammarContext on BuildContext {
  GrammarColors get g => Theme.of(this).extension<GrammarColors>() ?? GrammarColors.light;
  bool get isWide => MediaQuery.sizeOf(this).width >= 900;
}

/// Literata styles for English content; sizes follow the design (19 for passages).
abstract final class ReadingStyles {
  static TextStyle passage(BuildContext context) => TextStyle(fontFamily: Tokens.readingFont, fontFamilyFallback: Tokens.fallbackFonts, fontSize: 19, height: 1.75, color: context.g.ink);
  static TextStyle title(BuildContext context) =>
      TextStyle(fontFamily: Tokens.readingFont, fontFamilyFallback: Tokens.fallbackFonts, fontSize: 28, height: 1.3, fontWeight: FontWeight.w600, color: context.g.ink);
  static TextStyle headword(BuildContext context) =>
      TextStyle(fontFamily: Tokens.readingFont, fontFamilyFallback: Tokens.fallbackFonts, fontSize: 36, height: 1.2, fontWeight: FontWeight.w600, color: context.g.ink);
  static TextStyle prompt(BuildContext context) => TextStyle(fontFamily: Tokens.readingFont, fontFamilyFallback: Tokens.fallbackFonts, fontSize: 22, height: 1.5, color: context.g.ink);
  static TextStyle line(BuildContext context) => TextStyle(fontFamily: Tokens.readingFont, fontFamilyFallback: Tokens.fallbackFonts, fontSize: 17, height: 1.5, color: context.g.ink);
  static TextStyle example(BuildContext context) => TextStyle(fontFamily: Tokens.readingFont, fontFamilyFallback: Tokens.fallbackFonts, fontSize: 16, height: 1.5, color: context.g.indigo);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final c = dark ? GrammarColors.dark : GrammarColors.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.iris,
    onPrimary: dark ? c.canvas : Tokens.paper,
    primaryContainer: c.lilac,
    onPrimaryContainer: c.iris,
    secondary: c.slate,
    onSecondary: Tokens.paper,
    secondaryContainer: c.lilac,
    onSecondaryContainer: c.indigo,
    // Warm amber, apart from the violet accent: "show the answer" and similar hint actions.
    tertiary: dark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
    onTertiary: dark ? c.canvas : c.ink,
    tertiaryContainer: dark ? const Color(0xFF3A2E14) : const Color(0xFFFEF3C7),
    onTertiaryContainer: dark ? const Color(0xFFFCD34D) : const Color(0xFF78350F),
    error: c.savedWord,
    onError: Tokens.paper,
    errorContainer: c.savedTint,
    onErrorContainer: c.savedWord,
    surface: c.card,
    onSurface: c.ink,
    surfaceDim: c.canvas,
    surfaceBright: c.card,
    surfaceContainerLowest: c.card,
    surfaceContainerLow: c.canvas,
    surfaceContainer: Color.alphaBlend(c.lilac.withValues(alpha: 0.5), c.canvas),
    surfaceContainerHigh: c.lilac,
    surfaceContainerHighest: Color.alphaBlend(c.border.withValues(alpha: 0.5), c.canvas),
    onSurfaceVariant: c.slate,
    outline: c.fog,
    outlineVariant: c.border,
    shadow: c.shadow,
    scrim: Colors.black54,
    inverseSurface: c.ink,
    onInverseSurface: c.card,
    inversePrimary: c.lilac,
    surfaceTint: Colors.transparent,
  );

  TextStyle ui(double size, {FontWeight weight = FontWeight.w400, double? height, Color? color}) => TextStyle(
    fontFamily: Tokens.uiFont,
    fontFamilyFallback: Tokens.fallbackFonts,
    fontSize: size,
    fontWeight: weight,
    height:
        height ??
        (size >= 32
            ? 1.28
            : size >= 20
            ? 1.4
            : 1.5),
    color: color ?? c.ink,
  );

  final text = TextTheme(
    displayLarge: ui(44, weight: FontWeight.w600),
    displayMedium: ui(40, weight: FontWeight.w600),
    displaySmall: ui(36, weight: FontWeight.w600),
    headlineLarge: ui(32, weight: FontWeight.w600),
    headlineMedium: ui(28, weight: FontWeight.w600),
    headlineSmall: ui(24, weight: FontWeight.w600),
    titleLarge: ui(20, weight: FontWeight.w600),
    titleMedium: ui(16, weight: FontWeight.w600),
    titleSmall: ui(14, weight: FontWeight.w600),
    bodyLarge: ui(16),
    bodyMedium: ui(14),
    bodySmall: ui(12, color: c.slate),
    labelLarge: ui(14, weight: FontWeight.w600),
    labelMedium: ui(12, weight: FontWeight.w600),
    labelSmall: ui(11, weight: FontWeight.w600, color: c.slate),
  );

  const pill = StadiumBorder();
  final pillPadding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Tokens.radiusCard),
    side: BorderSide(color: c.border),
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: Tokens.uiFont, fontFamilyFallback: Tokens.fallbackFonts, textTheme: text);
  return base.copyWith(
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.card,
    dividerColor: c.border,
    splashFactory: InkRipple.splashFactory,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.card,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 56,
      shape: Border(bottom: BorderSide(color: c.border)),
      titleTextStyle: text.titleMedium,
      iconTheme: IconThemeData(color: c.ink, size: 22),
    ),
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: cardShape,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusInput)),
      selectedTileColor: c.lilac,
      selectedColor: c.iris,
      iconColor: c.slate,
      textColor: c.ink,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodyMedium?.copyWith(color: c.slate),
      leadingAndTrailingTextStyle: text.bodySmall,
    ),
    expansionTileTheme: ExpansionTileThemeData(shape: const Border(), collapsedShape: const Border(), iconColor: c.slate, collapsedIconColor: c.slate, textColor: c.ink, collapsedTextColor: c.ink),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: c.ink, size: 20),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.iris,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: c.border,
        disabledForegroundColor: c.fog,
        shape: pill,
        padding: pillPadding,
        minimumSize: const Size(40, 40),
        textStyle: text.labelLarge,
        elevation: 0,
      ).copyWith(overlayColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.08))),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.iris,
        foregroundColor: scheme.onPrimary,
        shape: pill,
        padding: pillPadding,
        minimumSize: const Size(40, 40),
        textStyle: text.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        backgroundColor: c.card,
        disabledForegroundColor: c.fog,
        side: BorderSide(color: c.border),
        shape: pill,
        padding: pillPadding,
        minimumSize: const Size(40, 40),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.iris, shape: pill, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), minimumSize: const Size(40, 40), textStyle: text.labelLarge),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: c.ink, highlightColor: c.lilac),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: c.iris, foregroundColor: scheme.onPrimary, elevation: 2, shape: pill, extendedTextStyle: text.labelLarge),
    chipTheme: ChipThemeData(
      backgroundColor: c.card,
      selectedColor: c.lilac,
      secondarySelectedColor: c.lilac,
      disabledColor: c.canvas,
      side: BorderSide(color: c.border),
      shape: pill,
      labelStyle: text.bodyMedium?.copyWith(color: c.ink),
      secondaryLabelStyle: text.bodyMedium?.copyWith(color: c.iris, fontWeight: FontWeight.w600),
      iconTheme: IconThemeData(color: c.slate, size: 16),
      checkmarkColor: c.iris,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? c.canvas : c.canvas,
      hintStyle: text.bodyLarge?.copyWith(color: c.fog),
      labelStyle: text.bodyMedium?.copyWith(color: c.slate),
      helperStyle: text.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusInput),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusInput),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusInput),
        borderSide: BorderSide(color: c.iris, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusInput),
        borderSide: BorderSide(color: c.border.withValues(alpha: 0.6)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: c.card,
        foregroundColor: c.ink,
        selectedBackgroundColor: c.lilac,
        selectedForegroundColor: c.iris,
        side: BorderSide(color: c.border),
        textStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(dark ? c.ink : Tokens.paper),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.iris : c.border),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: c.iris, inactiveTrackColor: c.border, thumbColor: c.iris, overlayColor: c.iris.withValues(alpha: 0.12), valueIndicatorColor: c.ink),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.iris, linearTrackColor: c.border, linearMinHeight: 6, borderRadius: BorderRadius.circular(3)),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.iris : Colors.transparent),
      side: BorderSide(color: c.fog, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.iris : c.fog)),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: c.border,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.radiusFeature))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.card, surfaceTintColor: Colors.transparent, shape: cardShape, titleTextStyle: text.titleLarge, contentTextStyle: text.bodyLarge),
    popupMenuTheme: PopupMenuThemeData(color: c.card, surfaceTintColor: Colors.transparent, shape: cardShape, textStyle: text.bodyMedium, elevation: 4, shadowColor: c.shadow),
    menuTheme: MenuThemeData(
      style: MenuStyle(backgroundColor: WidgetStatePropertyAll(c.card), shape: WidgetStatePropertyAll(cardShape)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.card),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusCard)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(Tokens.radiusInput)),
      textStyle: text.bodySmall?.copyWith(color: c.card),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      indicatorColor: c.lilac,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => text.labelSmall!.copyWith(color: s.contains(WidgetState.selected) ? c.iris : c.slate)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.iris : c.slate, size: 22)),
    ),
    tabBarTheme: TabBarThemeData(labelColor: c.iris, unselectedLabelColor: c.slate, indicatorColor: c.iris, dividerColor: c.border, labelStyle: text.labelLarge, unselectedLabelStyle: text.bodyMedium),
    badgeTheme: BadgeThemeData(backgroundColor: c.iris, textColor: scheme.onPrimary),
  );
}

/// Colours with the same meaning as in the old app (kept for the pages that import them).
class Marks {
  static const savedWord = Tokens.savedRed; // từ đã lưu: đỏ
  static const highlight = Tokens.lilac; // câu đang đọc
}
