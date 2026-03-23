import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../theme/app_theme.dart';
import 'settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Text('Settings',
                        style: Theme.of(context).textTheme.headlineLarge),
                  ],
                ),
              ),
            ),
            // Account
            SliverToBoxAdapter(
              child: _SectionHeader(title: 'Account'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: LiquidGlassCard(
                  borderRadius: 18,
                  onTap: () async {
                    final result = await Navigator.of(context)
                        .pushNamed('/login');
                    if (result is String?) {
                      settings.setCookie(result);
                    }
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: settings.isSignedIn
                              ? AppTheme.secondaryAccent.withOpacity(0.2)
                              : AppTheme.primaryAccent.withOpacity(0.2),
                        ),
                        child: Icon(
                          settings.isSignedIn
                              ? Icons.person_rounded
                              : Icons.login_rounded,
                          color: settings.isSignedIn
                              ? AppTheme.secondaryAccent
                              : AppTheme.primaryAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settings.isSignedIn
                                  ? 'Signed In'
                                  : 'Sign in to YouTube Music',
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              settings.isSignedIn
                                  ? 'Tap to manage your account'
                                  : 'Sync your library, playlists, and history',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textTertiary, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            // Audio
            SliverToBoxAdapter(
              child: _SectionHeader(title: 'Audio'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: LiquidGlassCard(
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Audio Quality',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _QualityOption(
                        label: 'Best',
                        subtitle: 'Highest available bitrate',
                        selected: settings.audioQuality == 'best',
                        onTap: () => settings.setAudioQuality('best'),
                      ),
                      _QualityOption(
                        label: 'Medium',
                        subtitle: 'Balanced quality and data usage',
                        selected: settings.audioQuality == 'medium',
                        onTap: () => settings.setAudioQuality('medium'),
                      ),
                      _QualityOption(
                        label: 'Low',
                        subtitle: 'Saves data',
                        selected: settings.audioQuality == 'low',
                        onTap: () => settings.setAudioQuality('low'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Region
            SliverToBoxAdapter(
              child: _SectionHeader(title: 'Region'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: LiquidGlassCard(
                  borderRadius: 18,
                  onTap: () => _showRegionPicker(context, settings),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Content Region',
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(settings.region,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textTertiary, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            // About
            SliverToBoxAdapter(
              child: _SectionHeader(title: 'About'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: LiquidGlassCard(
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LiquidGlass Music v2.0',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      const Text(
                        'A beautiful YouTube Music client with a Liquid Glass aesthetic. '
                        'Uses InnerTube API for music data and Piped API as fallback '
                        'for stream extraction.',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  void _showRegionPicker(BuildContext context, SettingsProvider settings) {
    final regions = ['US', 'DE', 'FR', 'GB', 'IT', 'JP', 'KR', 'BR', 'IN', 'CA'];
    LiquidGlassBottomSheet.show(
      context: context,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: regions.length,
        itemBuilder: (context, i) {
          return ListTile(
            title: Text(regions[i],
                style: const TextStyle(color: AppTheme.textPrimary)),
            trailing: settings.region == regions[i]
                ? const Icon(Icons.check_rounded,
                    color: AppTheme.primaryAccent, size: 20)
                : null,
            onTap: () {
              settings.setRegion(regions[i]);
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 28, bottom: 4),
      child: Text(title,
          style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
    );
  }
}

class _QualityOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _QualityOption({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppTheme.primaryAccent : AppTheme.textTertiary,
                  width: selected ? 5 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: selected
                              ? AppTheme.primaryAccent
                              : AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.textTertiary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
