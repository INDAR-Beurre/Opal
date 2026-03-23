import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted user settings via SharedPreferences.
class SettingsProvider extends ChangeNotifier {
  static const _kCookie = 'ytm_cookie';
  static const _kAudioQuality = 'audio_quality';
  static const _kRegion = 'region';

  SharedPreferences? _prefs;
  String? _cookie;
  String _audioQuality = 'best';
  String _region = 'US';

  String? get cookie => _cookie;
  String get audioQuality => _audioQuality;
  String get region => _region;
  bool get isSignedIn => _cookie != null && _cookie!.isNotEmpty;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _cookie = _prefs!.getString(_kCookie);
    _audioQuality = _prefs!.getString(_kAudioQuality) ?? 'best';
    _region = _prefs!.getString(_kRegion) ?? 'US';
    notifyListeners();
  }

  Future<void> setCookie(String? cookie) async {
    _cookie = cookie;
    if (cookie != null && cookie.isNotEmpty) {
      await _prefs?.setString(_kCookie, cookie);
    } else {
      await _prefs?.remove(_kCookie);
    }
    notifyListeners();
  }

  Future<void> setAudioQuality(String quality) async {
    _audioQuality = quality;
    await _prefs?.setString(_kAudioQuality, quality);
    notifyListeners();
  }

  Future<void> setRegion(String region) async {
    _region = region;
    await _prefs?.setString(_kRegion, region);
    notifyListeners();
  }
}
