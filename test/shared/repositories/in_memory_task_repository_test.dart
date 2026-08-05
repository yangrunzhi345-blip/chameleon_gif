import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/entities/export_task.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/shared/platform/gallery_save_result.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';

/// [InMemoryTaskRepository] 字段级复制一致性(与 Isar 实现对齐,
/// 缺字段会导致依赖本仓储的测试断言失真)。
void main() {
  test('add 保留全部字段(含相册状态与图片路径)', () async {
    final repo = InMemoryTaskRepository();
    final id = await repo.add(
      ExportTask(
        id: 0,
        videoPath: '/img/a.png',
        imagePaths: const ['/img/a.png', '/img/b.png'],
        settings: const GifSetting(frameDurationMs: 500),
        state: TaskState.completed,
        progress: 0.8,
        errorCode: 'GIF_1_ENCODE',
        errorDetail: '编码失败',
        retryCount: 1,
        createdAt: DateTime(2026, 1, 1),
        startedAt: DateTime(2026, 1, 1, 0, 0, 1),
        finishedAt: DateTime(2026, 1, 1, 0, 0, 5),
        galleryStatus: GallerySaveStatus.failed,
        galleryMessage: '系统版本过低,请使用系统分享保存',
      ),
    );

    final task = await repo.byId(id);
    expect(task, isNotNull);
    expect(task!.imagePaths, ['/img/a.png', '/img/b.png']);
    expect(task.galleryStatus, GallerySaveStatus.failed);
    expect(task.galleryPath, isNull);
    expect(task.galleryUri, isNull);
    expect(task.galleryMessage, '系统版本过低,请使用系统分享保存');
    expect(task.errorDetail, '编码失败');
    expect(task.finishedAt, DateTime(2026, 1, 1, 0, 0, 5));
  });

  test('add 保留相册 saved 三件套', () async {
    final repo = InMemoryTaskRepository();
    final id = await repo.add(
      ExportTask(
        id: 0,
        videoPath: '/tmp/videos/demo.mp4',
        settings: const GifSetting(),
        state: TaskState.completed,
        createdAt: DateTime(2026, 1, 1),
        galleryStatus: GallerySaveStatus.saved,
        galleryPath: 'Pictures/GIFForge/demo.gif',
        galleryUri: 'content://media/external/images/media/1',
      ),
    );

    final task = await repo.byId(id);
    expect(task!.galleryStatus, GallerySaveStatus.saved);
    expect(task.galleryPath, 'Pictures/GIFForge/demo.gif');
    expect(task.galleryUri, 'content://media/external/images/media/1');
  });
}
