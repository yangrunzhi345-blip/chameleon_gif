import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/application/cache_storage_controller.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/export_history.dart';
import 'package:chameleon_gif/domain/entities/export_task.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';

/// [CacheStorageController] 纯 Dart 测试(注入 fake 仓储 + 临时目录 + 时钟)。
void main() {
  late Directory tempRoot;
  late InMemoryTaskRepository tasks;
  late InMemoryHistoryRepository histories;
  var clock = DateTime(2026, 8, 7, 12);

  late ProviderContainer container;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('gifforge_cache_test_');
    tasks = InMemoryTaskRepository();
    histories = InMemoryHistoryRepository();
    clock = DateTime(2026, 8, 7, 12);
  });

  tearDown(() async {
    container.dispose();
    await tempRoot.delete(recursive: true);
  });

  CacheStorageController buildController() {
    container = ProviderContainer(
      overrides: [
        cacheStorageControllerProvider.overrideWith(
          () => CacheStorageController(
            taskRepository: tasks,
            historyRepository: histories,
            logger: AppLogger(),
            now: () => clock,
            systemTempDir: tempRoot.path,
          ),
        ),
      ],
    );
    return container.read(cacheStorageControllerProvider.notifier);
  }

  /// 构造 temp 目录树(返回关键路径)。
  ({
    String pickerOld,
    String pickerNew,
    String pickerSub,
    String work,
    String thumb,
  })
  makeTree({bool withSub = true, int workId = 42}) {
    final picker = Directory('${tempRoot.path}/file_picker');
    final t1 = Directory('${picker.path}/t1')..createSync(recursive: true);
    final t2 = Directory('${picker.path}/t2')..createSync(recursive: true);
    final oldFile = File('${t1.path}/old.jpg')..writeAsStringSync('old');
    File('${t2.path}/fresh.jpg').writeAsStringSync('fresh');
    final sub = withSub ? (Directory('${t2.path}/nested')..createSync()) : null;
    final work = Directory('${tempRoot.path}/gifforge_$workId')
      ..createSync(recursive: true);
    File('${work.path}/out.gif').writeAsStringSync('work');
    final thumb = Directory('${tempRoot.path}/gifforge_thumbs')
      ..createSync(recursive: true);
    File('${thumb.path}/thumb_a.png').writeAsStringSync('thumb');
    return (
      pickerOld: oldFile.path,
      pickerNew: '${t2.path}/fresh.jpg',
      pickerSub: sub?.path ?? '',
      work: work.path,
      thumb: '${thumb.path}/thumb_a.png',
    );
  }

  /// 文件 mtime 拨到 [daysAgo] 天前(超期/新鲜控制;目录 mtime 无法直接
  /// 修改,工作目录超期用注入时钟前拨模拟)。
  void age(String path, int daysAgo) {
    File(path).setLastModifiedSync(
      DateTime(2026, 8, 7, 12).subtract(Duration(days: daysAgo)),
    );
  }

  group('统计', () {
    test('三分区统计正确(文件数与字节)', () async {
      final paths = makeTree();
      final controller = buildController();

      await controller.load();

      final state = container.read(cacheStorageControllerProvider);
      expect(state.totalCount, 4, reason: '2 副本 + 1 工作输出 + 1 缩略图');
      expect(
        state.totalBytes,
        'old'.length + 'fresh'.length + 'work'.length + 'thumb'.length,
      );
      expect(state.partitions[CachePartition.filePickerCopies]!.count, 2);
      expect(state.partitions[CachePartition.workDirs]!.count, 1);
      expect(state.partitions[CachePartition.thumbs]!.count, 1);
      expect(paths.pickerSub, isNotEmpty);
    });
  });

  group('启动自动清理', () {
    test('未引用 + 超期副本删除;未超期保留;空子目录回收', () async {
      final paths = makeTree();
      age(paths.pickerOld, 8); // 8 天前 → 超期
      // pickerNew 保持新鲜
      final controller = buildController();

      await controller.runStartupCleanup();

      expect(File(paths.pickerOld).existsSync(), isFalse, reason: '超期未引用删');
      expect(File(paths.pickerNew).existsSync(), isTrue, reason: '新鲜保留');
      // t1 子目录已空 → 回收
      expect(
        Directory(File(paths.pickerOld).parent.path).existsSync(),
        isFalse,
      );
    });

    test('被引用副本不删(即使超期)', () async {
      final paths = makeTree();
      age(paths.pickerOld, 8);
      await tasks.add(
        ExportTask(
          id: 1,
          videoPath: paths.pickerOld,
          outputPath: null,
          imagePaths: null,
          settings: const GifSetting(),
          state: TaskState.completed,
          createdAt: DateTime(2026, 8, 1),
        ),
      );
      final controller = buildController();

      await controller.runStartupCleanup();

      expect(File(paths.pickerOld).existsSync(), isTrue, reason: '仍被任务引用 → 豁免');
    });

    test('工作目录:终态/不存在任务 + 超期删;running 任务目录保留', () async {
      // 时钟拨到 8 天后(目录创建于现在 → 相对 cutoff 已"超期";
      // 目录 mtime 无法直接修改,用注入时钟模拟)
      clock = DateTime(2026, 8, 7, 12).add(const Duration(days: 8));
      // 先 add 拿真实自增 id(InMemory 仓储忽略传入 id),目录名对齐
      final taskId = await tasks.add(
        ExportTask(
          id: 42,
          videoPath: '',
          outputPath: 'x',
          imagePaths: null,
          settings: const GifSetting(),
          state: TaskState.running,
          createdAt: DateTime(2026, 8, 1),
        ),
      );
      final paths = makeTree(workId: taskId);
      // 任务处于 running → 目录保留
      await tasks.update(
        ExportTask(
          id: taskId,
          videoPath: '',
          outputPath: '${paths.work}/out.gif',
          imagePaths: null,
          settings: const GifSetting(),
          state: TaskState.running,
          createdAt: DateTime(2026, 8, 1),
        ),
      );
      final controller = buildController();

      await controller.runStartupCleanup();

      expect(
        Directory(paths.work).existsSync(),
        isTrue,
        reason: 'running 任务目录豁免',
      );

      // 任务转终态 → 下次启动清理删除
      await tasks.update(
        ExportTask(
          id: taskId,
          videoPath: '',
          outputPath: '${paths.work}/out.gif',
          imagePaths: null,
          settings: const GifSetting(),
          state: TaskState.completed,
          createdAt: DateTime(2026, 8, 1),
        ),
      );
      await controller.runStartupCleanup();
      expect(
        Directory(paths.work).existsSync(),
        isFalse,
        reason: '终态 + 超期 → 删',
      );
    });

    test('历史引用豁免:历史 imagePaths 中的副本不删', () async {
      final paths = makeTree();
      age(paths.pickerOld, 8);
      await histories.add(
        ExportHistory(
          id: 1,
          videoPath: '',
          outputPath: '${tempRoot.path}/out.gif',
          imagePaths: [paths.pickerOld],
          settings: const GifSetting(),
          durationMs: 1000,
          outputSizeBytes: 10,
          createdAt: DateTime(2026, 8, 1),
          sourceDurationMs: 1000,
        ),
      );
      final controller = buildController();

      await controller.runStartupCleanup();

      expect(File(paths.pickerOld).existsSync(), isTrue, reason: '历史记录引用 → 豁免');
    });
  });

  group('手动清空', () {
    test('副本全清(含被引用)+ 非 running 工作目录 + 缩略图', () async {
      final paths = makeTree();
      // 副本被任务引用 → 手动清空仍删(用户明确选择)
      await tasks.add(
        ExportTask(
          id: 1,
          videoPath: paths.pickerOld,
          outputPath: null,
          imagePaths: null,
          settings: const GifSetting(),
          state: TaskState.completed,
          createdAt: DateTime(2026, 8, 1),
        ),
      );
      final controller = buildController();

      await controller.clear();

      expect(File(paths.pickerOld).existsSync(), isFalse, reason: '手动清空不豁免');
      expect(File(paths.pickerNew).existsSync(), isFalse);
      expect(Directory(paths.work).existsSync(), isFalse);
      expect(File(paths.thumb).existsSync(), isFalse);
      // 清空后统计归零
      final state = container.read(cacheStorageControllerProvider);
      expect(state.totalCount, 0);
    });
  });
}
