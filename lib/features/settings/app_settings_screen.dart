import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_manager/core/config/router.dart';
import 'package:expense_manager/core/providers/app_lock_provider.dart';
import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/services/analytics_service.dart';
import 'package:expense_manager/core/services/biometric_auth_service.dart';
import 'package:expense_manager/core/widgets/ad_banner_footer.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/core/providers/locale_provider.dart';
import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/providers/theme_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/recurring_reminders_provider.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/backup_flow.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(
      themeModeProvider.select((v) => v.value == ThemeMode.dark),
    );
    final currentLocale = ref.watch(localeProvider).value;
    final currentLocaleName = supportedLocales
        .firstWhere(
          (l) => l.code == (currentLocale?.languageCode ?? 'es'),
          orElse: () => supportedLocales.first,
        )
        .name;
    final currentCurrencyCode =
        ref.watch(currencyProvider).value ?? 'EUR';
    final currentCurrency = supportedCurrencies.firstWhere(
      (c) => c.code == currentCurrencyCode,
      orElse: () => supportedCurrencies.first,
    );
    final numFmtStyle = ref.watch(numberFormatProvider).value ??
        NumberFormatStyle.dotDecimal;
    final numFmtLabel = numFmtStyle == NumberFormatStyle.dotDecimal
        ? l10n.numberFormatDotDecimal
        : l10n.numberFormatCommaDecimal;

    return Scaffold(
      bottomNavigationBar: ref.watch(isProProvider) ? null : const AdBannerFooter(),
      appBar: AppBar(
        title: Text(l10n.appSettings),
      ),
      body: ListView(
        children: [
          const Gap(8),
          SwitchListTile(
            secondary: Icon(
              isDark
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
            title: Text(l10n.darkMode),
            value: isDark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(l10n.language),
            subtitle: Text(currentLocaleName),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _showLanguageSheet(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.attach_money_outlined),
            title: Text(l10n.currency),
            subtitle: Text(
                '${currentCurrency.flag} ${currentCurrency.code} — ${currentCurrency.name}'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _showCurrencySheet(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: Text(l10n.numberFormat),
            subtitle: Text(numFmtLabel),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _showNumberFormatSheet(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: Text(l10n.appLock),
            subtitle: Text(l10n.appLockSubtitle),
            value: ref.watch(appLockProvider).value ?? false,
            onChanged: (enable) => _toggleAppLock(context, ref, enable),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l10n.recurringReminders),
            subtitle: Text(l10n.recurringRemindersSubtitle),
            value: ref.watch(recurringRemindersProvider).value ?? false,
            onChanged: (enable) => _toggleReminders(context, ref, enable),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: Text(l10n.backupExport),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => runBackupExportFlow(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(l10n.backupImport),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => runBackupImportFlow(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => context.push(AppRoutes.privacyPolicy),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.termsOfService),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => context.push(AppRoutes.termsOfService),
          ),
          // Herramienta temporal de soporte (migración FREE→PRO huérfana).
          // Oculta en release desde 2026-06; eliminar pantalla + ruta cuando
          // pase una release sin que haga falta.
          if (kDebugMode) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Recuperar datos locales'),
              subtitle: const Text(
                'Sube transacciones guardadas en este dispositivo a tu cuenta',
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => context.push(AppRoutes.dataRecovery),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleAppLock(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (!enable) {
      await ref.read(appLockProvider.notifier).setEnabled(false);
      AnalyticsService.track(AnalyticsService.appLockToggled, {'enabled': false});
      return;
    }
    final biometrics = ref.read(biometricAuthServiceProvider);
    if (!await biometrics.isSupported()) {
      if (context.mounted) {
        context.showSnackbar(l10n.appLockUnavailable, isError: true);
      }
      return;
    }
    // Exigir una autenticación correcta antes de activar: evita que el usuario
    // se bloquee a sí mismo si su biometría/código no funciona.
    final ok = await biometrics.authenticate(l10n.appLockUnlockReason);
    if (!ok) return;
    await ref.read(appLockProvider.notifier).setEnabled(true);
    AnalyticsService.track(AnalyticsService.appLockToggled, {'enabled': true});
  }

  Future<void> _toggleReminders(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(recurringRemindersProvider.notifier);
    if (!enable) {
      await notifier.disable();
      AnalyticsService.track(
          AnalyticsService.recurringRemindersToggled, {'enabled': false});
      return;
    }
    final granted = await notifier.enable();
    if (!granted) {
      if (context.mounted) {
        context.showSnackbar(l10n.notificationsDenied, isError: true);
      }
      return;
    }
    AnalyticsService.track(
        AnalyticsService.recurringRemindersToggled, {'enabled': true});
  }

  void _showNumberFormatSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        final current = ref.read(numberFormatProvider).value ??
            NumberFormatStyle.dotDecimal;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(l10n.numberFormat,
                      style: ctx.textTheme.titleMedium),
                ),
                ListTile(
                  leading: const Icon(Icons.looks_one_outlined),
                  title: Text(l10n.numberFormatDotDecimal),
                  trailing: current == NumberFormatStyle.dotDecimal
                      ? Icon(Icons.check, color: ctx.colors.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(numberFormatProvider.notifier)
                        .setStyle(NumberFormatStyle.dotDecimal);
                    Navigator.of(ctx).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.looks_two_outlined),
                  title: Text(l10n.numberFormatCommaDecimal),
                  trailing: current == NumberFormatStyle.commaDecimal
                      ? Icon(Icons.check, color: ctx.colors.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(numberFormatProvider.notifier)
                        .setStyle(NumberFormatStyle.commaDecimal);
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        final currentLocale = ref.read(localeProvider).value;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child:
                      Text(l10n.language, style: ctx.textTheme.titleMedium),
                ),
                ...supportedLocales.map((locale) {
                  final isSelected =
                      currentLocale?.languageCode == locale.code;
                  return ListTile(
                    leading: Text(
                      locale.flag,
                      style: Theme.of(ctx).textTheme.bodyLarge,
                    ),
                    title: Text(locale.name),
                    trailing: isSelected
                        ? Icon(Icons.check, color: ctx.colors.primary)
                        : null,
                    onTap: () {
                      ref
                          .read(localeProvider.notifier)
                          .setLocale(Locale(locale.code));
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCurrencySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        final currentCode = ref.read(currencyProvider).value ?? 'EUR';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child:
                      Text(l10n.currency, style: ctx.textTheme.titleMedium),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: supportedCurrencies.map((c) {
                      final isSelected = currentCode == c.code;
                      return ListTile(
                        leading: Text(c.flag,
                            style: Theme.of(ctx).textTheme.bodyLarge),
                        title: Text('${c.code} — ${c.name}'),
                        subtitle: Text(c.symbol),
                        trailing: isSelected
                            ? Icon(Icons.check, color: ctx.colors.primary)
                            : null,
                        onTap: () {
                          ref
                              .read(currencyProvider.notifier)
                              .setCurrency(c.code);
                          Navigator.of(ctx).pop();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
