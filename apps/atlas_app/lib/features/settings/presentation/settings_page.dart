import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../reader/application/reading_settings_controller.dart';
import '../application/ai_settings_controller.dart';

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
          const SizedBox(height: AtlasSpacing.lg),
          const Divider(),
          const SizedBox(height: AtlasSpacing.md),
          Text('AI 模型', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AtlasSpacing.sm),
          const _AiSettingsSection(),
        ],
      ),
    );
  }
}

class _AiSettingsSection extends ConsumerStatefulWidget {
  const _AiSettingsSection();

  @override
  ConsumerState<_AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends ConsumerState<_AiSettingsSection> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelNameController;

  AiSettings? _initialSettings;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _baseUrlController = TextEditingController();
    _modelNameController = TextEditingController();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelNameController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    try {
      await ref
          .read(aiSettingsProvider.notifier)
          .updateSettings(
            AiSettings(
              apiKey: _apiKeyController.text.trim(),
              baseUrl: _baseUrlController.text.trim(),
              modelName: _modelNameController.text.trim(),
            ),
          );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存 AI 配置')));
  }

  @override
  Widget build(BuildContext context) {
    final aiSettingsState = ref.watch(aiSettingsProvider);

    return aiSettingsState.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('加载配置失败：$e'),
      data: (settings) {
        if (_initialSettings != settings) {
          _initialSettings = settings;
          _apiKeyController.text = settings.apiKey;
          _baseUrlController.text = settings.baseUrl;
          _modelNameController.text = settings.modelName;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atlas 不运营 AI 服务。填写你自己的模型信息后，文档片段会直接发送给该模型服务商。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AtlasSpacing.md),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key（你的模型服务商）',
                hintText: 'sk-...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: AtlasSpacing.sm),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL (兼容 OpenAI 接口规范)',
                hintText: '例如 https://api.example.com/v1',
                helperText: '仅支持 OpenAI 兼容接口；非本机地址必须使用 HTTPS。',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AtlasSpacing.sm),
            TextField(
              controller: _modelNameController,
              decoration: const InputDecoration(
                labelText: '模型名称 (Model Name)',
                hintText: '如 deepseek-chat',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AtlasSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saveSettings,
                child: const Text('保存配置'),
              ),
            ),
          ],
        );
      },
    );
  }
}
