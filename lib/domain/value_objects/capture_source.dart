/// 采集来源(拍摄/录屏;自动导入与预览页来源标记用)。
enum CaptureSource {
  /// 相机拍摄。
  camera,

  /// 屏幕录制。
  screenRecord;

  /// 预览页来源 query 值(`/preview?from=<value>`;无此值时 = 普通导入)。
  String get routeFrom => switch (this) {
    CaptureSource.camera => 'capture',
    CaptureSource.screenRecord => 'record',
  };
}
