package com.burakozturk.linkball

import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class ChoiceShareProvider : FileProvider()

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "linkball/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "png") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.arguments as? ByteArray
                val signature = byteArrayOf(137.toByte(), 80, 78, 71, 13, 10, 26, 10)
                if (bytes == null || bytes.size !in 8..8388608 || !bytes.take(8).toByteArray().contentEquals(signature)) {
                    result.error("invalid_png", "Geçersiz sonuç kartı", null)
                    return@setMethodCallHandler
                }
                try {
                    val directory = File(cacheDir, "choice_share").apply { mkdirs() }
                    directory.listFiles()?.filter { it.isFile && System.currentTimeMillis() - it.lastModified() > 86400000L }
                        ?.forEach { it.delete() }
                    val file = File.createTempFile("linkball_", ".png", directory)
                    file.writeBytes(bytes)
                    val uri = FileProvider.getUriForFile(this, "$packageName.choice.share", file)
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "image/png"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        clipData = ClipData.newRawUri("Linkball sonuç kartı", uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(send, "Sonuç kartını paylaş / kaydet"))
                    result.success(null)
                } catch (e: Exception) {
                    result.error("share_failed", "Paylaşım açılamadı", null)
                }
            }
    }
}
