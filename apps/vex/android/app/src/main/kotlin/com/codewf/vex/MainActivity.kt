package com.codewf.vex

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var saving: ByteArray? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "vex/documents").setMethodCallHandler { call, result ->
            when (call.method) {
                "pickDocument", "saveDocument" -> {
                    if (pending != null) { result.error("busy", "A document picker is already open", null); return@setMethodCallHandler }
                    val save = call.method == "saveDocument"
                    saving = if (save) call.argument<ByteArray>("bytes") else null
                    val intent = Intent(if (save) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = if (save) "text/markdown" else "*/*"
                        if (save) putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    }
                    pending = result
                    try { startActivityForResult(intent, 701) } catch (e: Exception) {
                        pending = null; saving = null; result.error("picker", e.message, null)
                    }
                }
                "readDocument", "writeDocument" -> {
                    val location = call.argument<String>("location") ?: ""
                    val bytes = call.argument<ByteArray>("bytes")
                    io.execute {
                        try {
                            val uri = decode(location)
                            if (call.method == "writeDocument") {
                                write(uri, bytes ?: throw IllegalArgumentException("Missing bytes"))
                                runOnUiThread { result.success(null) }
                            } else {
                                val value = read(uri)
                                runOnUiThread { result.success(value) }
                            }
                        } catch (e: Exception) { runOnUiThread { result.error("document", e.message, null) } }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != 701) { super.onActivityResult(requestCode, resultCode, data); return }
        val result = pending ?: return
        val bytes = saving
        pending = null; saving = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
        val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try { contentResolver.takePersistableUriPermission(uri, flags) } catch (_: SecurityException) { /* Some providers grant session access only. */ }
        io.execute {
            try {
                if (bytes != null) write(uri, bytes)
                val value = read(uri).toMutableMap()
                if (bytes == null && flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION == 0) value["location"] = null
                runOnUiThread { result.success(value) }
            } catch (e: Exception) { runOnUiThread { result.error("document", e.message, null) } }
        }
    }

    private fun decode(location: String): Uri {
        require(location.startsWith("vex-document:android:"))
        return Uri.parse(Uri.decode(location.removePrefix("vex-document:android:"))).also { require(it.scheme == "content") }
    }

    private fun read(uri: Uri): Map<String, Any?> {
        var name = "Untitled.md"
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) name = it.getString(0) ?: name
        }
        require(name.substringAfterLast('.', "").lowercase(Locale.ROOT) in setOf("md", "markdown", "txt")) { "Select a Markdown or text document" }
        val bytes = contentResolver.openInputStream(uri)?.use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(65536)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                require(output.size() + count <= 128 * 1024 * 1024) { "Document exceeds 128 MB" }
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        } ?: throw IllegalStateException("Cannot read this document")
        require(bytes.size <= 128 * 1024 * 1024) { "Document exceeds 128 MB" }
        return mapOf("location" to "vex-document:android:${Uri.encode(uri.toString())}", "name" to name, "bytes" to bytes)
    }

    private fun write(uri: Uri, bytes: ByteArray) {
        contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes); it.flush() }
            ?: throw IllegalStateException("Cannot write this document; save a copy instead")
    }

    override fun onDestroy() {
        pending?.error("closed", "The document picker was closed", null)
        pending = null
        io.shutdown()
        super.onDestroy()
    }
}
