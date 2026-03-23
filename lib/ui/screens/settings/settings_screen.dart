import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/repositories/music_repository.dart';
import 'settings_provider.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../theme/app_theme.dart';

/// Settings screen with account, audio quality, region, and about sections.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      appBar: LiquidGlassAppBar(
        title: 'Settings',
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: LiquidGlassIconButton(
            icon: Icons.arrow_back_rounded,
            size: 40,
            iconSize: 20,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Account ──
          const SliverToBoxAdapter(
            child: _SectionHeader(title: 'Account'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: settings.isLoggedIn
                  ? _buildSignedInCard(context, settings)
                  : _buildSignInCard(context),
            ),
          ),

          // ── Audio Quality ──
          const SliverToBoxAdapter(
            child: _SectionHeader(title: 'Audio Quality'),
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
                    _QualityOption(
                      label: 'Best',
                      subtitle: 'Highest available bitrate',
                      selected: settings.audioQuality == 'best',
                      onTap: () => _setAudioQuality(context, settings, 'best'),
                    ),
                    _QualityOption(
                      label: 'Medium',
                      subtitle: 'Balanced quality and data usage',
                      selected: settings.audioQuality == 'medium',
                      onTap: () =>
                          _setAudioQuality(context, settings, 'medium'),
                    ),
                    _QualityOption(
                      label: 'Low',
                      subtitle: 'Saves data',
                      selected: settings.audioQuality == 'low',
                      onTap: () => _setAudioQuality(context, settings, 'low'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content Region ──
          const SliverToBoxAdapter(
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
                        const Text(
                          'Content Region',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          settings.region,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textTertiary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── About ──
          const SliverToBoxAdapter(
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
                  children: const [
                    Text(
                      'Opal v3.0.0',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'A YouTube Music client with Liquid Glass UI',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildSignedInCard(BuildContext context, SettingsProvider settings) {
    return LiquidGlassCard(
      borderRadius: 18,
      child: Column(
        children: [
          Row(
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signed In',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your YouTube Music account is connected',
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () async {
                final repo = context.read<MusicRepository>();
                await settings.clearCookie();
                repo.setCookie(null);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
              ),
              child: const Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInCard(BuildContext context) {
    return LiquidGlassCard(
      borderRadius: 18,
      onTap: () => Navigator.of(context).pushNamed('/login'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryAccent.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.login_rounded,
              color: AppTheme.primaryAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign in to YouTube Music',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Sync your library, playlists, and history',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }

  void _setAudioQuality(
    BuildContext context,
    SettingsProvider settings,
    String quality,
  ) {
    settings.setAudioQuality(quality);
    context.read<MusicRepository>().setAudioQuality(quality);
  }

  void _showRegionPicker(BuildContext context, SettingsProvider settings) {
    final regions = [
      'US',
      'GB',
      'DE',
      'FR',
      'IT',
      'JP',
      'KR',
      'BR',
      'IN',
      'CA',
      'AU',
      'MX',
      'ES',
      'NL',
      'SE',
    ];

    LiquidGlassBottomSheet.show(
      context: context,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: regions.length,
        itemBuilder: (context, index) {
          final region = regions[index];
          return ListTile(
            title: Text(
              region,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            trailing: settings.region == region
                ? const Icon(
                    Icons.check_rounded,
                    color: AppTheme.primaryAccent,
                    size: 20,
                  )
                : null,
            onTap: () {
              settings.setRegion(region);
              context.read<MusicRepository>().setRegion(region);
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
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
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
                  color: selected
                      ? AppTheme.primaryAccent
                      : AppTheme.textTertiary,
                  width: selected ? 5 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? AppTheme.primaryAccent
                          : AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
