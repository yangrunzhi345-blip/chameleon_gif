package com.chameleongif.chameleon_gif

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
  }
}
