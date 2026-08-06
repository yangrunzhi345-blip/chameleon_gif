import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/file_size.dart';
import '../../domain/value_objects/app_theme_mode.dart';
import '../application/camera_settings_controller.dart';
import '../application/captures_storage_controller.dart';
import '../application/record_settings_controller.dart';
import '../application/providers.dart';
import '../application/settings_controller.dart';
import 'batch_parameter_form.dart';
import 'capture_settings_groups.dart';

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

/// 素材存储分组:占用统计 + 清空(二次确认;历史重转对已删素材有预检提示)。
class _CapturesStorageGroup extends ConsumerWidget {
  const _CapturesStorageGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(capturesStorageControllerProvider);
    final controller = ref.read(capturesStorageControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            state.loading
                ? '统计中…'
                : '拍摄/录屏素材 ${state.fileCount} 个,占用 '
                      '${formatFileSize(state.totalBytes)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: state.fileCount == 0
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('清空素材'),
                        content: Text(
                          '将删除全部拍摄/录屏素材文件(共 ${state.fileCount} 个,'
                          '占用 ${formatFileSize(state.totalBytes)})。'
                          '历史记录中的相关转换将无法重转。确定清空?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await controller.clear();
                    }
                  },
            icon: const Icon(Icons.delete_outline),
            label: const Text('清空素材'),
          ),
        ),
      ],
    );
  }
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// 批量参数表单 key(保存前 flush 未回车的文本字段)。
  final _formKey = GlobalKey<BatchParameterFormState>();

  @override
  void initState() {
    super.initState();
    // 延迟到首帧后加载,避免 initState 内触发 Notifier 状态写入
    Future.microtask(() {
      if (!mounted) return;
      ref.read(settingsControllerProvider.notifier).init();
      ref.read(cameraSettingsControllerProvider.notifier).probe();
      ref.read(capturesStorageControllerProvider.notifier).load();
    });
  }

  Future<void> _save() async {
    // 先提交未回车的文本字段(循环/开始/结束);解析失败 → formError 中止
    if (_formKey.currentState?.flushPendingInputs() == false) return;
    await ref.read(settingsControllerProvider.notifier).save();
    await ref.read(cameraSettingsControllerProvider.notifier).save();
    await ref.read(recordSettingsControllerProvider.notifier).save();
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
            BatchParameterForm(
              key: _formKey,
              state: formState,
              actions: controller,
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const SectionLabel('相机'),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '拍摄参数(能力探测失败时仅基础参数;设备支持什么显示什么)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const CameraSettingsGroup(),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const SectionLabel('录屏'),
            const RecordSettingsGroup(),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const SectionLabel('素材存储'),
            _CapturesStorageGroup(),
            const SizedBox(height: 24),
            const Divider(height: 1),
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
