package com.chameleongif.chameleon_gif

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 相册保存与分享的 MethodChannel(自写原生,零新增 Gradle 依赖)。
 *
 * 方法:
 * - saveToGallery {path, displayName}:MediaStore.Images 写入(API>=29,免权限),
 *   insert+copy 在后台线程执行(大文件防 ANR);API<29 返回 failed 中文提示,
 *   由 Dart 侧引导用户用系统分享。
 * - saveVideo {path, displayName}:MediaStore.Video 写入(拍摄/录屏素材存相册,
 *   语义同 saveToGallery,分区 Movies/GIFForge)。
 * - contentExists {uri}:ContentResolver 查询 content URI 是否仍存在
 *   (历史重转素材预检;异常兜底 false)。
 * - openGallery {uri?}:ACTION_VIEW 定位保存条目;无 uri 兜底相册网格。
 * - shareFile {path}:FileProvider + ACTION_SEND(Android 9- 保存兜底)。
 *
 * 返回统一 Map:{status: saved|failed|unsupported, displayPath?, uri?, message?},
 * 与 Dart 侧 GallerySaveResult 一一对应(见 gallery_save_result.dart)。
 */
object MediaStoreChannel {
  private const val CHANNEL = "com.chameleongif.chameleon_gif/media_store"
  private val ALBUM = "${Environment.DIRECTORY_PICTURES}/GIFForge"
  private val ALBUM_VIDEO = "${Environment.DIRECTORY_MOVIES}/GIFForge"

  fun register(messenger: BinaryMessenger, appContext: Context) {
    MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "saveToGallery" -> handleSave(call, result, appContext)
        "saveVideo" -> handleSaveVideo(call, result, appContext)
        "contentExists" -> handleContentExists(call, result, appContext)
        "openGallery" -> handleOpen(call, result, appContext)
        "shareFile" -> handleShare(call, result, appContext)
        else -> result.notImplemented()
      }
    }
  }

  private fun handleSave(call: MethodCall, result: MethodChannel.Result, context: Context) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
      result.success(
        mapOf(
          "status" to "failed",
          "message" to "当前系统版本过低,无法直接保存到相册,请使用系统分享保存",
        ),
      )
      return
    }
    val path = call.argument<String>("path")
    val displayName = call.argument<String>("displayName")
    if (path == null || !File(path).exists()) {
      result.success(mapOf("status" to "failed", "message" to "输出文件不存在,无法保存到相册"))
      return
    }
    saveIntoMediaStore(
      result = result,
      context = context,
      collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
      mime = "image/gif",
      album = ALBUM,
      defaultName = "chameleon.gif",
      path = path,
      displayName = displayName,
    )
  }

  private fun handleSaveVideo(
    call: MethodCall,
    result: MethodChannel.Result,
    context: Context,
  ) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
      result.success(
        mapOf(
          "status" to "failed",
          "message" to "当前系统版本过低,无法直接保存到相册,请使用系统分享保存",
        ),
      )
      return
    }
    val path = call.argument<String>("path")
    val displayName = call.argument<String>("displayName")
    if (path == null || !File(path).exists()) {
      result.success(mapOf("status" to "failed", "message" to "输出文件不存在,无法保存到相册"))
      return
    }
    saveIntoMediaStore(
      result = result,
      context = context,
      collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
      mime = "video/mp4",
      album = ALBUM_VIDEO,
      defaultName = "capture.mp4",
      path = path,
      displayName = displayName,
    )
  }

  /** 统一 MediaStore 写入(Images/Video 共用):insert + copy + IS_PENDING 1→0,
   *  失败回滚 delete。大文件 IO 必须后台线程(MethodChannel.Result 允许
   *  在任意线程 complete,Flutter JNI 线程安全)。 */
  private fun saveIntoMediaStore(
    result: MethodChannel.Result,
    context: Context,
    collection: Uri,
    mime: String,
    album: String,
    defaultName: String,
    path: String?,
    displayName: String?,
  ) {
    Thread {
      val resolver = context.contentResolver
      val values = ContentValues().apply {
        put(MediaStore.MediaColumns.DISPLAY_NAME, displayName ?: defaultName)
        put(MediaStore.MediaColumns.MIME_TYPE, mime)
        // 必须相对路径且无前导 "/",否则 Android 10+ 抛 IllegalArgumentException
        put(MediaStore.MediaColumns.RELATIVE_PATH, album)
        put(MediaStore.MediaColumns.IS_PENDING, 1)
      }
      var uri: Uri? = null
      try {
        uri = resolver.insert(collection, values)
          ?: throw IllegalStateException("MediaStore insert 返回 null")
        resolver.openOutputStream(uri)?.use { out ->
          File(path!!).inputStream().use { src -> src.copyTo(out, 1 shl 20) }
        } ?: throw IllegalStateException("openOutputStream 返回 null")
        values.clear()
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, displayName ?: defaultName)
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        result.success(
          mapOf(
            "status" to "saved",
            "displayPath" to "$album/${values.getAsString(MediaStore.MediaColumns.DISPLAY_NAME)}",
            "uri" to uri.toString(),
          ),
        )
      } catch (e: Exception) {
        // 写失败回滚 pending 条目,避免相册出现半成品占位
        uri?.let { runCatching { resolver.delete(it, null, null) } }
        result.success(mapOf("status" to "failed", "message" to "保存到相册失败,请使用系统分享保存"))
      }
    }.start()
  }

  private fun handleContentExists(
    call: MethodCall,
    result: MethodChannel.Result,
    context: Context,
  ) {
    val uriStr = call.argument<String>("uri")
    if (uriStr == null) {
      result.success(false)
      return
    }
    // 直接对 content URI 查询 _ID:条目存在返回 true;异常(已删除/非法)
    // 一律 false,不向 Dart 抛错(预检语义,见 Dart 侧 sourceExists)
    val exists =
      runCatching {
        context.contentResolver
          .query(
            Uri.parse(uriStr),
            arrayOf(MediaStore.MediaColumns._ID),
            null,
            null,
            null,
          )
          ?.use { it.count > 0 } ?: false
      }.getOrDefault(false)
    result.success(exists)
  }

  private fun handleOpen(call: MethodCall, result: MethodChannel.Result, context: Context) {
    val uriArg = call.argument<String>("uri")
    val intent =
      if (uriArg != null) {
        Intent(Intent.ACTION_VIEW).setDataAndType(Uri.parse(uriArg), "image/gif")
      } else {
        Intent(Intent.ACTION_VIEW).setData(MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
      }
    runCatching {
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      context.startActivity(intent)
    } // ActivityNotFoundException 等:尽力语义,静默
    result.success(null)
  }

  private fun handleShare(call: MethodCall, result: MethodChannel.Result, context: Context) {
    val path = call.argument<String>("path")
    if (path == null) {
      result.success(null)
      return
    }
    runCatching {
      val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", File(path))
      val send = Intent(Intent.ACTION_SEND).apply {
        type = "image/gif"
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      }
      val chooser = Intent.createChooser(send, "分享 GIF").apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      }
      context.startActivity(chooser)
    }
    result.success(null)
  }
}
