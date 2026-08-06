/// 从 ffprobe 结果解析视频旋转角(显示矩阵,度;0/缺失 = 无需旋转)。
///
/// [probeJson](两端兼容:桌面 Process JSON / Android Kit getAllProperties)
/// 的 `streams[0].side_data_list` 中 `rotation` 键;解析失败返回 null
/// (调用方按"无需旋转"处理,不阻塞采集流程)。纯参数签名,core 零依赖
/// (FfprobeResult 含 ffmpeg_kit 插件类型,不下沉 domain)。
int? parseRotationDegrees(Map<dynamic, dynamic>? probeJson) {
  final streams = probeJson?['streams'];
  if (streams is! List || streams.isEmpty) return null;
  final sideData = (streams.first as Map?)?['side_data_list'];
  if (sideData is! List) return null;
  for (final entry in sideData) {
    if (entry is Map && entry['rotation'] is num) {
      return (entry['rotation'] as num).round();
    }
  }
  return null;
}
