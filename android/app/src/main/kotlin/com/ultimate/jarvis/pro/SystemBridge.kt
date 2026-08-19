package com.ultimate.jarvis.pro

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.BatteryManager
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.net.wifi.WifiNetworkSuggestion
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SystemBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val wifiSuggestions = mutableListOf<WifiNetworkSuggestion>()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getLocation" -> result.success(getLocation())
            "getBatteryStatus" -> result.success(getBatteryStatus())
            "openWifiSettings" -> result.success(openSettings(Settings.ACTION_WIFI_SETTINGS))
            "openHotspotSettings" -> result.success(openSettings(Settings.ACTION_WIRELESS_SETTINGS))
            "openBluetoothSettings" -> result.success(openSettings(Settings.ACTION_BLUETOOTH_SETTINGS))
            "openAccessibilitySettings" -> result.success(openSettings(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            "openAppSettings" -> result.success(openSettings(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, activity.packageName))
            "getWifiState" -> result.success(getWifiState())
            "getBluetoothState" -> result.success(getBluetoothState())
            "suggestWifi" -> result.success(suggestWifi(call))
            "removeWifiSuggestions" -> result.success(removeWifiSuggestions())
            "launchPackage" -> result.success(launchPackage(call.argument<String>("packageName").orEmpty()))
            "resolvePackage" -> result.success(resolvePackage(call.argument<String>("appName").orEmpty()))
            "dial" -> result.success(dial(call.argument<String>("number").orEmpty()))
            else -> result.notImplemented()
        }
    }

    private fun getLocation(): Map<String, Any?> {
        val manager = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        if (!hasLocationPermission()) return mapOf("status" to "permission_required")
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        var best: Location? = null
        providers.forEach { provider ->
            try {
                val location = manager.getLastKnownLocation(provider)
                if (location != null && (best == null || location.time > best!!.time)) best = location
            } catch (_: SecurityException) {}
        }
        if (best == null) {
            return mapOf(
                "status" to if (manager.isLocationEnabled) "unavailable" else "disabled",
            )
        }
        return mapOf(
            "status" to "ok",
            "latitude" to best!!.latitude,
            "longitude" to best!!.longitude,
            "accuracy" to best!!.accuracy,
            "timestamp" to best!!.time,
        )
    }

    private fun getBatteryStatus(): Map<String, Any?> {
        val manager = activity.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val percent = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        val intent = activity.registerReceiver(null, android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED))
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        return mapOf(
            "status" to "ok",
            "percent" to percent.coerceIn(0, 100),
            "charging" to charging,
            "chargingState" to when (status) {
                BatteryManager.BATTERY_STATUS_FULL -> "full"
                BatteryManager.BATTERY_STATUS_CHARGING -> "charging"
                BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "not_charging"
                BatteryManager.BATTERY_STATUS_DISCHARGING -> "discharging"
                else -> "unknown"
            },
        )
    }

    private fun hasLocationPermission(): Boolean =
        ActivityCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ActivityCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun getWifiState(): Map<String, Any?> {
        val manager = activity.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val info = manager.connectionInfo
        return mapOf(
            "enabled" to manager.isWifiEnabled,
            "ssid" to (info?.ssid?.removePrefix("\"")?.removeSuffix("\"") ?: ""),
        )
    }

    private fun getBluetoothState(): Map<String, Any?> {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        return mapOf("available" to (adapter != null), "enabled" to (adapter?.isEnabled == true))
    }

    private fun suggestWifi(call: MethodCall): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            openSettings(Settings.ACTION_WIFI_SETTINGS)
            return mapOf("status" to "settings_required", "message" to "Use Wi-Fi settings on this Android version.")
        }
        val ssid = call.argument<String>("ssid")?.trim().orEmpty()
        val password = call.argument<String>("password")?.trim().orEmpty()
        if (ssid.isEmpty() || password.length < 8) return mapOf("status" to "invalid", "message" to "SSID and an 8+ character password are required.")
        val suggestion = WifiNetworkSuggestion.Builder().setSsid(ssid).setWpa2Passphrase(password).setIsAppInteractionRequired(true).build()
        val manager = activity.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val status = manager.addNetworkSuggestions(listOf(suggestion))
        if (status == WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS) {
            wifiSuggestions.add(suggestion)
            openSettings(Settings.ACTION_WIFI_SETTINGS)
            return mapOf("status" to "suggested", "message" to "Approve the JARVIS Wi-Fi suggestion in the system UI.")
        }
        return mapOf("status" to "failed", "code" to status)
    }

    private fun removeWifiSuggestions(): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return mapOf("status" to "settings_required")
        val manager = activity.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val status = manager.removeNetworkSuggestions(wifiSuggestions)
        wifiSuggestions.clear()
        return mapOf("status" to if (status == WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS) "removed" else "failed", "code" to status)
    }

    private fun resolvePackage(appName: String): Map<String, Any?> {
        val normalized = appName.trim().lowercase()
        val mapping = mapOf(
            "youtube" to "com.google.android.youtube",
            "chrome" to "com.android.chrome",
            "gmail" to "com.google.android.gm",
            "maps" to "com.google.android.apps.maps",
            "whatsapp" to "com.whatsapp",
            "instagram" to "com.instagram.android",
            "facebook" to "com.facebook.katana",
            "spotify" to "com.spotify.music",
            "telegram" to "org.telegram.messenger",
            "discord" to "com.discord",
            "netflix" to "com.netflix.mediaclient",
            "amazon" to "com.amazon.mShop.android.shopping",
        )
        val packageName = mapping[normalized]
        if (packageName == null) return mapOf("status" to "unknown", "appName" to appName)
        val installed = try {
            activity.packageManager.getApplicationInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) { false }
        return mapOf("status" to if (installed) "installed" else "not_installed", "packageName" to packageName, "appName" to appName)
    }

    private fun launchPackage(packageName: String): Map<String, Any?> {
        if (packageName.isEmpty()) return mapOf("status" to "invalid")
        return try {
            val launchIntent = activity.packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent == null) mapOf("status" to "not_installed", "packageName" to packageName)
            else {
                activity.startActivity(launchIntent)
                mapOf("status" to "launched", "packageName" to packageName)
            }
        } catch (_: Exception) {
            mapOf("status" to "failed", "packageName" to packageName)
        }
    }

    private fun dial(number: String): Map<String, Any?> {
        if (!Regex("^\\+?[0-9 ()-]{7,20}$").matches(number.trim())) return mapOf("status" to "invalid")
        return try {
            activity.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:${Uri.encode(number.trim())}")))
            mapOf("status" to "opened")
        } catch (_: Exception) { mapOf("status" to "failed") }
    }

    private fun openSettings(action: String, packageName: String? = null): Boolean {
        return try {
            val intent = if (packageName == null) Intent(action) else Intent(action, Uri.parse("package:$packageName"))
            activity.startActivity(intent)
            true
        } catch (_: Exception) { false }
    }
}
