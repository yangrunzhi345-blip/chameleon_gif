import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:gif_forge/domain/entities/export_task.dart';
import 'package:gif_forge/domain/entities/video_info.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';
import 'package:gif_forge/domain/value_objects/task_state.dart';
import 'package:gif_forge/features/converter/infrastructure/process_engine.dart';
import 'package:gif_forge/features/task_queue/application/task_manager.dart';
import 'package:gif_forge/shared/platform/platform_adapter.dart';
import 'package:gif_forge/shared/repositories/in_memory_history_repository.dart';
import 'package:gif_forge/shared/repositories/in_memory_task_repository.dart';
import 'package:gif_forge/features/converter/application/ffmpeg_service_engine.dart';

/// P3 阶段门真实转码冒烟(需桌面环境 + 系统 ffmpeg):
///   flutter test -d linux integration_test/export_smoke_test.dart
///
/// 3 段夹具视频 → 默认参数导出 → completed → 输出存在且为可解码 GIF
/// (GIF8 头),输出目录内无 palette.png 残留(docs/12 P3 阶段门)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const samples = [
    (
      name: 'clip_a(3s 640x360 30fps)',
      path: 'test/fixtures/videos/clip_a.mp4',
      duration: Duration(seconds: 3),
      width: 640,
      height: 360,
    ),
    (
      name: 'clip_b(3s 640x360 25fps 彩条)',
      path: 'test/fixtures/videos/clip_b.mp4',
      duration: Duration(seconds: 3),
      width: 640,
      height: 360,
    ),
    (
      name: 'clip_long(10s 320x240 24fps)',
      path: 'test/fixtures/videos/clip_long.mp4',
      duration: Duration(seconds: 10),
      width: 320,
      height: 240,
    ),
  ];

  test('3 段视频默认参数导出成功且可解码', () async {
    final tempRoot = await Directory.systemTemp.createTemp('gifforge_smoke');
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

    for (final s in samples) {
      final video = VideoInfo(
        path: '${Directory.current.path}/${s.path}',
        formatName: 'mov,mp4',
        duration: s.duration,
        width: s.width,
        height: s.height,
        fps: null,
        codec: 'h264',
      );
      final id = await manager.submit(const GifSetting(), video);

      // 等待完成(最长 60s)
      ExportTask? task;
      for (var i = 0; i < 600; i++) {
        task = await repo.byId(id);
        if (task?.state == TaskState.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(task?.state, TaskState.completed, reason: '导出应成功: ${s.name}');

      final out = File(task!.outputPath!);
      expect(out.existsSync(), isTrue);
      final bytes = await out.readAsBytes();
      expect(bytes.length, greaterThan(100), reason: '输出非空');
      expect(
        String.fromCharCodes(bytes.take(4)),
        'GIF8',
        reason: '输出应为可解码 GIF: ${s.name}',
      );
      // palette 无残留(Service 成功收尾清理)
      final workDir = File(task.outputPath!).parent;
      expect(File('${workDir.path}/palette.png').existsSync(), isFalse);
    }
  });
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}
