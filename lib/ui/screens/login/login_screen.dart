import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/repositories/music_repository.dart';
import '../settings/settings_provider.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../theme/app_theme.dart';

/// Login screen for cookie-based YouTube Music authentication.
///
/// Users paste their browser cookie from YouTube Music to authenticate.
/// Supports sign-in, sign-out, and displays step-by-step instructions.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _cookieController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    if (settings.cookie != null) {
      _cookieController.text = settings.cookie!;
    }
  }

  @override
  void dispose() {
    _cookieController.dispose();
    super.dispose();
  }

  Future<void> _saveCookie() async {
    final cookie = _cookieController.text.trim();
    if (cookie.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final settings = context.read<SettingsProvider>();
      final repo = context.read<MusicRepository>();

      await settings.saveCookie(cookie);
      repo.setCookie(cookie);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cookie saved successfully.'),
          backgroundColor: AppTheme.surfaceElevated,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save cookie: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _signOut() async {
    final settings = context.read<SettingsProvider>();
    final repo = context.read<MusicRepository>();

    await settings.clearCookie();
    repo.setCookie(null);

    if (!mounted) return;

    _cookieController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Signed out successfully.'),
        backgroundColor: AppTheme.surfaceElevated,
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isLoggedIn = settings.isLoggedIn;

    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              LiquidGlassIconButton(
                icon: Icons.arrow_back_rounded,
                size: 40,
                iconSize: 20,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Sign in to YouTube Music',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'To sync your YouTube Music library, history, and playlists, '
                'paste your cookie from the YouTube Music web app.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Already logged in section
              if (isLoggedIn) ...[
                LiquidGlassContainer(
                  borderRadius: 18,
                  intensity: 0.5,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.secondaryAccent.withValues(alpha: 0.2),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppTheme.secondaryAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Signed In',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Cookie is configured',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _signOut,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Instructions
              LiquidGlassContainer(
                borderRadius: 18,
                intensity: 0.5,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How to get your cookie:',
                      style: TextStyle(
                        color: AppTheme.primaryAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStep('1', 'Open YouTube Music in your browser'),
                    _buildStep('2', 'Sign in to your Google account'),
                    _buildStep(
                        '3', 'Open Developer Tools (F12) \u2192 Application \u2192 Cookies'),
                    _buildStep('4', 'Copy all cookies and paste below'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Cookie input label
              const Text(
                'Cookie value',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Multiline cookie text field
              TextField(
                controller: _cookieController,
                maxLines: 5,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: 'Paste cookie here...',
                  hintStyle: const TextStyle(color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryAccent,
                      width: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveCookie,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

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

  Widget _buildStep(String number, String text) {
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
              color: AppTheme.primaryAccent.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppTheme.primaryAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
