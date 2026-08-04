import '../../../domain/exceptions/disk_full_exception.dart';
import '../../../domain/exceptions/domain_exception.dart';
import '../../../domain/exceptions/encode_exception.dart';
import '../../../domain/exceptions/ffmpeg_missing_exception.dart';
import '../../../domain/exceptions/output_conflict_exception.dart';
import '../../../domain/exceptions/palette_exception.dart';
import '../../../domain/exceptions/permission_exception.dart';
import '../../../domain/exceptions/source_broken_exception.dart';
import '../../../domain/exceptions/source_missing_exception.dart';

/// 退出码 + stderr 特征 → 领域异常(纯函数,docs/08 §8.3.5 错误映射表)。
///
/// 匹配顺序即映射表顺序(先特征后退出码):127 → 缺二进制;特征行 → 对应
/// 异常;exit 1 + palette 关键词 → 调色板失败;其余非 0 → [EncodeException]。
/// 错误码统一 `GIF_<EXITCODE>_<KIND>`。
class ErrorHandler {
  const ErrorHandler();

  /// 分类结果;类型为 [DomainException] 以容纳 FilePick 系(源缺失/损坏)
  /// 与 Conversion 系(磁盘/权限/编码)两类异常。
  DomainException classify({required int exitCode, required String stderr}) {
    final s = stderr.toLowerCase();
    if (exitCode == 127) {
      return FFmpegMissingException(kind: 'ENCODE');
    }
    if (s.contains('no such file')) {
      return SourceMissingException(
        errorCode: 'GIF_${exitCode}_SOURCE_MISSING',
      );
    }
    if (s.contains('invalid data') || s.contains('moov')) {
      return SourceBrokenException(errorCode: 'GIF_${exitCode}_SOURCE_BROKEN');
    }
    if (s.contains('no space left')) {
      return DiskFullException(errorCode: 'GIF_${exitCode}_DISK_FULL');
    }
    if (s.contains('permission denied')) {
      return PermissionException(errorCode: 'GIF_${exitCode}_PERMISSION');
    }
    if (s.contains('output file already exists')) {
      return OutputConflictException(
        errorCode: 'GIF_${exitCode}_OUTPUT_CONFLICT',
      );
    }
    if (exitCode == 1 &&
        (s.contains('palette') ||
            s.contains('palettegen') ||
            s.contains('paletteuse'))) {
      return PaletteException(errorCode: 'GIF_1_PALETTE');
    }
    return EncodeException(errorCode: 'GIF_${exitCode}_ENCODE');
  }
}
