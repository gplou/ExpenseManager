import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/providers/locale_provider.dart';
import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/services/notification_service.dart';
import 'package:expense_manager/core/utils/app_logger.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

const _kRemindersKey = 'recurring_reminders_enabled';

/// Hora local del recordatorio (el día ANTES de `next_occurrence`).
const kReminderHour = 9;

/// Recordatorios locales de transacciones recurrentes (Plan 3 — A5).
///
/// Estado = toggle de ajustes (SharedPreferences, default off). [resync]
/// reprograma todos los avisos desde el repositorio: se llama al arrancar
/// ([recurringRemindersBootstrapProvider]) y tras cada CRUD/catch-up de
/// recurrentes — así no dependemos de BOOT_COMPLETED ni de mantener ids
/// sincronizados operación a operación.
class RecurringRemindersNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kRemindersKey) ?? false;
  }

  /// Activa los recordatorios pidiendo antes el permiso de notificaciones.
  /// Devuelve false si el permiso fue denegado (la UI avisa al usuario).
  Future<bool> enable() async {
    // Espera el build inicial: si aún está leyendo prefs, su resultado
    // sobreescribiría el estado que seteamos aquí.
    await future;
    final granted =
        await ref.read(notificationServiceProvider).requestPermissions();
    if (!granted) return false;
    await _persist(true);
    await resync();
    return true;
  }

  Future<void> disable() async {
    await future;
    await _persist(false);
    try {
      await ref.read(notificationServiceProvider).cancelAll();
    } catch (e) {
      AppLogger.log('[Reminders] cancelAll failed: $e');
    }
  }

  Future<void> _persist(bool enabled) async {
    state = AsyncData(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRemindersKey, enabled);
  }

  /// Reprograma todos los recordatorios desde cero (cancelAll + schedule).
  /// Nunca lanza: un fallo aquí no debe romper el CRUD que lo dispara.
  Future<void> resync() async {
    try {
      final enabled = await future;
      if (!enabled) return;
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final recurrings = await ref
          .read(recurringTransactionsRepositoryProvider)
          .getAllForUser();
      final locale = await ref.read(localeProvider.future);
      final l10n = lookupAppLocalizations(locale);
      final currencyCode = await ref.read(currencyProvider.future);
      final numFmt = await ref.read(numberFormatProvider.future);

      final service = ref.read(notificationServiceProvider);
      await service.cancelAll();
      for (final r in recurrings) {
        // Día antes de la próxima ocurrencia a las [kReminderHour]; DateTime
        // normaliza day 0 al último día del mes anterior.
        final when = DateTime(
          r.nextOccurrence.year,
          r.nextOccurrence.month,
          r.nextOccurrence.day - 1,
          kReminderHour,
        );
        final name = (r.description?.trim().isNotEmpty ?? false)
            ? r.description!.trim()
            : TransactionCategories.localizedName(r.category, l10n);
        final amountLabel =
            '${currencySymbol(currencyCode)}${formatAmount(r.amount, numFmt)}';
        await service.schedule(
          // Id estable derivado del id de la recurrente (1 aviso por recurrente).
          id: r.id.hashCode & 0x7fffffff,
          title: l10n.recurringReminderTitle,
          body: l10n.recurringReminderBody(name, amountLabel),
          when: when,
          channelName: l10n.recurringReminders,
          channelDescription: l10n.recurringRemindersSubtitle,
        );
      }
    } catch (e) {
      AppLogger.log('[Reminders] resync failed: $e');
    }
  }
}

final recurringRemindersProvider =
    AsyncNotifierProvider<RecurringRemindersNotifier, bool>(
  RecurringRemindersNotifier.new,
);

/// Reprograma los recordatorios al arrancar (y al cambiar de usuario).
/// Watcheado desde MyApp igual que offlineSyncServiceProvider.
final recurringRemindersBootstrapProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  // El locale afecta a los textos: re-programa si cambia.
  ref.watch(localeProvider.select((l) => l.value?.languageCode));
  await ref.read(recurringRemindersProvider.notifier).resync();
});

/// Helper para los call-sites de CRUD: fire-and-forget seguro.
void resyncRecurringReminders(Ref ref) {
  // resync() nunca lanza, pero por si el provider no puede construirse
  // (p. ej. prefs rotas) el callback de error evita un zone-error.
  ref
      .read(recurringRemindersProvider.notifier)
      .resync()
      .catchError((Object e) {
    AppLogger.log('[Reminders] resync dispatch failed: $e');
  });
}
