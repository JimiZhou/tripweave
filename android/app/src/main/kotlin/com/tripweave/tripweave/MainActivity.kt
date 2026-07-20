package com.tripweave.tripweave

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.tripweave.tripweave/media_store"
    private val createDocumentRequest = 7401
    private var pendingResult: MethodChannel.Result? = null
    private var pendingSource: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveVideo") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val sourcePath = call.argument<String>("sourcePath")
                val displayName = call.argument<String>("displayName")
                    ?.takeIf { it.endsWith(".mp4", ignoreCase = true) }
                    ?: "tripweave-${System.currentTimeMillis()}.mp4"
                val source = sourcePath?.let(::File)
                if (source == null || !source.isFile) {
                    result.error("source_missing", "导出的临时视频不存在，请重新生成。", null)
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    saveToMediaStore(source, displayName, result)
                } else {
                    openLegacySaveDialog(source, displayName, result)
                }
            }
    }

    private fun saveToMediaStore(
        source: File,
        displayName: String,
        result: MethodChannel.Result,
    ) {
        Thread {
            var destination: Uri? = null
            try {
                val values = ContentValues().apply {
                    put(MediaStore.Video.Media.DISPLAY_NAME, displayName)
                    put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                    put(
                        MediaStore.Video.Media.RELATIVE_PATH,
                        "${Environment.DIRECTORY_MOVIES}/TripWeave",
                    )
                    put(MediaStore.Video.Media.IS_PENDING, 1)
                }
                destination = contentResolver.insert(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    values,
                ) ?: error("系统媒体库没有返回保存位置。")
                contentResolver.openOutputStream(destination, "w").use { output ->
                    requireNotNull(output) { "无法打开系统媒体库写入流。" }
                    source.inputStream().buffered().use { input ->
                        input.copyTo(output)
                    }
                }
                values.clear()
                values.put(MediaStore.Video.Media.IS_PENDING, 0)
                contentResolver.update(destination, values, null, null)
                runOnUiThread { result.success(destination.toString()) }
            } catch (error: Throwable) {
                destination?.let { contentResolver.delete(it, null, null) }
                runOnUiThread {
                    result.error("media_store_write_failed", error.message, null)
                }
            }
        }.start()
    }

    private fun openLegacySaveDialog(
        source: File,
        displayName: String,
        result: MethodChannel.Result,
    ) {
        if (pendingResult != null) {
            result.error("save_in_progress", "已有一个保存操作正在进行。", null)
            return
        }
        pendingResult = result
        pendingSource = source
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "video/mp4"
            putExtra(Intent.EXTRA_TITLE, displayName)
        }
        startActivityForResult(intent, createDocumentRequest)
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != createDocumentRequest) return
        val result = pendingResult ?: return
        val source = pendingSource
        val destination = data?.data
        pendingResult = null
        pendingSource = null
        if (resultCode != Activity.RESULT_OK || source == null || destination == null) {
            result.success(null)
            return
        }
        Thread {
            try {
                contentResolver.openOutputStream(destination, "w").use { output ->
                    requireNotNull(output) { "无法打开所选保存位置。" }
                    source.inputStream().buffered().use { input -> input.copyTo(output) }
                }
                runOnUiThread { result.success(destination.toString()) }
            } catch (error: Throwable) {
                runOnUiThread {
                    result.error("document_write_failed", error.message, null)
                }
            }
        }.start()
    }
}
