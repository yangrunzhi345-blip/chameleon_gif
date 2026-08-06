import 'domain_exception.dart';

/// 采集(拍摄/录屏)通用失败(设备不可用/原生错误等)。
class CaptureException extends DomainException {
  const CaptureException({
    required super.errorCode,
    required super.userMessage,
    super.cause,
  });
}

/// 采集被用户取消(静默:返回/按返回键等,UI 不弹提示)。
class CaptureCancelledException extends DomainException {
  const CaptureCancelledException()
    : super(errorCode: 'GIF_CAPTURE_CANCELLED', userMessage: '已取消');
}

/// 采集权限被拒绝(相机权限 / MediaProjection 授权;UI 展示引导文案)。
class CapturePermissionDeniedException extends DomainException {
  const CapturePermissionDeniedException({required super.userMessage})
    : super(errorCode: 'GIF_CAPTURE_PERMISSION_DENIED');
}
