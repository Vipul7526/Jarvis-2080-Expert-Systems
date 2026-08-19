package com.ultimate.jarvis.pro

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.service.voice.VoiceInteractionService

/**
 * Entry point used when JARVIS is selected as Android's default assistant.
 *
 * The service deliberately does not start SpeechRecognizer or a foreground
 * microphone loop. Android/OEM hotword DSP ownership is system-controlled. A
 * hardware-enrolled hotword, when available on a device, is delivered by the
 * system assistant stack; otherwise JARVIS remains available through the
 * assistant gesture and explicit push-to-talk UI.
 */
class JarvisVoiceInteractionService : VoiceInteractionService() {
    companion object {
        fun isActive(context: android.content.Context): Boolean =
            VoiceInteractionService.isActiveService(
                context,
                ComponentName(context, JarvisVoiceInteractionService::class.java),
            )
    }

    override fun onReady() {
        super.onReady()
    }

    override fun onLaunchVoiceAssistFromKeyguard() {
        launchAssistant("")
    }

    private fun launchAssistant(command: String) {
        val intent = Intent(this, AssistantActivity::class.java).apply {
            action = Intent.ACTION_ASSIST
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
            putExtra("jarvis_command", command)
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
            // The assistant gesture remains available even if the activity is
            // temporarily unavailable while the device is locked.
        }
    }
}

class JarvisVoiceInteractionSessionService : android.service.voice.VoiceInteractionSessionService() {
    override fun onNewSession(args: Bundle): android.service.voice.VoiceInteractionSession =
        JarvisVoiceInteractionSession(this)
}

private class JarvisVoiceInteractionSession(
    context: android.content.Context,
) : android.service.voice.VoiceInteractionSession(context) {
    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        closeSystemDialogs()
        startAssistantActivity(
            Intent(context, AssistantActivity::class.java).apply {
                action = Intent.ACTION_ASSIST
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            },
        )
        hide()
    }
}
