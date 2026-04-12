import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/currency_provider.dart';
import '../../core/widgets/ad_banner_footer.dart';
import '../subscription/subscription_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/number_format_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/utils/extensions.dart';
import '../../l10n/app_localizations.dart';
import '../tutorial/tutorial_notifier.dart';

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(
      themeModeProvider.select((v) => v.valueOrNull == ThemeMode.dark),
    );
    final currentLocale = ref.watch(localeProvider).valueOrNull;
    final currentLocaleName = supportedLocales
        .firstWhere(
          (l) => l.code == (currentLocale?.languageCode ?? 'es'),
          orElse: () => supportedLocales.first,
        )
        .name;
    final currentCurrencyCode =
        ref.watch(currencyProvider).valueOrNull ?? 'EUR';
    final currentCurrency = supportedCurrencies.firstWhere(
      (c) => c.code == currentCurrencyCode,
      orElse: () => supportedCurrencies.first,
    );
    final numFmtStyle = ref.watch(numberFormatProvider).valueOrNull ??
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
          ListTile(
            leading: const Icon(Icons.help_outline_rounded),
            title: Text(l10n.tutorialTitle),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              final tutNotifier = ref.read(tutorialProvider.notifier);
              Navigator.of(context).pop();
              Future<void>.delayed(
                const Duration(milliseconds: 350),
                tutNotifier.start,
              );
            },
          ),
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => context.push('/privacy-policy'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.termsOfService),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => context.push('/terms-of-service'),
          ),
        ],
      ),
    );
  }

  void _showNumberFormatSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        final current = ref.read(numberFormatProvider).valueOrNull ??
            NumberFormatStyle.dotDecimal;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
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
        final currentLocale = ref.read(localeProvider).valueOrNull;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
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
                      style: const TextStyle(fontSize: 24),
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
        final currentCode = ref.read(currencyProvider).valueOrNull ?? 'EUR';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
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
                            style: const TextStyle(fontSize: 24)),
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
