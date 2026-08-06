package com.chameleongif.chameleon_gif

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // 相册保存/打开/分享通道(MediaStoreChannel,见 docs/13-风险分析.md R-07 实证)
    MediaStoreChannel.register(
      flutterEngine.dartExecutor.binaryMessenger,
      applicationContext,
    )
    // 录屏通道(MediaProjection 授权需 Activity 上下文与 onActivityResult 转发)
    ScreenRecordChannel.register(
      flutterEngine.dartExecutor.binaryMessenger,
      this,
    )
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    // 必须先 super:file_picker 等插件依赖 engine 分发 onActivityResult
    super.onActivityResult(requestCode, resultCode, data)
    ScreenRecordChannel.onActivityResult(requestCode, resultCode, data)
  }

  override fun onDestroy() {
    // 页面销毁兜底:回复挂起结果 + 通知服务取消(防前台服务泄漏)
    ScreenRecordChannel.onActivityDestroyed()
    super.onDestroy()
  }
}
