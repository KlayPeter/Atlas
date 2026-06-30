import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../reader/application/reading_settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final readingSettings = ref.watch(readingSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(AtlasSpacing.md),
        children: [
          Text('阅读外观', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AtlasSpacing.sm),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto),
                label: Text('系统'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('浅色'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('深色'),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) {
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(selection.first);
            },
          ),
          const SizedBox(height: AtlasSpacing.lg),
          Text('阅读排版', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AtlasSpacing.sm),
          readingSettings.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('读取设置失败：$error'),
            data: (settings) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('字号 ${settings.fontSize.round()}'),
                Slider(
                  value: settings.fontSize,
                  min: 14,
                  max: 24,
                  divisions: 10,
                  onChanged: (value) => ref
                      .read(readingSettingsProvider.notifier)
                      .updateSettings(settings.copyWith(fontSize: value)),
                ),
                Text('行距 ${settings.lineHeight.toStringAsFixed(2)}'),
                Slider(
                  value: settings.lineHeight,
                  min: 1.25,
                  max: 2.1,
                  divisions: 17,
                  onChanged: (value) => ref
                      .read(readingSettingsProvider.notifier)
                      .updateSettings(settings.copyWith(lineHeight: value)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('护眼纸色'),
                  value: settings.eyeCare,
                  onChanged: (value) => ref
                      .read(readingSettingsProvider.notifier)
                      .updateSettings(settings.copyWith(eyeCare: value)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
