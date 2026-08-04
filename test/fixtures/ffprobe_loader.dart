import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_minimal/media_information.dart';

/// 从 test/fixtures/ffprobe/ 加载 ffprobe JSON 夹具并包装为 [MediaInformation]。
///
/// [MediaInformation] 有公开构造(直接透传 ffprobe JSON),纯 Dart 单测据此伪造;
/// 夹具形状与真实 `ffprobe -show_format -show_streams` 输出一致。
MediaInformation loadFfprobeFixture(String name) {
  final raw = File('test/fixtures/ffprobe/$name.json').readAsStringSync();
  final map = jsonDecode(raw) as Map<dynamic, dynamic>;
  return MediaInformation(map);
}
