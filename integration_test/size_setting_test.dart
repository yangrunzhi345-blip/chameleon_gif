import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/features/converter/application/ffmpeg_service_engine.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/platform/process_engine.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';

/// 宽高设置端到端验证(真实 ffmpeg,需桌面环境):
///   flutter test -d linux integration_test/size_setting_test.dart
///
/// 4 种组合断言输出 GIF 的实际像素尺寸(ffprobe 读回):
/// - 默认(宽高都 0)→ 源尺寸
/// - 宽 480(高 0)→ 480 × 等比
/// - 高 270(宽 0)→ 等比 × 270
/// - 宽 480 + 高 300 → 精确 480×300(允许变形)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 源:640×360,3s(快转码)
  const clipPath = 'test/fixtures/videos/clip_a.mp4';
  const video = VideoInfo(
    path: '',
    formatName: 'mp4',
    duration: Duration(seconds: 3),
    width: 640,
    height: 360,
    fps: 30,
    codec: 'h264',
  );

  Future<({int width, int height})> gifSize(String path) async {
    final result = await Process.run('ffprobe', [
      '-v',
      'error',
      '-select_streams',
      'v:0',
      '-show_entries',
      'stream=width,height',
      '-of',
      'json',
      path,
    ]);
    final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final stream = (json['streams'] as List).first as Map<String, dynamic>;
    return (width: stream['width'] as int, height: stream['height'] as int);
  }

  test('宽高 4 组合输出尺寸正确', () async {
    final tempRoot = await Directory.systemTemp.createTemp('gifforge_size_');
    addTearDown(() => tempRoot.delete(recursive: true));
    final repo = InMemoryTaskRepository();
    final manager = TaskManager(
      taskRepository: repo,
      historyRepository: InMemoryHistoryRepository(),
      ffmpegService: FfmpegServiceEngine(
        engine: const ProcessEngine(),
        logger: AppLogger(),
      ),
      platformAdapter: _TestAdapter(tempRoot.path),
      logger: AppLogger(),
    );

    const cases = [
      (setting: GifSetting(), expectW: 640, expectH: 360, name: '默认(原图)'),
      (
        setting: GifSetting(width: 480),
        expectW: 480,
        expectH: 270,
        name: '宽 480 等比',
      ),
      (
        setting: GifSetting(height: 270),
        expectW: 480,
        expectH: 270,
        name: '高 270 等比',
      ),
      (
        setting: GifSetting(width: 480, height: 300),
        expectW: 480,
        expectH: 300,
        name: '宽 480 高 300(精确)',
      ),
    ];

    for (final c in cases) {
      final input = '${Directory.current.path}/$clipPath';
      final id = await manager.submit(c.setting, video.copyWith(path: input));
      for (var i = 0; i < 600; i++) {
        final t = await repo.byId(id);
        if (t?.state == TaskState.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final task = await repo.byId(id);
      expect(task?.state, TaskState.completed, reason: '${c.name} 应转换成功');

      final size = await gifSize(task!.outputPath!);
      expect(size.width, c.expectW, reason: '${c.name}:输出宽度');
      expect(size.height, c.expectH, reason: '${c.name}:输出高度');
      // ignore: avoid_print
      print('✅ ${c.name}: 输出 ${size.width}×${size.height}');
    }
  });
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}
