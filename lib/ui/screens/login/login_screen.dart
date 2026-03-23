import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../theme/app_theme.dart';

/// Login screen for Google / YouTube Music cookie-based authentication.
/// The user pastes their cookie from YouTube Music's web app.
///
/// This is the same approach used by InnerTune, Metrolist, and other
/// InnerTube-based clients. The cookie allows the app to access
/// the user's YTM library, history, and playlists.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _cookieCtrl = TextEditingController();
  bool _saving = false;
  String? _savedCookie;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final cookie = prefs.getString('ytm_cookie');
    if (cookie != null && mounted) {
      setState(() {
        _savedCookie = cookie;
        _cookieCtrl.text = cookie;
      });
    }
  }

  Future<void> _save() async {
    final cookie = _cookieCtrl.text.trim();
    if (cookie.isEmpty) return;
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ytm_cookie', cookie);
    if (mounted) {
      setState(() {
        _savedCookie = cookie;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cookie saved. Restart the app to apply.'),
          backgroundColor: AppTheme.surfaceElevated,
        ),
      );
      Navigator.of(context).pop(cookie);
    }
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ytm_cookie');
    if (mounted) {
      setState(() {
        _savedCookie = null;
        _cookieCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed out'),
          backgroundColor: AppTheme.surfaceElevated,
        ),
      );
      Navigator.of(context).pop(null);
    }
  }

  @override
  void dispose() {
    _cookieCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(height: 28),
              Text('Sign in to YouTube Music',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              const Text(
                'To sync your YouTube Music library, history, and playlists, '
                'paste your cookie from the YouTube Music web app.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 28),
              // Instructions
              LiquidGlassContainer(
                borderRadius: 18,
                intensity: 0.5,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('How to get your cookie:',
                        style: TextStyle(
                            color: AppTheme.primaryAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _step('1', 'Open music.youtube.com in your browser'),
                    _step('2', 'Sign in to your Google account'),
                    _step('3', 'Press F12 to open DevTools'),
                    _step('4', 'Go to the Network tab'),
                    _step('5', 'Reload the page'),
                    _step('6',
                        'Click any request to music.youtube.com'),
                    _step('7',
                        'Find the "Cookie" header and copy its full value'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Cookie input
              const Text('Cookie value',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _cookieCtrl,
                maxLines: 5,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Paste cookie here...',
                  hintStyle:
                      const TextStyle(color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryAccent, width: 0.8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Save / Sign out buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Text('Save & Sign In',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              if (_savedCookie != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _signOut,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                    ),
                    child: const Text('Sign Out'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Privacy note
              const Text(
                'Your cookie is stored locally on this device only. '
                'It is never sent to any server except YouTube.',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryAccent.withOpacity(0.2),
            ),
            child: Center(
                child: Text(num,
                    style: const TextStyle(
                        color: AppTheme.primaryAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13))),
        ],
      ),
    );
  }
}
