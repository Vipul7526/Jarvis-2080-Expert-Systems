package com.ultimate.jarvis.pro

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

open class MainActivity : FlutterFragmentActivity() {
    private val assistantChannel = "com.ultimate.jarvis/assistant"
    private val biometricChannel = "com.ultimate.jarvis/biometric"
    private var assistantMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        assistantMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, assistantChannel)
        assistantMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAssistIntent" -> result.success(intent?.action == Intent.ACTION_ASSIST)
                "getAssistCommand" -> result.success(intent?.getStringExtra("jarvis_command") ?: "")
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, biometricChannel)
            .setMethodCallHandler(NativeAuth(this))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ultimate.jarvis/system")
            .setMethodCallHandler(SystemBridge(this))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ultimate.jarvis/wake_word")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start", "status" -> result.success(
                        mapOf(
                            "active" to JarvisVoiceInteractionService.isActive(this),
                            "mode" to "android_default_assistant",
                            "microphoneLoop" to false,
                        ),
                    )
                    "stop" -> result.success(true)
                    "openAssistantSettings" -> try {
                        startActivity(Intent(Settings.ACTION_VOICE_INPUT_SETTINGS))
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("ASSISTANT_SETTINGS_FAILED", error.message, null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        assistantMethodChannel?.invokeMethod("assistCommand", intent.getStringExtra("jarvis_command") ?: "")
    }

    override fun onDestroy() {
        assistantMethodChannel = null
        super.onDestroy()
    }
}
