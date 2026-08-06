import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/features/camera/infrastructure/capture_committer.dart';
import 'package:chameleon_gif/shared/platform/gallery_save_result.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';

/// [CaptureCommitter] 纯 Dart 单测:素材落位(rename/copy 回退/目录创建)、
/// 相册三态、取消清理。
void main() {
  late Directory tempRoot;
  late Directory capturesDir;
  late _FakeAdapter adapter;
  late CaptureCommitter committer;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('capture_commit_');
    capturesDir = Directory('${tempRoot.path}/captures');
    adapter = _FakeAdapter();
    committer = CaptureCommitter(adapter: adapter, capturesDir: capturesDir);
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  File writeTmp(String name) {
    final f = File('${tempRoot.path}/$name')..writeAsStringSync('tmp-bytes');
    return f;
  }

  test('commit:tmp 落位素材目录(rename)+ 相册 saved → CaptureResult', () async {
    adapter.saveVideoResult = const GallerySaveResult.saved(
      displayPath: 'Movies/GIFForge/capture_x.mp4',
      uri: 'content://media/video/1',
    );
    final tmp = writeTmp('tmp_1.mp4');

    final r = await committer.commit(
      tmpPath: tmp.path,
      fileName: 'capture_x.mp4',
      durationMs: 3200,
    );

    expect(
      File('${capturesDir.path}/capture_x.mp4').existsSync(),
      isTrue,
      reason: '素材持久副本',
    );
    expect(tmp.existsSync(), isFalse, reason: 'tmp 已落位(rename)');
    expect(r.finalPath, '${capturesDir.path}/capture_x.mp4');
    expect(r.durationMs, 3200);
    expect(r.galleryStatus, GallerySaveStatus.saved);
    expect(r.galleryUri, 'content://media/video/1');
    expect(adapter.savedDisplayName, 'capture_x.mp4');
  });

  test('discardTmp:取消/失败路径幂等清理(二次调用不抛)', () async {
    // rename 跨存储回退分支依赖真实文件系统差异(Android cache→filesDir
    // 可能跨分区),单测不可控,由真机清单覆盖;此处验证取消清理语义。
    final tmp = writeTmp('tmp_2.mp4');
    await committer.discardTmp(tmp.path);
    expect(tmp.existsSync(), isFalse, reason: 'discardTmp 幂等清理');

    await committer.discardTmp(tmp.path); // 二次调用不抛
  });

  test('commit:存相册 failed → 素材保留 + failed 状态(不阻塞)', () async {
    adapter.saveVideoResult = const GallerySaveResult.failed('保存到相册失败');
    final tmp = writeTmp('tmp_3.mp4');

    final r = await committer.commit(
      tmpPath: tmp.path,
      fileName: 'capture_y.mp4',
      durationMs: 1000,
    );

    expect(
      File('${capturesDir.path}/capture_y.mp4').existsSync(),
      isTrue,
      reason: '存相册失败副本保留供手动处理',
    );
    expect(r.galleryStatus, GallerySaveStatus.failed);
    expect(r.galleryUri, isNull);
  });

  test('commit:桌面 unsupported → 素材落位 + unsupported(无相册)', () async {
    adapter.saveVideoResult = const GallerySaveResult.unsupported();
    final tmp = writeTmp('tmp_4.mp4');

    final r = await committer.commit(
      tmpPath: tmp.path,
      fileName: 'capture_z.mp4',
      durationMs: 500,
    );

    expect(File('${capturesDir.path}/capture_z.mp4').existsSync(), isTrue);
    expect(r.galleryStatus, GallerySaveStatus.unsupported);
  });

  test('commit:素材目录自动创建(首次调用)', () async {
    expect(capturesDir.existsSync(), isFalse);

    final tmp = writeTmp('tmp_5.mp4');
    await committer.commit(
      tmpPath: tmp.path,
      fileName: 'capture_a.mp4',
      durationMs: 100,
    );

    expect(capturesDir.existsSync(), isTrue);
    expect(File('${capturesDir.path}/capture_a.mp4').existsSync(), isTrue);
  });
}

class _FakeAdapter extends PlatformAdapter {
  GallerySaveResult saveVideoResult = const GallerySaveResult.unsupported();
  String? savedDisplayName;

  @override
  Future<GallerySaveResult> saveVideo(
    String sourcePath, {
    String? displayName,
  }) async {
    savedDisplayName = displayName;
    return saveVideoResult;
  }
}
