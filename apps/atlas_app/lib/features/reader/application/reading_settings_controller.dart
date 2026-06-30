import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_theme.dart';

final readingSettingsProvider =
    AsyncNotifierProvider<ReadingSettingsController, ReadingSettings>(
      ReadingSettingsController.new,
    );

class ReadingSettings {
  const ReadingSettings({
    this.fontSize = 17,
    this.lineHeight = 1.65,
    this.pagePadding = AtlasSpacing.lg,
    this.eyeCare = false,
  });

  final double fontSize;
  final double lineHeight;
  final double pagePadding;
  final bool eyeCare;

  ReadingSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? pagePadding,
    bool? eyeCare,
  }) {
    return ReadingSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      pagePadding: pagePadding ?? this.pagePadding,
      eyeCare: eyeCare ?? this.eyeCare,
    );
  }

  TextStyle bodyStyle(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.bodyLarge!.copyWith(fontSize: fontSize, height: lineHeight);
  }
}

class ReadingSettingsController extends AsyncNotifier<ReadingSettings> {
  static const _fontSizeKey = 'atlas.settings.fontSize';
  static const _lineHeightKey = 'atlas.settings.lineHeight';
  static const _pagePaddingKey = 'atlas.settings.pagePadding';
  static const _eyeCareKey = 'atlas.settings.eyeCare';

  @override
  Future<ReadingSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return ReadingSettings(
      fontSize: prefs.getDouble(_fontSizeKey) ?? 17,
      lineHeight: prefs.getDouble(_lineHeightKey) ?? 1.65,
      pagePadding: prefs.getDouble(_pagePaddingKey) ?? AtlasSpacing.lg,
      eyeCare: prefs.getBool(_eyeCareKey) ?? false,
    );
  }

  Future<void> updateSettings(ReadingSettings settings) async {
    state = AsyncData(settings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, settings.fontSize);
    await prefs.setDouble(_lineHeightKey, settings.lineHeight);
    await prefs.setDouble(_pagePaddingKey, settings.pagePadding);
    await prefs.setBool(_eyeCareKey, settings.eyeCare);
  }
}
