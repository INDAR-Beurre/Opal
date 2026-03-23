import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted user settings backed by SharedPreferences.
///
/// Manages cookie-based authentication state, audio quality preference,
/// and content region selection.
class SettingsProvider extends ChangeNotifier {
  static const _kCookie = 'ytm_cookie';
  static const _kAudioQuality = 'audio_quality';
  static const _kRegion = 'region';

  SharedPreferences? _prefs;
  String? _cookie;
  String _audioQuality = 'best';
  String _region = 'US';

  // ── Getters ──

  String? get cookie => _cookie;
  String get audioQuality => _audioQuality;
  String get region => _region;
  bool get isLoggedIn => _cookie != null && _cookie!.isNotEmpty;

  // ── Initialization ──

  /// Load all persisted settings from SharedPreferences.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _cookie = _prefs!.getString(_kCookie);
    _audioQuality = _prefs!.getString(_kAudioQuality) ?? 'best';
    _region = _prefs!.getString(_kRegion) ?? 'US';
    notifyListeners();
  }

  // ── Cookie / Auth ──

  /// Save the authentication cookie to persistent storage.
  Future<void> saveCookie(String cookie) async {
    _cookie = cookie;
    await _prefs?.setString(_kCookie, cookie);
    notifyListeners();
  }

  /// Clear the authentication cookie and sign out.
  Future<void> clearCookie() async {
    _cookie = null;
    await _prefs?.remove(_kCookie);
    notifyListeners();
  }

  // ── Audio Quality ──

  /// Set the preferred audio quality.
  ///
  /// Valid values: 'best', 'medium', 'low'.
  Future<void> setAudioQuality(String quality) async {
    _audioQuality = quality;
    await _prefs?.setString(_kAudioQuality, quality);
    notifyListeners();
  }

  // ── Region ──

  /// Set the content region (ISO 3166-1 alpha-2 country code).
  Future<void> setRegion(String region) async {
    _region = region;
    await _prefs?.setString(_kRegion, region);
    notifyListeners();
  }
}
