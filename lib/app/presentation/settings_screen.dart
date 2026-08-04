import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/app_theme_mode.dart';
import '../application/providers.dart';
import '../application/settings_controller.dart';
import 'batch_parameter_form.dart';

/// 设置界面(app 层组合壳):外观(主题切换)+ 批量导入默认参数。
///
/// 主题三态经 [themeModeProvider] 持久化(从首页迁移至此);批量默认
/// 参数经 [SettingsController](BatchFormMixin 承载表单逻辑)编辑,
/// 保存写回 defaultGifSetting + defaultExportDir,批量导入设置页
/// init 时读取。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 延迟到首帧后加载,避免 initState 内触发 Notifier 状态写入
    Future.microtask(() {
      if (!mounted) return;
      ref.read(settingsControllerProvider.notifier).init();
    });
  }

  Future<void> _save() async {
    await ref.read(settingsControllerProvider.notifier).save();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('设置已保存')));
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('外观'),
            SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('浅色'),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('深色'),
                ),
                ButtonSegment(
                  value: AppThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('跟随系统'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(selection.first);
              },
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const SectionLabel('批量导入默认参数'),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '保存后,批量导入将默认使用以下参数',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            BatchParameterForm(state: formState, actions: controller),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: formState.formError != null ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存设置'),
            ),
          ],
        ),
      ),
    );
  }
}
