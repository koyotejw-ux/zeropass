package com.zeropass.app.zeropass

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.zeropass.app/sms_launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "launchNativeSms") {
                val phone = call.argument<String>("phone") ?: ""
                val body = call.argument<String>("body") ?: ""
                try {
                    val cleanPhone = phone.replace(Regex("[^0-9]"), "")
                    val intent = Intent(Intent.ACTION_SENDTO).apply {
                        data = Uri.parse("smsto:$cleanPhone")
                        // Using extras avoids URI length limits and URL encoding truncation!
                        putExtra("sms_body", body)
                        putExtra(Intent.EXTRA_TEXT, body)
                    }
                    if (intent.resolveActivity(packageManager) != null) {
                        startActivity(intent)
                        result.success(true)
                    } else {
                        // Fallback generic sms intent
                        val fallbackIntent = Intent(Intent.ACTION_VIEW).apply {
                            type = "vnd.android-dir/mms-sms"
                            putExtra("address", cleanPhone)
                            putExtra("sms_body", body)
                            putExtra(Intent.EXTRA_TEXT, body)
                        }
                        startActivity(fallbackIntent)
                        result.success(true)
                    }
                } catch (e: Exception) {
                    result.error("SMS_ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
