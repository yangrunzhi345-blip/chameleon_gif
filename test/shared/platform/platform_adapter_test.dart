import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/shared/platform/gallery_save_result.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';

/// [PlatformAdapter] 素材目录与存在性预检测试。
///
/// 单测运行于 Linux:Android 分支分发逻辑无法在此构造(Platform.isAndroid
/// 恒 false),由桥契约测试 + 阶段 B 真机覆盖;此处锁定桌面侧契约。
void main() {
  // content:// 分支走 MethodChannel(AndroidMediaStoreSaver),需 binding
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PlatformAdapter.capturesDir', () {
    test('桌面分支:经 capturesRoot 创建素材目录并返回路径(幂等)', () async {
      final temp = await Directory.systemTemp.createTemp('captures_test_');
      addTearDown(() => temp.delete(recursive: true));
      final adapter = _FakeRootAdapter(temp.path);

      final dir = adapter.capturesDir;

      expect(dir, temp.path);
      expect(Directory(dir).existsSync(), isTrue);
      // 二次访问幂等(不重复创建、不抛错)
      expect(adapter.capturesDir, temp.path);
    });
  });

  group('PlatformAdapter.sourceExists', () {
    test('真实存在文件 → true', () async {
      final file = File(
        '${Directory.systemTemp.path}/exists_${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      file.writeAsStringSync('x');
      addTearDown(() => file.deleteSync());

      expect(await const PlatformAdapter().sourceExists(file.path), isTrue);
    });

    test('不存在文件 → false', () async {
      expect(
        await const PlatformAdapter().sourceExists('/nonexistent/path/foo.mp4'),
        isFalse,
      );
    });

    test('content:// URI 在桌面无法判定 → 放行 true', () async {
      // Linux 无原生桥:contentExists 返回 null → 视为存在放行(预检不挡任务)
      expect(
        await const PlatformAdapter().sourceExists(
          'content://media/external/video/media/1',
        ),
        isTrue,
      );
    });
  });

  group('PlatformAdapter.saveVideo/saveToGallery(桌面)', () {
    test('桌面返回 unsupported(无相册能力)', () async {
      final video = await const PlatformAdapter().saveVideo('/tmp/x.mp4');
      expect(video.status, GallerySaveStatus.unsupported);

      final image = await const PlatformAdapter().saveToGallery('/tmp/x.gif');
      expect(image.status, GallerySaveStatus.unsupported);
    });
  });
}

/// 覆写 [PlatformAdapter.capturesRoot] 注入临时目录(严禁触真实 ~/Documents)。
class _FakeRootAdapter extends PlatformAdapter {
  _FakeRootAdapter(this.root);

  final String root;

  @override
  String capturesRoot() => root;
}
