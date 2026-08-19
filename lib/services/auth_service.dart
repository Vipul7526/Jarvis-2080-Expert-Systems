import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class AuthService {
  static const String suppliedOAuthClientId =
      '857994198808-m8lpn7rv0s49i7vius72mgcr1hqi4dkk.apps.googleusercontent.com';

  static const _onboardedKey = 'security_onboarded';
  static const _emailKey = 'user_google_email';
  static const _recoveryEmailKey = 'recovery_email';
  static const _pinKey = 'jarvis_pin';
  static const _biometricChannel =
      MethodChannel('com.ultimate.jarvis/biometric');

  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
  );

  static SharedPreferences? _staticPrefs;

  static Future<void> init() async {
    _staticPrefs ??= await SharedPreferences.getInstance();
  }

  static Future<SharedPreferences> getPrefs() async {
    _staticPrefs ??= await SharedPreferences.getInstance();
    return _staticPrefs!;
  }

  static Future<bool> isSetUp() async {
    final prefs = await getPrefs();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  static Future<bool> isLocked() async {
    final prefs = await getPrefs();
    return prefs.getBool('is_locked') ??
        (prefs.getBool(_onboardedKey) ?? false);
  }

  static Future<String?> simulateGoogleSignIn() async => null;

  Future<String?> get registeredEmail async {
    final prefs = await getPrefs();
    return prefs.getString(_emailKey);
  }

  static Future<void> completeSetupStatic({
    required String email,
    required String pin,
    required String recoveryEmail,
  }) =>
      completeSetup(email: email, pin: pin, recoveryEmail: recoveryEmail);

  static Future<bool> verifyPinStatic(String pin) => verifyPin(pin);

  static Future<void> completeSetup({
    required String email,
    required String pin,
    required String recoveryEmail,
  }) async {
    final prefs = await getPrefs();
    await prefs.setString(_emailKey, email);
    await prefs.setString(_pinKey, pin.trim());
    await prefs.setString(
        _recoveryEmailKey, recoveryEmail.trim().toLowerCase());
    await prefs.setBool(_onboardedKey, true);
    await prefs.setBool('is_locked', false);
  }

  static Future<bool> verifyPin(String pin) async {
    final prefs = await getPrefs();
    final saved = prefs.getString(_pinKey)?.trim();
    return saved != null && saved.isNotEmpty && saved == pin.trim();
  }

  static Future<bool> promptBiometric() async {
    try {
      return await _biometricChannel
              .invokeMethod<bool>('authenticateBiometric') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      final account = await googleSignIn.signIn();
      if (account == null) return false;
      final prefs = await getPrefs();
      await prefs.setString(_emailKey, account.email);
      return true;
    } catch (e) {
      debugPrint('Google Sign-In exception: $e');
      return false;
    }
  }
}
