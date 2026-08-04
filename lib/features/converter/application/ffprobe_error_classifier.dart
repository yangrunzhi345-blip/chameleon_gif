import '../../../domain/exceptions/file_pick_exception.dart';
import '../../../domain/exceptions/source_broken_exception.dart';
import '../../../domain/exceptions/source_missing_exception.dart';

/// ffprobe 失败输出 → 领域异常(纯函数,可单测)。
///
/// 特征映射契约见 docs/08-FFmpeg设计.md §8.3.5 错误映射表;
/// 错误码编码 `GIF_<EXITCODE>_<KIND>`。匹配顺序:文件缺失 → 文件损坏 → 兜底。
class FfprobeErrorClassifier {
  const FfprobeErrorClassifier();

  /// 依据 ffprobe stderr 全文与退出码分类失败原因。
  ///
  /// 匹配前统一转小写,保证 `MOOV`/`Moov` 等大小写变体命中;
  /// 未匹配任何已知特征时兜底为通用 [FilePickException],不猜测具体原因。
  FilePickException classify({required String stderr, required int exitCode}) {
    final text = stderr.toLowerCase();
    if (text.contains('no such file or directory')) {
      return SourceMissingException(
        errorCode: 'GIF_${exitCode}_SOURCE_MISSING',
      );
    }
    if (text.contains('invalid data found') || text.contains('moov')) {
      return SourceBrokenException(errorCode: 'GIF_${exitCode}_SOURCE_BROKEN');
    }
    return FilePickException(
      errorCode: 'GIF_${exitCode}_PROBE_FAILED',
      userMessage: '视频解析失败(错误码 $exitCode),请尝试其他文件',
    );
  }
}
