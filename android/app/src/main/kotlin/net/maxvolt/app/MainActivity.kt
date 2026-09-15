package net.maxvolt.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import androidx.annotation.NonNull

class MainActivity: FlutterActivity() {
    private val CHANNEL = "net.maxvolt.app/nfc"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setNfcTag") {
                val tag = call.argument<String>("tag")
                if (tag != null) {
                    val prefs = getSharedPreferences("nfc_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putString("assigned_tag", tag).apply()
                    result.success(true)
                } else {
                    result.error("INVALID_TAG", "Tag is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

