import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/onboarding_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _totalPages = 7;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    AnalyticsService.track(AnalyticsService.onboardingCompleted);
    await ref.read(onboardingProvider.notifier).markSeen();
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.boneWhite;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await ref.read(onboardingProvider.notifier).markSeen();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar: skip button ──────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page counter
                    Text(
                      '${_currentPage + 1} / $_totalPages',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.textMuted,
                      ),
                    ),
                    // Skip button (hidden on last page)
                    if (_currentPage < _totalPages - 1)
                      TextButton(
                        onPressed: _finish,
                        child: Text(
                          l10n.tutorialSkip,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Pages ─────────────────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _WelcomePage(l10n: l10n, isDark: isDark),
                    _ManualPage(l10n: l10n, isDark: isDark),
                    _PhotoPage(l10n: l10n, isDark: isDark),
                    _VoicePage(l10n: l10n, isDark: isDark),
                    _ListPage(l10n: l10n, isDark: isDark),
                    _ChartsPage(l10n: l10n, isDark: isDark),
                    _DonePage(l10n: l10n, isDark: isDark),
                  ],
                ),
              ),

              // ── Bottom: dots + next button ─────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    _DotsIndicator(
                      total: _totalPages,
                      current: _currentPage,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.dustyTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _currentPage == _totalPages - 1
                              ? l10n.tutorialStart
                              : l10n.tutorialNext,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dots indicator ─────────────────────────────────────────────────────────────

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({
    required this.total,
    required this.current,
    required this.isDark,
  });

  final int total;
  final int current;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        final size = isActive ? 12.0 : 8.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.dustyTeal
                : (isDark
                    ? AppColors.darkBorderColor
                    : AppColors.borderMedium),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

// ── Shared page template ───────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.body,
    this.extra,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String body;
  final Widget? extra;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: iconColor),
          ),
          const SizedBox(height: 32),
          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          // Body
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              height: 1.5,
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 24),
            extra!,
          ],
        ],
      ),
    );
  }
}

// ── Individual pages ───────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.l10n, required this.isDark});
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: Icons.celebration_rounded,
      iconColor: AppColors.warmAmber,
      iconBg: AppColors.warmAmberLight,
      title: l10n.onboardingWelcomeTitle,
      body: l10n.onboardingWelcomeBody,
      isDark: isDark,
    );
  }
}

class _ManualPage extends StatelessWidget {
  const _ManualPage({required this.l10n, required this.isDark});
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: Icons.edit_note_rounded,
      iconColor: AppColors.dustyTeal,
      iconBg: AppColors.dustyTealLight,
      title: l10n.onboardingManualTitle,
      body: l10n.onboardingManualBody,
      isDark: isDark,
    );
  }
}

class _PhotoPage extends StatelessWidget {
  const _PhotoPage({required this.l10n, required this.isDark});
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: Icons.photo_camera_rounded,
      iconColor: AppColors.sageGreen,
      iconBg: AppColors.sageGreenLight,
      title: l10n.onboardingPhotoTitle,
      body: l10n.onboardingPhotoBody,
      isDark: isDark,
    );
  }
}

class _VoicePage extends StatelessWidget {
  const _VoicePage({required this.l10n, required this.isDark});
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tipBg = isDark ? AppColors.darkSurfaceHigh : AppColors.warmAmberLight;
    final tipBorder =
        isDark ? AppColors.darkBorderColor : AppColors.warmAmber.withValues(alpha: 0.4);

    return _OnboardingPage(
      icon: Icons.mic_rounded,
      iconColor: AppColors.mutedTerra,
      iconBg: AppColors.mutedTerraLight,
      title: l10n.onboardingVoiceTitle,
      body: l10n.onboardingVoiceBody,
      isDark: isDark,
      extra: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tipBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_rounded,
                    size: 18, color: AppColors.warmAmber),
                const SizedBox(width: 8),
                Text(
                  l10n.onboardingVoiceImportant,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.warmAmber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // What to include
            _VoiceBullet(
              icon: Icons.attach_money_rounded,
              text: l10n.onboardingVoiceBulletAmount,
              isDark: isDark,
              theme: theme,
            ),
            _VoiceBullet(
              icon: Icons.category_rounded,
              text: l10n.onboardingVoiceBulletCategory,
              isDark: isDark,
              theme: theme,
            ),
            _VoiceBullet(
              icon: Icons.subdirectory_arrow_right_rounded,
              text: l10n.onboardingVoiceBulletSubcategory,
              isDark: isDark,
              theme: theme,
            ),
            _VoiceBullet(
              icon: Icons.description_rounded,
              text: l10n.onboardingVoiceBulletDescription,
              isDark: isDark,
              theme: theme,
            ),
            const SizedBox(height: 10),
            // Example
            Text(
              l10n.onboardingVoiceTip,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceBullet extends StatelessWidget {
  const _VoiceBullet({
    required this.icon,
    required this.text,
    required this.isDark,
    required this.theme,
  });
  final IconData icon;
  final String text;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkText : AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListPage extends StatelessWidget {
  const _ListPage({required this.l10n, required this.isDark});
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: Icons.list_alt_rounded,
      iconColor: AppColors.dustyTeal,
      iconBg: AppColors.dustyTealLight,
      title: l10n.onboardingListTitle,
      body: l10n.onboardingListBody,
      isDark: isDark,
    );
  }
}

class _ChartsPage extends StatelessWidget {
  const _ChartsPage({required this.l10n, required this.isDark});
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: Icons.bar_chart_rounded,
      iconColor: AppColors.sageGreen,
      iconBg: AppColors.sageGreenLight,
      title: l10n.onboardingChartsTitle,
      body: l10n.onboardingChartsBody,
      isDark: isDark,
    );
  }
}

class _DonePage extends StatelessWidget {
  const _DonePage({required this.l10n, required this.isDark});
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.sageGreen,
      iconBg: AppColors.sageGreenLight,
      title: l10n.onboardingDoneTitle,
      body: l10n.onboardingDoneBody,
      isDark: isDark,
    );
  }
}
