package org.orbitnote.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val vaultFolders by lazy { AndroidVaultFolderPicker(this) }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!vaultFolders.onResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        OrbitBackgroundJobs.pause(this)
        super.onCreate(savedInstanceState)
    }
    override fun onStart() {
        OrbitBackgroundJobs.pause(this)
        super.onStart()
    }
    override fun onStop() {
        super.onStop()
        try { OrbitBackgroundJobs.schedule(this) } catch (_: Exception) { /* Settings can retry. */ }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "orbit_note/vault_folders")
            .setMethodCallHandler { call, result ->
                if (call.method == "importFolder") vaultFolders.open(result)
                else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "orbit_note/background_sync")
            .setMethodCallHandler { call, result ->
                if (call.method != "configure") result.notImplemented()
                else try {
                    OrbitBackgroundJobs.configure(this, call.argument<Boolean>("enabled") == true)
                    result.success(null)
                } catch (_: Exception) {
                    result.error("scheduler", "Android did not allow the background job.", null)
                }
            }
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
