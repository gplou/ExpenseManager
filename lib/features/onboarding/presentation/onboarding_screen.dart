import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/services/analytics_service.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/onboarding/providers/onboarding_provider.dart';

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

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await ref.read(onboardingProvider.notifier).markSeen();
      },
      child: Scaffold(
        backgroundColor: context.appColors.background,
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
                        color: context.appColors.textMuted,
                      ),
                    ),
                    // Skip button (hidden on last page)
                    if (_currentPage < _totalPages - 1)
                      TextButton(
                        onPressed: _finish,
                        child: Text(
                          l10n.tutorialSkip,
                          style: TextStyle(
                            color: context.appColors.textMuted,
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
                    _WelcomePage(l10n: l10n),
                    _ManualPage(l10n: l10n),
                    _PhotoPage(l10n: l10n),
                    _VoicePage(l10n: l10n),
                    _ListPage(l10n: l10n),
                    _ChartsPage(l10n: l10n),
                    _DonePage(l10n: l10n),
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
  const _DotsIndicator({required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22.0 : 6.0,
          height: 6.0,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.dustyTeal
                : context.appColors.borderStrong,
            borderRadius: BorderRadius.circular(3),
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
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String body;
  final Widget? extra;

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
              color: context.appColors.text,
            ),
          ),
          const SizedBox(height: 16),
          // Body
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: context.appColors.textMuted,
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
  const _WelcomePage({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: PhosphorIcons.confetti(),
      iconColor: AppColors.warmAmber,
      iconBg: AppColors.warmAmberLight,
      title: l10n.onboardingWelcomeTitle,
      body: l10n.onboardingWelcomeBody,
    );
  }
}

class _ManualPage extends StatelessWidget {
  const _ManualPage({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: PhosphorIcons.notePencil(),
      iconColor: AppColors.dustyTeal,
      iconBg: AppColors.dustyTealLight,
      title: l10n.onboardingManualTitle,
      body: l10n.onboardingManualBody,
    );
  }
}

class _PhotoPage extends StatelessWidget {
  const _PhotoPage({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: PhosphorIcons.camera(),
      iconColor: AppColors.sageGreen,
      iconBg: AppColors.sageGreenLight,
      title: l10n.onboardingPhotoTitle,
      body: l10n.onboardingPhotoBody,
    );
  }
}

class _VoicePage extends StatelessWidget {
  const _VoicePage({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tipBg = context.appColors.raised;
    final tipBorder = context.appColors.borderStrong;

    return _OnboardingPage(
      icon: PhosphorIcons.microphone(),
      iconColor: AppColors.mutedTerra,
      iconBg: AppColors.mutedTerraLight,
      title: l10n.onboardingVoiceTitle,
      body: l10n.onboardingVoiceBody,
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
                Icon(PhosphorIcons.lightbulb(),
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
            _VoiceBullet(
              icon: PhosphorIcons.coins(),
              text: l10n.onboardingVoiceBulletAmount,
              theme: theme,
            ),
            _VoiceBullet(
              icon: PhosphorIcons.squaresFour(),
              text: l10n.onboardingVoiceBulletCategory,
              theme: theme,
            ),
            _VoiceBullet(
              icon: PhosphorIcons.arrowElbowDownRight(),
              text: l10n.onboardingVoiceBulletSubcategory,
              theme: theme,
            ),
            _VoiceBullet(
              icon: PhosphorIcons.fileText(),
              text: l10n.onboardingVoiceBulletDescription,
              theme: theme,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.onboardingVoiceTip,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.appColors.textMuted,
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
    required this.theme,
  });
  final IconData icon;
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.appColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.appColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListPage extends StatelessWidget {
  const _ListPage({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: PhosphorIcons.listBullets(),
      iconColor: AppColors.dustyTeal,
      iconBg: AppColors.dustyTealLight,
      title: l10n.onboardingListTitle,
      body: l10n.onboardingListBody,
    );
  }
}

class _ChartsPage extends StatelessWidget {
  const _ChartsPage({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: PhosphorIcons.chartBar(),
      iconColor: AppColors.sageGreen,
      iconBg: AppColors.sageGreenLight,
      title: l10n.onboardingChartsTitle,
      body: l10n.onboardingChartsBody,
    );
  }
}

class _DonePage extends StatelessWidget {
  const _DonePage({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      icon: PhosphorIcons.checkCircle(),
      iconColor: AppColors.sageGreen,
      iconBg: AppColors.sageGreenLight,
      title: l10n.onboardingDoneTitle,
      body: l10n.onboardingDoneBody,
    );
  }
}
