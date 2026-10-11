package org.orbitnote.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "orbit_note/clipboard")
            .setMethodCallHandler { call, result ->
                if (call.method != "setRichText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val plainText = call.argument<String>("plainText")
                val html = call.argument<String>("html")
                if (plainText == null || html == null) {
                    result.error("invalid_arguments", "Expected clipboard text and HTML.", null)
                    return@setMethodCallHandler
                }
                try {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    clipboard.setPrimaryClip(ClipData.newHtmlText("Orbit Note", plainText, html))
                    result.success(true)
                } catch (error: Exception) {
                    // Binder limits, unavailable service, or OS policy: Dart
                    // will try ordinary text copy and keep the note untouched.
                    result.error("clipboard_unavailable", "Could not copy rich text.", null)
                }
            }
    }
}
