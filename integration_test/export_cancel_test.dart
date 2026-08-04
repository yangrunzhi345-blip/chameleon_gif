import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:gif_forge/domain/entities/export_task.dart';
import 'package:gif_forge/domain/entities/video_info.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';
import 'package:gif_forge/domain/value_objects/task_state.dart';
import 'package:gif_forge/features/converter/application/ffmpeg_service_engine.dart';
import 'package:gif_forge/shared/platform/process_engine.dart';
import 'package:gif_forge/features/task_queue/application/task_manager.dart';
import 'package:gif_forge/shared/platform/platform_adapter.dart';
import 'package:gif_forge/shared/repositories/in_memory_history_repository.dart';
import 'package:gif_forge/shared/repositories/in_memory_task_repository.dart';

/// P3 阶段门取消链路冒烟(需桌面环境 + 系统 ffmpeg):
///   flutter test -d linux integration_test/export_cancel_test.dart
///
/// 长视频导出中取消 → 任务 cancelled → 临时目录无残留(docs/12 P3 阶段门)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('导出中取消 → cancelled,临时目录无残留', () async {
    final tempRoot = await Directory.systemTemp.createTemp('gifforge_cancel');
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

    final video = VideoInfo(
      path: '${Directory.current.path}/test/fixtures/videos/clip_long.mp4',
      formatName: 'mov,mp4',
      duration: const Duration(seconds: 10),
      width: 320,
      height: 240,
      fps: null,
      codec: 'h264',
    );
    final id = await manager.submit(const GifSetting(), video);

    // 等待进入 running
    ExportTask? task;
    for (var i = 0; i < 200; i++) {
      task = await repo.byId(id);
      if (task?.state == TaskState.running) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(task?.state, TaskState.running, reason: '应进入执行中');

    final workDir = Directory('${tempRoot.path}/gifforge_$id');
    expect(workDir.existsSync(), isTrue, reason: '转换目录应已创建');

    // 取消并等待 cancelled 终态
    await manager.cancel(id);
    for (var i = 0; i < 200; i++) {
      task = await repo.byId(id);
      if (task?.state == TaskState.cancelled) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(task?.state, TaskState.cancelled, reason: '取消后应落终态');

    // 临时目录无残留(取消经 CancellationManager 幂等清理)
    final remains = workDir.existsSync()
        ? workDir.listSync().whereType<File>().toList()
        : <File>[];
    expect(remains, isEmpty, reason: '取消后临时目录应无残留文件');
  });
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}
