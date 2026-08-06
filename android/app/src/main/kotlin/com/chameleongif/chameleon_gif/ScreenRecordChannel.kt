package com.chameleongif.chameleon_gif

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 录屏通道(自写原生,零新增 Gradle 依赖,仿 MediaStoreChannel object 模式)。
 *
 * 方法:
 * - startRecording {fps, maxDurationMs, aspectRatio?, outputPath}:
 *   Result **挂起**,录制结束(手动停止/超时自动停/取消/授权拒绝)才回复:
 *   {status: saved, path, durationMs} / {status: rejected} /
 *   {status: cancelled} / {status: error, message}
 * - stopRecording:手动停止(正常保存);cancelRecording:取消(删 tmp)。
 *
 * 授权流:createScreenCaptureIntent → startActivityForResult;MainActivity
 * 转发 onActivityResult。Android 14+ 时序:先 startForegroundService,
 * 服务 onStartCommand 内 startForeground 后再 getMediaProjection
 * (顺序反了抛 SecurityException,见 ScreenRecordService 注释)。
 */
object ScreenRecordChannel {
  private const val CHANNEL = "com.chameleongif.chameleon_gif/screen_record"
  private const val REQUEST_CODE = 0x5C0A

  private var activity: Activity? = null
  private var pendingResult: MethodChannel.Result? = null
  private var params: StartParams? = null

  private data class StartParams(
    val fps: Double,
    val maxDurationMs: Int,
    val aspectRatio: Double?,
    val outputPath: String,
  )

  fun register(messenger: BinaryMessenger, activity: Activity) {
    this.activity = activity
    MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "startRecording" -> handleStart(call, result)
        "stopRecording" -> ScreenRecordService.requestStop(normal = true)
        "cancelRecording" -> ScreenRecordService.requestStop(normal = false)
        else -> result.notImplemented()
      }
    }
  }

  private fun handleStart(call: MethodCall, result: MethodChannel.Result) {
    val act = activity
    if (act == null || act.isDestroyed) {
      result.success(mapOf("status" to "error", "message" to "录屏通道未就绪"))
      return
    }
    if (pendingResult != null) {
      result.success(mapOf("status" to "error", "message" to "已有录制会话进行中"))
      return
    }
    pendingResult = result
    params = StartParams(
      fps = call.argument<Double>("fps") ?: 15.0,
      maxDurationMs = call.argument<Int>("maxDurationMs") ?: 60_000,
      aspectRatio = call.argument<Double>("aspectRatio"),
      outputPath = call.argument<String>("outputPath") ?: "",
    )
    val mgr =
      act.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    act.startActivityForResult(mgr.createScreenCaptureIntent(), REQUEST_CODE)
  }

  /** MainActivity 转发;拒绝 → 立即回复 rejected,成功 → 启动前台服务。 */
  fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    if (requestCode != REQUEST_CODE || pendingResult == null) return
    val act = activity ?: return
    if (resultCode != Activity.RESULT_OK || data == null) {
      finish(mapOf("status" to "rejected"))
      return
    }
    val p = params ?: run {
      finish(mapOf("status" to "error", "message" to "录屏参数缺失"))
      return
    }
    val intent =
      Intent(act, ScreenRecordService::class.java).apply {
        action = ScreenRecordService.ACTION_START
        putExtra(ScreenRecordService.EXTRA_RESULT_CODE, resultCode)
        putExtra(ScreenRecordService.EXTRA_RESULT_DATA, data)
        putExtra(ScreenRecordService.EXTRA_FPS, p.fps)
        putExtra(ScreenRecordService.EXTRA_MAX_DURATION_MS, p.maxDurationMs)
        if (p.aspectRatio != null) {
          putExtra(ScreenRecordService.EXTRA_ASPECT_RATIO, p.aspectRatio)
        }
        putExtra(ScreenRecordService.EXTRA_OUTPUT_PATH, p.outputPath)
      }
    androidx.core.content.ContextCompat.startForegroundService(act, intent)
  }

  /** 服务回调(同进程):回复挂起 Result。 */
  fun onRecordingFinished(status: String, path: String?, durationMs: Long, message: String?) {
    val reply =
      buildMap {
        put("status", status)
        if (path != null) put("path", path)
        put("durationMs", durationMs)
        if (message != null) put("message", message)
      }
    finish(reply)
  }

  private fun finish(reply: Map<String, Any?>) {
    pendingResult?.success(reply)
    pendingResult = null
    params = null
  }

  /** Activity 销毁兜底:回复 error + 通知服务取消(防前台服务泄漏)。 */
  fun onActivityDestroyed() {
    if (pendingResult != null) {
      finish(mapOf("status" to "error", "message" to "页面已关闭"))
      ScreenRecordService.requestStop(normal = false)
    }
  }
}
