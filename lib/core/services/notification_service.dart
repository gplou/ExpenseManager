import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:expense_manager/core/utils/app_logger.dart';

/// Wrapper fino sobre flutter_local_notifications, inyectable y mockeable en
/// tests (override de [notificationServiceProvider]).
///
/// Init perezoso: timezone + plugin se inicializan en el primer uso real, no
/// en main() — los usuarios sin recordatorios activados no pagan el coste.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (e) {
      // tz.local queda en UTC: hora desplazada pero sin crash.
      AppLogger.log('[Notifications] timezone init failed: $e');
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permisos iOS: se piden explícitamente en requestPermissions(), no
        // en el arranque.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  /// Pide el permiso de notificaciones (runtime en Android 13+ / iOS).
  Future<bool> requestPermissions() async {
    try {
      await _ensureInitialized();
      if (Platform.isIOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      // Pre-Android 13 no hay permiso runtime.
      return granted ?? true;
    } catch (e) {
      AppLogger.log('[Notifications] requestPermissions failed: $e');
      return false;
    }
  }

  /// Programa una notificación puntual. No-op si [when] ya pasó.
  /// inexactAllowWhileIdle: no requiere el permiso SCHEDULE_EXACT_ALARM y
  /// para un recordatorio "el día antes" la precisión de minutos es irrelevante.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String channelName,
    required String channelDescription,
  }) async {
    if (!when.isAfter(clock.now())) return;
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'recurring_reminders',
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());
