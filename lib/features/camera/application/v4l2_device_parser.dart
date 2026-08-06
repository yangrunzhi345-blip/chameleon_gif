/// v4l2 设备枚举输出解析(纯函数,可单测;本机真实输出固化为夹具)。
library;

/// 设备条目:名称 + 采集节点。
class V4l2DeviceEntry {
  const V4l2DeviceEntry({required this.name, required this.node});

  /// 设备名称(v4l2-ctl 分组名 / ffmpeg 方括号内名称)。
  final String name;

  /// 采集节点(/dev/videoN)。
  final String node;
}

/// 解析 `v4l2-ctl --list-devices` 输出(枚举首选路径)。
///
/// 输出形态(实测):设备名行以 `:` 结尾,后续制表符缩进行为节点
/// (可能混入 /dev/media* 元设备,过滤仅保留 /dev/video*);同一摄像头
/// 的多个节点均返回,meta 节点由调用方 `--get-fmt-video` 探活过滤。
List<V4l2DeviceEntry> parseV4l2ListDevices(String output) {
  final entries = <V4l2DeviceEntry>[];
  String? currentName;
  for (final rawLine in output.split('\n')) {
    final line = rawLine.trimRight();
    if (line.endsWith(':')) {
      currentName = line.substring(0, line.length - 1).trim();
      continue;
    }
    if (currentName == null) continue;
    final node = line.trim();
    if (node.startsWith('/dev/video')) {
      entries.add(V4l2DeviceEntry(name: currentName, node: node));
    }
  }
  return entries;
}

/// 解析 `ffmpeg -hide_banner -sources v4l2` 输出(降级路径:
/// v4l2-ctl 缺失时使用;实测输出:
/// `  /dev/video1 [USB2.0 HD UVC WebCam: USB2.0 HD] (none)`)。
///
/// 注意:该路径**不区分 meta 节点**,采集启动失败由错误映射兜底
/// (meta 节点 ffmpeg 启动即报错,可被 capture 出口捕获)。
List<V4l2DeviceEntry> parseFfmpegSourcesV4l2(String output) {
  final entries = <V4l2DeviceEntry>[];
  final pattern = RegExp(r'^(/dev/video\d+)\s*\[([^\]]*)\]');
  for (final line in output.split('\n')) {
    final match = pattern.firstMatch(line.trim());
    if (match == null) continue;
    entries.add(
      V4l2DeviceEntry(name: match.group(2) ?? '', node: match.group(1)!),
    );
  }
  return entries;
}

/// 解析 `ffmpeg -hide_banner -sources dshow` 输出(Windows 设备枚举)。
///
/// 预期形态(Windows 真机,待验证):
/// ```
/// DirectShow video devices (some may be both video and audio devices)
///     "Integrated Camera"
///     "OBS Virtual Camera"
/// DirectShow audio devices
/// ```
/// 解析 video 段引号内设备名(名称即 dshow 输入标识,含空格与引号
/// 由命令装配整串传入);形态不符时按 Windows 验证清单修正。
List<String> parseFfmpegSourcesDshow(String output) {
  final names = <String>[];
  final lines = output.split('\n');
  var inVideoSection = false;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('DirectShow video devices')) {
      inVideoSection = true;
      continue;
    }
    if (trimmed.startsWith('DirectShow audio devices')) {
      break;
    }
    if (!inVideoSection) continue;
    final quoted = RegExp(r'"([^"]+)"').firstMatch(trimmed);
    if (quoted != null) names.add(quoted.group(1)!);
  }
  return names;
}
