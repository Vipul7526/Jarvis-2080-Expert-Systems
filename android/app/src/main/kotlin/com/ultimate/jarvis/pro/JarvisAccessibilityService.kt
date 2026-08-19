package com.ultimate.jarvis.pro

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class JarvisAccessibilityService : AccessibilityService() {
    companion object {
        const val ACTION_SCREEN_CONTEXT = "com.ultimate.jarvis.SCREEN_CONTEXT"
        const val EXTRA_PACKAGE_NAME = "packageName"
        const val EXTRA_SCREEN_TEXT = "screenText"

        @Volatile
        private var latestPackageName: String = ""

        @Volatile
        private var latestScreenText: String = ""

        fun latestSnapshot(): Map<String, String> = mapOf(
            "packageName" to latestPackageName,
            "screenText" to latestScreenText,
        )
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceInfo = serviceInfo?.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = flags or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val root = rootInActiveWindow ?: return
        val builder = StringBuilder()
        appendVisibleText(root, builder, 0)
        val packageName = event.packageName?.toString().orEmpty()
        val screenText = builder.toString().trim().take(8000)
        latestPackageName = packageName
        latestScreenText = screenText
        sendBroadcast(Intent(ACTION_SCREEN_CONTEXT).apply {
            setPackage(this@JarvisAccessibilityService.packageName)
            putExtra(EXTRA_PACKAGE_NAME, packageName)
            putExtra(EXTRA_SCREEN_TEXT, screenText)
        })
    }

    override fun onInterrupt() = Unit

    fun performJarvisGlobalAction(action: String): Boolean = when (action.lowercase()) {
        "back" -> performGlobalAction(GLOBAL_ACTION_BACK)
        "home" -> performGlobalAction(GLOBAL_ACTION_HOME)
        "recents" -> performGlobalAction(GLOBAL_ACTION_RECENTS)
        "notifications" -> performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
        "quick_settings" -> performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS)
        else -> false
    }

    private fun appendVisibleText(node: AccessibilityNodeInfo, builder: StringBuilder, depth: Int) {
        if (depth > 32 || builder.length >= 8000) return
        val text = node.text?.toString()?.trim().orEmpty()
        val description = node.contentDescription?.toString()?.trim().orEmpty()
        if (text.isNotEmpty()) appendUnique(builder, text)
        if (description.isNotEmpty()) appendUnique(builder, description)
        for (index in 0 until node.childCount) {
            val child = node.getChild(index) ?: continue
            try {
                appendVisibleText(child, builder, depth + 1)
            } finally {
                child.recycle()
            }
            if (builder.length >= 8000) return
        }
    }

    private fun appendUnique(builder: StringBuilder, value: String) {
        if (value.isEmpty() || builder.length >= 8000) return
        if (builder.indexOf(value) >= 0) return
        if (builder.isNotEmpty()) builder.append('\n')
        builder.append(value)
    }
}
