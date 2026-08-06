package com.chameleongif.chameleon_gif

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import java.util.Timer
import java.util.TimerTask
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * 录屏前台服务(MediaProjection + MediaCodec H264 + MediaMuxer → 无声 MP4)。
 *
 * Android 14+(targetSdk 34+)强制:先 startForegroundService → 本服务
 * onStartCommand 内先 startForeground(mediaProjection 类型)再
 * getMediaProjection,顺序反了抛 SecurityException。
 *
 * MediaProjection 一次性:每次会话授权 token 只能创建一次 VirtualDisplay,
 * 停止后 token 失效 → 系统强制下次重新授权(与"每次录制需授权"一致)。
 * 无声录制(仅视频轨):无 AudioRecord/音轨同步,代码大幅简化。
 */
class ScreenRecordService : Service() {
  companion object {
    const val ACTION_START = "com.chameleongif.chameleon_gif.START_RECORD"
    const val ACTION_STOP = "com.chameleongif.chameleon_gif.STOP_RECORD"

    const val EXTRA_RESULT_CODE = "result_code"
    const val EXTRA_RESULT_DATA = "result_data"
    const val EXTRA_FPS = "fps"
    const val EXTRA_MAX_DURATION_MS = "max_duration_ms"
    const val EXTRA_ASPECT_RATIO = "aspect_ratio"
    const val EXTRA_OUTPUT_PATH = "output_path"

    private const val NOTIF_ID = 1001
    private const val CHANNEL_ID = "screen_record"
    private const val TAG = "ScreenRecordService"

    private var current: ScreenRecordService? = null

    /** 幂等停止请求(通道线程安全调用;normal=true 保存,false 取消删 tmp)。 */
    fun requestStop(normal: Boolean) {
      current?.requestStop(normal)
    }
  }

  private var projection: MediaProjection? = null
  private var virtualDisplay: VirtualDisplay? = null
  private var codec: MediaCodec? = null
  private var muxer: MediaMuxer? = null
  private var muxerStarted = false
  private var trackIndex = -1
  private var recording = false
  private var startElapsedMs = 0L
  private var outputPath: String? = null
  private var drainThread: Thread? = null
  private var timeoutTimer: Timer? = null
  private var stopNormal = true

