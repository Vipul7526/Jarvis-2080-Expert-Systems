package com.ultimate.jarvis.pro

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.fragment.app.FragmentActivity
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NativeAuth(private val activity: FragmentActivity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "biometricAvailable" -> result.success(isBiometricAvailable())
            "authenticateBiometric" -> authenticate(result)
            else -> result.notImplemented()
        }
    }

    private fun isBiometricAvailable(): Boolean {
        val manager = BiometricManager.from(activity)
        return manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK) ==
            BiometricManager.BIOMETRIC_SUCCESS
    }

    private fun authenticate(result: MethodChannel.Result) {
        if (!isBiometricAvailable()) {
            result.success(false)
            return
        }
        val executor = ContextCompat.getMainExecutor(activity)
        val prompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    authenticationResult: BiometricPrompt.AuthenticationResult,
                ) {
                    result.success(true)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    result.success(false)
                }

                override fun onAuthenticationFailed() {
                    // Keep the prompt open for another enrolled biometric attempt.
                }
            },
        )
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Unlock JARVIS")
            .setSubtitle("Use an enrolled face or fingerprint")
            .setDescription("JARVIS will unlock only after Android verifies an enrolled biometric.")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_WEAK)
            .setNegativeButtonText("Use JARVIS PIN")
            .setConfirmationRequired(true)
            .build()
        prompt.authenticate(info)
    }
}
