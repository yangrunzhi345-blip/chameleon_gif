import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/shared/platform/android_media_store.dart';
import 'package:chameleon_gif/shared/platform/ffmpeg_kit_engine.dart';
import 'package:chameleon_gif/shared/platform/gallery_save_result.dart';
import 'package:integration_test/integration_test.dart';

/// Android 真机桥验证(docs/20 阶段 A 手工清单,本机无法覆盖的运行时行为):
///   `flutter test -d <device_id> integration_test/android_media_store_bridge_test.dart`
///
/// 覆盖点:
/// 1. saveVideo 真实写入相册(Movies/GIFForge)并返回 saved + displayPath/uri;
/// 2. contentExists 对已存条目返回 true;
/// 3. contentExists 对不存在条目返回 false(已删除/非法 URI)。
///
/// 测试视频由 ffmpeg_kit 内嵌引擎生成(testsrc,无需宿主文件);
/// 测试产物会留在相册(命名含 bridge 标记,人工核对后删除)。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'saveVideo 写入相册 + contentExists 判定(真机)',
    (tester) async {
      // 1. 内置 ffmpeg_kit 生成 1s 测试视频(cache 目录)
      final cacheDir = Directory.systemTemp;
      final srcPath = '${cacheDir.path}/bridge_capture_test.mp4';
      final engine = FfmpegKitEngine();
      final gen = await engine.convert(
        ConvertRequest(
          command: [
            '-f',
            'lavfi',
            '-i',
            'testsrc=duration=1:size=320x240:rate=15',
            '-pix_fmt',
            'yuv420p',
            '-y',
            srcPath,
          ],
          workDir: cacheDir.path,
          tempFiles: [srcPath],
        ),
      );
      expect(gen.exitCode, 0, reason: '测试视频生成成功: ${gen.exitCode}');
      expect(File(srcPath).existsSync(), isTrue, reason: '测试视频已落盘');

      // 2. saveVideo → saved + 相册路径 + 条目 URI
      const saver = AndroidMediaStoreSaver();
      final r = await saver.saveVideo(
        srcPath,
        displayName: 'capture_bridge_test.mp4',
      );
      expect(r.status, GallerySaveStatus.saved, reason: '应写入相册: ${r.message}');
      expect(r.displayPath, contains('GIFForge'), reason: '相册分区展示路径');
      expect(r.uri, startsWith('content://'), reason: '返回相册条目 URI');
      debugPrint('✅ 相册条目: ${r.displayPath} uri=${r.uri}');

      // 3. contentExists:已存条目 → true;不存在条目 → false
      expect(await saver.contentExists(r.uri!), isTrue, reason: '已存条目应存在');
      expect(
        await saver.contentExists(
          'content://media/external/video/media/99999999',
        ),
        isFalse,
        reason: '不存在的条目应判定缺失',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
