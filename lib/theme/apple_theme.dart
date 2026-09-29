import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 依 Apple Human Interface Guidelines 調整的主題：
/// - 系統藍當強調色，內容區用分組背景（淺灰）＋白色圓角卡片
/// - 標題粗、內文 17pt、字距緊；間距以 8pt 為單位
/// - 細分隔線、無陰影、圓角 12
class AppleTheme {
  AppleTheme._();

  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemRed = Color(0xFFFF3B30);
  static const Color systemGreen = Color(0xFF34C759);

  // Light
  static const Color groupedBg = Color(0xFFF2F2F7);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color label = Color(0xFF000000);
  static const Color secondaryLabel = Color(0x993C3C43);
  static const Color tertiaryLabel = Color(0x4D3C3C43);
  static const Color separator = Color(0x4A3C3C43);
  static const Color fillTertiary = Color(0x1E767680);

  // Dark
  static const Color groupedBgDark = Color(0xFF000000);
  static const Color cardBgDark = Color(0xFF1C1C1E);
  static const Color labelDark = Color(0xFFFFFFFF);
  static const Color secondaryLabelDark = Color(0x99EBEBF5);
  static const Color tertiaryLabelDark = Color(0x4DEBEBF5);
  static const Color separatorDark = Color(0xA6545458);
  static const Color fillTertiaryDark = Color(0x3D767680);

  static const double radius = 12;

  /// [fontFamily] 預設不指定，讓平台使用系統字型（iOS 為 SF Pro）。
  static ThemeData light({String? fontFamily}) => _build(Brightness.light, fontFamily);
  static ThemeData dark({String? fontFamily}) => _build(Brightness.dark, fontFamily);

  static ThemeData _build(Brightness b, String? fontFamily) {
    final isDark = b == Brightness.dark;
    final bg = isDark ? groupedBgDark : groupedBg;
    final card = isDark ? cardBgDark : cardBg;
    final fg = isDark ? labelDark : label;
    final fg2 = isDark ? secondaryLabelDark : secondaryLabel;
    final sep = isDark ? separatorDark : separator;
    final fill = isDark ? fillTertiaryDark : fillTertiary;

    final scheme = ColorScheme.fromSeed(
      seedColor: systemBlue,
      brightness: b,
      primary: systemBlue,
      onPrimary: Colors.white,
      surface: bg,
      onSurface: fg,
      error: systemRed,
      outline: sep,
      outlineVariant: sep,
      surfaceContainerLowest: card,
      surfaceContainerLow: card,
      surfaceContainer: card,
      surfaceContainerHigh: card,
      surfaceContainerHighest: fill,
      onSurfaceVariant: fg2,
    );

    // iOS 文字層級（pt）：Large Title 34 / Title1 28 / Title2 22 / Title3 20 /
    // Headline 17 semibold / Body 17 / Callout 16 / Subhead 15 / Footnote 13 / Caption 12
    // iOS 文字層級（pt）。字級、字距、行距一起設定：大字負字距、緊行距；小字近零字距、鬆行距。
    TextStyle t(double size, FontWeight w, double tracking, double lineHeight, Color color) => TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: w,
          letterSpacing: tracking,
          height: lineHeight / size,
          color: color,
        );
    final text = TextTheme(
      displayLarge: t(34, FontWeight.w700, -0.4, 41, fg),   // Large Title
      headlineLarge: t(28, FontWeight.w700, -0.3, 34, fg),  // Title 1
      headlineMedium: t(22, FontWeight.w700, -0.2, 28, fg), // Title 2
      headlineSmall: t(22, FontWeight.w700, -0.2, 28, fg),
      titleLarge: t(20, FontWeight.w600, -0.1, 25, fg),     // Title 3
      titleMedium: t(17, FontWeight.w600, -0.2, 22, fg),    // Headline
      titleSmall: t(15, FontWeight.w600, -0.1, 20, fg),     // Subheadline (semibold)
      bodyLarge: t(17, FontWeight.w400, -0.2, 22, fg),      // Body
      bodyMedium: t(15, FontWeight.w400, -0.1, 20, fg),     // Subheadline
      bodySmall: t(13, FontWeight.w400, 0, 18, fg2),        // Footnote
      labelLarge: t(17, FontWeight.w600, -0.2, 22, fg),
      labelMedium: t(13, FontWeight.w500, 0, 18, fg2),
      labelSmall: t(12, FontWeight.w400, 0.1, 16, fg2),     // Caption
    );

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: text,
      typography: Typography.material2021(platform: TargetPlatform.iOS),
      splashFactory: NoSplash.splashFactory,
      highlightColor: fill,
      dividerColor: sep,
      dividerTheme: DividerThemeData(color: sep, thickness: 0.5, space: 0.5),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleMedium,
        iconTheme: const IconThemeData(color: systemBlue),
        actionsIconTheme: const IconThemeData(color: systemBlue),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: card,
        iconColor: systemBlue,
        textColor: fg,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: systemBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: systemBlue,
          textStyle: text.bodyLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: systemBlue,
          minimumSize: const Size.fromHeight(50),
          shape: shape,
          side: BorderSide(color: sep),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: systemBlue, width: 1.5),
        ),
        hintStyle: text.bodyLarge?.copyWith(color: isDark ? tertiaryLabelDark : tertiaryLabel),
        labelStyle: text.bodyMedium?.copyWith(color: fg2),
        helperStyle: text.bodySmall,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fill,
        selectedColor: systemBlue.withValues(alpha: 0.15),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium?.copyWith(color: fg),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape,
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(backgroundColor: card, shape: shape),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: systemBlue),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: card,
        collapsedBackgroundColor: card,
        iconColor: fg2,
        collapsedIconColor: fg2,
        textColor: fg,
        collapsedTextColor: fg,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: b,
        primaryColor: systemBlue,
        scaffoldBackgroundColor: bg,
        barBackgroundColor: card,
      ),
    );
  }
}
