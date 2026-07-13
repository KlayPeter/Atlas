import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

class AtlasTheme {
  const AtlasTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF375E5A),
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6FA69E),
      brightness: Brightness.dark,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );
    final sansTheme = base.textTheme.apply(
      fontFamily: 'Noto Sans CJK SC',
      fontFamilyFallback: const [
        'PingFang SC',
        'Microsoft YaHei',
        'sans-serif',
      ],
    );
    final textTheme = sansTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontFamily: 'Noto Serif CJK SC',
        fontFamilyFallback: const ['Songti SC', 'STSong', 'serif'],
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontFamily: 'Noto Serif CJK SC',
        fontFamilyFallback: const ['Songti SC', 'STSong', 'serif'],
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontFamily: 'Noto Serif CJK SC',
        fontFamilyFallback: const ['Songti SC', 'STSong', 'serif'],
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontFamily: 'Noto Serif CJK SC',
        fontFamilyFallback: const ['Songti SC', 'STSong', 'serif'],
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarThemeData(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

class AtlasSpacing {
  const AtlasSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}
