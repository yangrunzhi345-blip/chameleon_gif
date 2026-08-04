import 'dart:convert';
import 'dart:io';

/// 从 test/fixtures/ffprobe/ 加载 ffprobe JSON 夹具。
///
/// 形状与真实 `ffprobe -show_format -show_streams` 输出一致(纯 Dart,
/// 不依赖 ffmpeg_kit 类型)。
Map<String, dynamic> loadFfprobeFixture(String name) {
  final raw = File('test/fixtures/ffprobe/$name.json').readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}
