/// 采集素材方向修正(docs/18 里程碑:陀螺仪方向判断横竖屏拍摄)。
///
/// 目标:素材方向与拍摄时设备方向一致,且**无 rotation 元数据**
/// (Android media_kit 不应用 rotation,真机实测;统一物理修正)。
///
/// 组合矩阵([devicePortrait] 由拍摄页 MediaQuery 方向提供,即陀螺仪语义):
/// - 竖拍:rotation 非 0 → autorotate 重编码(ffmpeg 自动旋转竖屏);
///    rotation 0/缺失(部分设备不写元数据)→ transpose=1 强制转竖;
/// - 横拍:rotation 0/缺失 → 不转码(素材已横屏);
///    rotation ±90(部分设备横拍误写旋转)→ 反向转回横屏;
///    rotation 180 → 不转码(横屏保持,仅倒置,可接受)。
library;

/// 构造方向修正命令;返回 null = 无需修正(不转码)。
///
/// [rotation] 为 ffprobe display matrix 旋转角(可 null = 缺失)。
List<String>? buildOrientationFixCommand({
  required int? rotation,
  required bool devicePortrait,
  required String input,
  required String output,
}) {
  final r = rotation ?? 0;
  if (devicePortrait) {
    // 竖拍:目标竖屏
    if (r == 0) {
      // 元数据缺失(部分设备):手动顺时针转 90
      return _transcode(['-noautorotate', '-vf', 'transpose=1'], input, output);
    }
    // ±90/180:ffmpeg autorotate 自动旋转到竖屏(默认开启,无需 -vf)
    return _transcode(const [], input, output);
  }
  // 横拍:目标横屏
  if (r == 0 || r == 180) return null; // 已横屏(180 倒置可接受)
  // ±90:横拍误写旋转元数据 → 反向转回横屏(transpose 不依赖 autorotate)
  final transpose = r == -90 ? 'transpose=2' : 'transpose=1';
  return _transcode(['-noautorotate', '-vf', transpose], input, output);
}

List<String> _transcode(List<String> vfArgs, String input, String output) {
  return [
    '-y', // FFmpegKit 默认不覆盖输出文件
    '-i',
    input,
    ...vfArgs,
    // ffmpeg-kit-min 变体不含 libx264(实测 exit=1);h264_mediacodec 为
    // Android 硬件 H.264 编码器(播放兼容性最好,预览实测通过)
    '-c:v',
    'h264_mediacodec',
    '-b:v',
    '8M',
    '-pix_fmt',
    'yuv420p',
    '-an',
    output,
  ];
}
