import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class AuthService {
  // This supplied ID came from an installed/desktop OAuth JSON file. Keep it
  // as metadata only until Google Cloud confirms a Web client is intended for
  // serverClientId; never embed the supplied client secret in the APK.
  static const String suppliedOAuthClientId =
      '857994198808-m8lpn7rv0s49i7vius72mgcr1hqi4dkk.apps.googleusercontent.com';

  static const _onboardedKey = 'security_onboarded';
  static const _emailKey = 'user_google_email';
  static const _legacyGoogleEmailKey = 'google_signed_email';
  static const _recoveryEmailKey = 'recovery_email';
  static const _pinKey = 'jarvis_pin';
  static const _biometricKey = 'biometric_lock_enabled';
  static const _biometricChannel =
      MethodChannel('com.ultimate.jarvis/biometric');

  // Android identifies the native app with applicationId + signing SHA-1.
  // Do not pass a Web OAuth client as clientId here. A serverClientId is only
  // needed when requesting an ID token/server auth code.
  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
  );

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> get isOnboarded async =>
      (await _prefs).getBool(_onboardedKey) ?? false;

  Future<String?> get registeredEmail async {
    final prefs = await _prefs;
    return prefs.getString(_emailKey) ?? prefs.getString(_legacyGoogleEmailKey);
  }

  Future<String?> get recoveryEmail async {
    final value = (await _prefs).getString(_recoveryEmailKey);
    return value?.trim().toLowerCase();
  }

  Future<int> get pinLength async =>
      (await _prefs).getString(_pinKey)?.length ?? 0;

  Future<bool> signInWithGoogle() async {
    try {
      final account = await googleSignIn.signIn();
      if (account == null) return false;
      final prefs = await _prefs;
      await prefs.setString(_emailKey, account.email);
      await prefs.setString(_legacyGoogleEmailKey, account.email);
      return true;
    } catch (e) {
      debugPrint('Google Sign-In exception: $e');
      rethrow;
    }
  }

  Future<void> completeSetup({
    required String pin,
    required String recoveryEmail,
    required bool biometricEnabled,
  }) async {
    final prefs = await _prefs;
    final cleanPin = pin.trim();
    final cleanEmail = recoveryEmail.trim().toLowerCase();
    print('AuthService: completing setup with PIN len=${cleanPin.length}, recovery=$cleanEmail');
    await prefs.setString(_pinKey, cleanPin);
    await prefs.setString(_recoveryEmailKey, cleanEmail);
    await prefs.setBool(_biometricKey, biometricEnabled);
    await prefs.setBool(_onboardedKey, true);
    await prefs.reload();
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await _prefs;
    final saved = prefs.getString(_pinKey)?.trim();
    final input = pin.trim();
    print('AuthService: verifying PIN. saved length=${saved?.length}, input length=${input.length}');
    return saved != null && saved.isNotEmpty && saved == input;
  }

  Future<bool> updatePin(String pin) async {
    final normalized = pin.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(normalized)) return false;
    return (await _prefs).setString(_pinKey, normalized);
  }

  Future<bool> updateRecoveryEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      return false;
    }
    return (await _prefs).setString(_recoveryEmailKey, normalized);
  }

  Future<bool> biometricEnabled() async =>
      (await _prefs).getBool(_biometricKey) ?? false;

  Future<bool> biometricAvailable() async {
    try {
      return await _biometricChannel.invokeMethod<bool>('biometricAvailable') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _biometricChannel
              .invokeMethod<bool>('authenticateBiometric') ??
          false;
    } catch (_) {
      return false;
    }
  }
}
