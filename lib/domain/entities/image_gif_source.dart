import '../value_objects/gif_setting.dart';
import '../value_objects/per_image_control.dart';

/// 图片→GIF 的源输入(多张图片按顺序合成帧动画)。
///
/// 与视频路径的 [VideoInfo] 平行:视频由 ffprobe 解析元数据,
/// 图片序列无时长信息,时长由 `GifSetting.effectiveFrameDuration × N` 推算。
/// width/height 为首图尺寸(0 = 未知,仅 UI 展示用,转换无需探测)。
class ImageGifSource {
  const ImageGifSource({
    required this.paths,
    this.width = 0,
    this.height = 0,
    this.perImageControls,
  });

  /// 有序图片路径列表(≥1,顺序即播放顺序)
  final List<String> paths;

  /// 首图宽度(0 = 未知)
  final int width;

  /// 首图高度(0 = 未知)
  final int height;

  /// 每图精细化控制(与 [paths] 等长对齐,null = 全部默认)。
  /// 元素恒非空,`isDefault` 表示该图未操作;null 列表 / 长度不齐时按
  /// 默认处理。不持久化于本对象,随任务/历史 JSON 列存储。
  final List<PerImageControl>? perImageControls;

  /// 第 [i] 张图的控制参数(越界或未精细控制返回 null = 默认)。
  PerImageControl? controlAt(int i) {
    final controls = perImageControls;
    if (controls == null || i < 0 || i >= controls.length) return null;
    return controls[i];
  }

  /// 总输出时长 = 每图实际段长(整帧量化)× 图片数 ÷ 播放速度(供进度
  /// 分母/历史快照/UI 总时长使用;速度 1.0 不缩放,setpts 压缩/拉伸
  /// 输出时间轴后即为实际时长)。量化见 [GifSetting.quantizedFrameDuration]:
  /// 每图 100ms @ 15fps 实际 133ms,产物 20 图 = 2.67s(非 2s)。
  Duration totalDuration(GifSetting setting) {
    final us =
        setting.quantizedFrameDuration.inMicroseconds *
        paths.length /
        setting.playbackSpeed;
    return Duration(microseconds: us.round());
  }
}
