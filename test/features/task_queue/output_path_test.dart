import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/features/task_queue/application/output_path.dart';

/// [buildOutputFileName]/[resolveOutputPath] 契约(P4-WP4)。
void main() {
  group('buildOutputFileName', () {
    test('源名 + taskId,去扩展名', () {
      expect(buildOutputFileName('/tmp/videos/demo.mp4', 3), 'demo_3.gif');
    });

    test('Windows 反斜杠路径', () {
      expect(buildOutputFileName(r'C:\Users\a\素材\video.MP4', 7), 'video_7.gif');
    });

    test('非法字符清洗', () {
      expect(buildOutputFileName('/tmp/a<b>c:d?.mp4', 1), 'a_b_c_d__1.gif');
    });

    test('无扩展名/点开头/空名兜底', () {
      expect(buildOutputFileName('/tmp/video', 2), 'video_2.gif');
      // 点开头(dot==0)不剥离,隐藏文件前缀保留
      expect(buildOutputFileName('/tmp/.hidden', 2), '.hidden_2.gif');
      expect(buildOutputFileName('/', 2), 'video_2.gif');
    });
  });

  group('resolveOutputPath', () {
    test('目录 + 源 + id 拼接', () {
      expect(
        resolveOutputPath(
          outputDir: '/home/u/GIF',
          sourcePath: '/tmp/videos/demo.mp4',
          taskId: 5,
        ),
        '/home/u/GIF/demo_5.gif',
      );
    });

    test('目录尾部分隔符去重', () {
      expect(
        resolveOutputPath(
          outputDir: '/home/u/GIF/',
          sourcePath: '/tmp/a.mp4',
          taskId: 1,
        ),
        '/home/u/GIF/a_1.gif',
      );
      // 统一 '/' 拼接(Windows API 接受混合分隔符,见审理 7e 记录)
      expect(
        resolveOutputPath(
          outputDir: r'C:\out\',
          sourcePath: r'C:\in\a.mp4',
          taskId: 1,
        ),
        r'C:\out/a_1.gif',
      );
    });
  });
}
