/// 采集素材目录与命名解析(纯函数,零 IO,可独立单测)。
///
/// 桌面素材根目录与素材命名规范见 docs/18 §5.3、docs/20 §二;
/// IO 侧(目录创建)在 PlatformAdapter.capturesDir,本文件只做字符串解析。
library;

/// 桌面素材根目录:Windows `%USERPROFILE%\Documents\chameleon_gif\captures`,
/// 其余平台 `$HOME/Documents/chameleon_gif/captures`。
String captureDirPath({required String home, bool isWindows = false}) {
  final sep = isWindows ? '\\' : '/';
  return '$home${sep}Documents${sep}chameleon_gif${sep}captures';
}

/// Android 素材落位目录:`<docsDir>/chameleon_gif/captures`
/// (docs/18 D1「素材持久可重转」,与桌面 capturesDir 同语义;
/// 相册条目为展示副本,此处为 ffprobe/转换/历史重转的真实文件)。
String androidCapturesDir(String docsDirPath) =>
    '$docsDirPath/chameleon_gif/captures';

/// 素材命名 `capture_<yyyyMMdd_HHmmss>_<seq3位补零>.mp4`(docs/18 §5.3)。
///
/// [seq] 为当日序号(1 起),时间戳为拍摄/录制完成时刻;
/// 序号补零到 3 位,防同名覆盖。
String buildCaptureFilename(DateTime timestamp, {int seq = 1}) {
  String pad(int v, [int width = 2]) => v.toString().padLeft(width, '0');
  final stamp =
      '${pad(timestamp.year)}${pad(timestamp.month)}${pad(timestamp.day)}_'
      '${pad(timestamp.hour)}${pad(timestamp.minute)}${pad(timestamp.second)}';
  return 'capture_${stamp}_${pad(seq, 3)}.mp4';
}