  override fun onCreate() {
    super.onCreate()
    current = this
    createNotificationChannel()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_START -> {
        startForeground(NOTIF_ID, buildNotification())
        val mgr =
          getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        @Suppress("DEPRECATION")
        val data =
          if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
          } else {
            intent.getParcelableExtra(EXTRA_RESULT_DATA)
          }
        if (data == null) {
          finishWith("error", "录屏授权数据缺失", 0)
          return START_NOT_STICKY
        }
        projection =
          mgr.getMediaProjection(intent.getIntExtra(EXTRA_RESULT_CODE, 0), data)
        // Android 14+(targetSdk 34+)强制:捕获启动前必须先 registerCallback,
        // 否则 getMediaProjection/start 抛 IllegalStateException(真机实测)
        projection?.registerCallback(
          object : MediaProjection.Callback() {
            override fun onStop() {
              // 系统停止投影(用户通知栏取消等)兜底:正常保存并结束
              Log.i(TAG, "投影被系统停止(通知栏取消等)")
              requestStop(normal = true)
            }
          },
          null,
        )
        if (startEncoding(intent)) {
          Log.i(TAG, "录制会话启动")
        } else {
          finishWith("error", "编码器初始化失败", 0)
        }
      }
      ACTION_STOP -> requestStop(normal = true)
    }
    return START_NOT_STICKY
  }

  private fun startEncoding(intent: Intent): Boolean {
    val fps = intent.getDoubleExtra(EXTRA_FPS, 15.0)
    val maxDurationMs = intent.getIntExtra(EXTRA_MAX_DURATION_MS, 60_000)
    val aspectRatio =
      if (intent.hasExtra(EXTRA_ASPECT_RATIO)) {
        intent.getDoubleExtra(EXTRA_ASPECT_RATIO, 0.0)
      } else {
        0.0
      }
    outputPath = intent.getStringExtra(EXTRA_OUTPUT_PATH) ?: ""
    val proj = projection ?: return false

    val metrics = resources.displayMetrics
    var w = metrics.widthPixels
    var h = metrics.heightPixels
    if (aspectRatio > 0) {
      // 虚拟显示比例:显示范围内最大等比矩形,偶数对齐
      val target = aspectRatio
      if (w.toDouble() / h > target) {
        h = (w / target).roundToInt()
      } else {
        w = (h * target).roundToInt()
      }
      w = w and 0x7FFFFFFE // 偶数对齐
      h = h and 0x7FFFFFFE
    }

    return try {
      val format =
        MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, w, h).apply {
          setInteger(
            MediaFormat.KEY_COLOR_FORMAT,
            MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
          )
          // 经验码率:0.07 bits/pixel/frame;至少 1Mbps
          setInteger(MediaFormat.KEY_BIT_RATE, max((w * h * fps * 0.07).toInt(), 1_000_000))
          setInteger(MediaFormat.KEY_FRAME_RATE, fps.toInt())
          setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
      val enc = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
      enc.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
      val surface = enc.createInputSurface()
      val mux = MediaMuxer(outputPath!!, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

      virtualDisplay =
        proj.createVirtualDisplay(
          "GifForgeScreenRecord",
          w,
          h,
          metrics.densityDpi,
          DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
          surface,
          null,
          null,
        )

      enc.start()
      codec = enc
      muxer = mux
      recording = true
      stopNormal = true
      startElapsedMs = SystemClock.elapsedRealtime()

      // 超时自动停(500ms 轮询,保存)
      timeoutTimer = Timer("screen-record-timeout").apply {
        scheduleAtFixedRate(
          object : TimerTask() {
            override fun run() {
              val elapsed = SystemClock.elapsedRealtime() - startElapsedMs
              if (recording && elapsed >= maxDurationMs) {
                requestStop(normal = true)
              }
            }
          },
          500,
          500,
        )
      }

      drainThread = Thread({ drainLoop(enc, mux) }, "screen-record-drain").also {
        it.start()
      }
      true
    } catch (e: Exception) {
      Log.e(TAG, "编码器初始化失败", e)
      false
    }
  }

  /** 编码输出循环:format 变化 → addTrack+muxer.start;缓冲 → writeSampleData;EOS 退出。 */
  private fun drainLoop(enc: MediaCodec, mux: MediaMuxer) {
    val bufferInfo = MediaCodec.BufferInfo()
    try {
      while (true) {
        val outIndex = enc.dequeueOutputBuffer(bufferInfo, 10_000)
        when {
          outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
            synchronized(this) {
              if (!muxerStarted) {
                trackIndex = mux.addTrack(enc.outputFormat)
                mux.start()
                muxerStarted = true
              }
            }
          }
          outIndex >= 0 -> {
            val buffer = enc.getOutputBuffer(outIndex) ?: continue
            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
              bufferInfo.size = 0
            }
            if (bufferInfo.size > 0) {
              buffer.position(bufferInfo.offset)
              buffer.limit(bufferInfo.offset + bufferInfo.size)
              synchronized(this) {
                if (muxerStarted) mux.writeSampleData(trackIndex, buffer, bufferInfo)
              }
            }
            enc.releaseOutputBuffer(outIndex, false)
            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
              return
            }
          }
        }
      }
    } catch (e: Exception) {
      Log.e(TAG, "编码输出循环异常", e)
    }
  }

  /** 幂等停止:停 Timer/显示/投影 → EOS → join drain → 释放 → 回通道 → 停服务。 */
  private fun requestStop(normal: Boolean) {
    synchronized(this) {
      if (!recording) return
      recording = false
      stopNormal = normal
    }
    timeoutTimer?.cancel()
    timeoutTimer = null
    try {
      virtualDisplay?.release()
      virtualDisplay = null
      projection?.stop()
      projection = null
      codec?.signalEndOfInputStream()
      drainThread?.join(3_000)
      synchronized(this) {
        if (muxerStarted) {
          try {
            muxer?.stop()
          } catch (e: Exception) {
            Log.w(TAG, "muxer stop 异常(输出可能不完整)", e)
          }
        }
        muxer?.release()
        muxer = null
      }
      codec?.stop()
      codec?.release()
      codec = null
    } catch (e: Exception) {
      Log.e(TAG, "停止录制异常", e)
    }
    val elapsed = SystemClock.elapsedRealtime() - startElapsedMs
    if (stopNormal) {
      finishWith("saved", outputPath, elapsed)
    } else {
      // 取消:删 tmp(尽力),回复 cancelled
      try {
        outputPath?.let { java.io.File(it).delete() }
      } catch (_: Exception) {
      }
      finishWith("cancelled", null, elapsed)
    }
  }

  private fun finishWith(status: String, path: String?, durationMs: Long) {
    ScreenRecordChannel.onRecordingFinished(status, path, durationMs, null)
    stopForeground(STOP_FOREGROUND_REMOVE)
    stopSelf()
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel =
        NotificationChannel(CHANNEL_ID, "屏幕录制", NotificationManager.IMPORTANCE_LOW)
      val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      nm.createNotificationChannel(channel)
    }
  }

  @Suppress("DEPRECATION")
  private fun buildNotification(): Notification {
    val builder =
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Notification.Builder(this, CHANNEL_ID)
      } else {
        Notification.Builder(this)
      }
    return builder
      .setContentTitle("屏幕录制中")
      .setContentText("正在录制屏幕,用于生成 GIF")
      .setSmallIcon(android.R.drawable.ic_media_play)
      .setOngoing(true)
      .build()
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onDestroy() {
    synchronized(this) {
      if (recording) {
        recording = false
        try {
          virtualDisplay?.release()
          projection?.stop()
        } catch (_: Exception) {
        }
      }
    }
    if (current === this) current = null
    super.onDestroy()
  }
}
