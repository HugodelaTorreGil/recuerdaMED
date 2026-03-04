import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'med_reminders',
    'Recordatorios de medicación',
    description: 'Notificaciones para recordar tomas de medicación',
    importance: Importance.max,
  );

  Future<void> init() async {
    // Timezone
    tzdata.initializeTimeZones();

    // Trabajamos en UTC y convertimos desde hora local al programar
    tz.setLocalLocation(tz.UTC);

    // Init settings
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    const initSettings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(initSettings);

    // Android channel
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_channel);

    // Permissions
    await androidPlugin?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // -------------------------------
  // DEBUG helpers
  // -------------------------------

  Future<int> pendingCount() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  Future<void> showNowTest() async {
    await _plugin.show(
      999999,
      'Test RecuerdaMed',
      'Si ves esto, permisos y canal OK',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // -------------------------------
  // Exact alarms + settings
  // -------------------------------

  Future<bool> canExactAlarms() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  Future<void> openExactAlarmsSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  Future<void> openBatteryOptimizationSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  // -------------------------------
  // Scheduling logic
  // -------------------------------

  int _notifId(String medicationId, DateTime day, String timeHHmm) {
    final dayId =
        '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    final base = int.parse(dayId);
    final hash = medicationId.codeUnits.fold(0, (a, b) => (a + b) & 0x7fffffff);
    final t = timeHHmm.replaceAll(':', '');
    final timePart = int.tryParse(t) ?? 0;
    return (base + (hash % 100000) + timePart) & 0x7fffffff;
  }

  List<Duration> _offsetsForFrequency(String frequency) {
    if (frequency == 'Cada 12 horas') {
      return <Duration>[Duration.zero, const Duration(hours: 12)];
    }
    if (frequency == 'Cada 8 horas') {
      return <Duration>[
        Duration.zero,
        const Duration(hours: 8),
        const Duration(hours: 16),
      ];
    }
    // Diario / Semanal / otros
    return <Duration>[Duration.zero];
  }

  Future<void> scheduleDailyBetweenDates({
    required String medicationId,
    required String title,
    required String body,
    required String timeHHmm,
    required String frequency,
    int? weeklyDay, // 1..7 (solo si Semanal)
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final parts = timeHHmm.split(':');
    final baseHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
    final baseMinute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    DateTime start = DateTime(startDate.year, startDate.month, startDate.day);
    DateTime end = DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) end = start;

    final offsets = _offsetsForFrequency(frequency);

    const maxDays = 365;
    int count = 0;

    final canExact = await canExactAlarms();
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    if (!canExact) {
      debugPrint(
        'Exact alarms NO permitidas: Android puede retrasar o saltarse recordatorios.',
      );
    }

    for (DateTime d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      count++;
      if (count > maxDays) break;

      // Semanal: solo el weekday elegido (o el weekday del startDate si no viene)
      if (frequency == 'Semanal') {
        final wd = weeklyDay ?? start.weekday;
        if (d.weekday != wd) continue;
      }

      // Base local (hora local del móvil)
      final baseLocal = DateTime(d.year, d.month, d.day, baseHour, baseMinute);

      for (final off in offsets) {
        final scheduledLocal = baseLocal.add(off);

        // Si al sumar horas pasamos de día, comprobamos rango
        final dayOnly = DateTime(
          scheduledLocal.year,
          scheduledLocal.month,
          scheduledLocal.day,
        );
        if (dayOnly.isBefore(start) || dayOnly.isAfter(end)) continue;

        // Si ya pasó en hora local, no programar
        if (scheduledLocal.isBefore(DateTime.now())) continue;

        final hh = scheduledLocal.hour.toString().padLeft(2, '0');
        final mm = scheduledLocal.minute.toString().padLeft(2, '0');
        final hhmm = '$hh:$mm';

        final id = _notifId(medicationId, dayOnly, hhmm);

        // Convertimos local -> UTC y lo programamos en tz.UTC
        final scheduledUtc = scheduledLocal.toUtc();
        final scheduledTz = tz.TZDateTime.from(scheduledUtc, tz.UTC);

        debugPrint(
          'SCHEDULING freq=$frequency local=$scheduledLocal utc=$scheduledUtc id=$id mode=$mode',
        );

        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledTz,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  Future<void> cancelScheduledBetweenDates({
    required String medicationId,
    required String timeHHmm,
    required String frequency,
    int? weeklyDay, // 1..7 (solo si Semanal)
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final parts = timeHHmm.split(':');
    final baseHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
    final baseMinute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    DateTime start = DateTime(startDate.year, startDate.month, startDate.day);
    DateTime end = DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) end = start;

    final offsets = _offsetsForFrequency(frequency);

    const maxDays = 365;
    int count = 0;

    for (DateTime d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      count++;
      if (count > maxDays) break;

      // Semanal: solo el weekday elegido (o el weekday del startDate si no viene)
      if (frequency == 'Semanal') {
        final wd = weeklyDay ?? start.weekday;
        if (d.weekday != wd) continue;
      }

      final baseLocal = DateTime(d.year, d.month, d.day, baseHour, baseMinute);

      for (final off in offsets) {
        final scheduledLocal = baseLocal.add(off);

        final dayOnly = DateTime(
          scheduledLocal.year,
          scheduledLocal.month,
          scheduledLocal.day,
        );
        if (dayOnly.isBefore(start) || dayOnly.isAfter(end)) continue;

        final hh = scheduledLocal.hour.toString().padLeft(2, '0');
        final mm = scheduledLocal.minute.toString().padLeft(2, '0');
        final hhmm = '$hh:$mm';

        final id = _notifId(medicationId, dayOnly, hhmm);
        await _plugin.cancel(id);
      }
    }
  }

  Future<void> scheduleTestIn2Minutes() async {
    final nowLocal = DateTime.now();
    final scheduledLocal = nowLocal.add(const Duration(minutes: 2));

    final canExact = await canExactAlarms();
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final scheduledUtc = scheduledLocal.toUtc();
    final scheduledTz = tz.TZDateTime.from(scheduledUtc, tz.UTC);

    debugPrint(
      'TEST SCHED local=$nowLocal scheduledLocal=$scheduledLocal scheduledUtc=$scheduledUtc canExact=$canExact mode=$mode',
    );

    await _plugin.zonedSchedule(
      123456,
      'TEST PROGRAMADA',
      'Debe salir en 2 minutos',
      scheduledTz,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    final p = await pendingCount();
    debugPrint('PENDING AFTER TEST=$p');
  }
}