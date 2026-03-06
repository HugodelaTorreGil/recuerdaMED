import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

//La mayor parte de esta clase (por no decir toda) me ha ayudado chatgpt porque era infumable lo de las notificaciones, me he pasado 3 dias intentando solucionar errores 
//y lo que hay hasta el momento funciona pero no bien del todo pero ya por culpa de android y no mía

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('NOTIF (bg) payload=${response.payload}');
}

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

  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    // 1) Timezones
    tzdata.initializeTimeZones();

    // En algunos móviles/plugins esto puede devolver algo que no sea String.
    // Yo lo fuerzo a String y si falla tiro de tz.local.
    String tzName;
    try {
      final dynamic tzInfo = await FlutterTimezone.getLocalTimezone();
      tzName = tzInfo.toString();
    } catch (_) {
      tzName = 'UTC';
    }

    try {
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      // Si el nombre no existe en la DB de timezones, uso el local por defecto.
      tz.setLocalLocation(tz.local);
    }

    // 2) Init settings
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    const initSettings = InitializationSettings(android: android, iOS: ios);

    // API NUEVA: settings: ...
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('NOTIF TAP payload=${response.payload}');
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // 3) Android channel + permisos
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_channel);

    // Android 13+ (POST_NOTIFICATIONS)
    await androidPlugin?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
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
    // API NUEVA: show requiere id: title: body: notificationDetails:
    await _plugin.show(
      id: 999999,
      title: 'Test RecuerdaMED',
      body: 'Si ves esto, permisos y canal OK',
      notificationDetails: NotificationDetails(
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
  // Scheduling
  // -------------------------------

  int _notifId(String medicationId, DateTime day, String timeHHmm) {
    // ID determinista para poder cancelar fácil: med + día + hora
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
    return <Duration>[Duration.zero]; // Diario / Semanal
  }

  Future<void> scheduleBetweenDates({
    required String medicationId,
    required String title,
    required String body,
    required String timeHHmm,
    required String frequency,
    int? weeklyDay, // 1..7 si Semanal
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final parts = timeHHmm.split(':');
    final baseHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
    final baseMinute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    final DateTime start = DateTime(startDate.year, startDate.month, startDate.day);
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
      debugPrint('Exact alarms NO permitidas: puede haber retrasos.');
    }

    for (DateTime d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      count++;
      if (count > maxDays) break;

      if (frequency == 'Semanal') {
        final wd = weeklyDay ?? start.weekday;
        if (d.weekday != wd) continue;
      }

      final baseTz = tz.TZDateTime(
        tz.local,
        d.year,
        d.month,
        d.day,
        baseHour,
        baseMinute,
      );

      for (final off in offsets) {
        final scheduled = baseTz.add(off);

        final dayOnly = DateTime(scheduled.year, scheduled.month, scheduled.day);
        if (dayOnly.isBefore(start) || dayOnly.isAfter(end)) continue;

        if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) continue;

        final hh = scheduled.hour.toString().padLeft(2, '0');
        final mm = scheduled.minute.toString().padLeft(2, '0');
        final hhmm = '$hh:$mm';

        final id = _notifId(medicationId, dayOnly, hhmm);

        debugPrint('SCHED local=$scheduled id=$id mode=$mode tz=${tz.local.name}');

        // API NUEVA: zonedSchedule con named params
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: NotificationDetails(
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
        );
      }
    }
  }

  Future<void> cancelBetweenDates({
    required String medicationId,
    required String timeHHmm,
    required String frequency,
    int? weeklyDay,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final parts = timeHHmm.split(':');
    final baseHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
    final baseMinute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    final DateTime start = DateTime(startDate.year, startDate.month, startDate.day);
    DateTime end = DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) end = start;

    final offsets = _offsetsForFrequency(frequency);

    const maxDays = 365;
    int count = 0;

    for (DateTime d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      count++;
      if (count > maxDays) break;

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

        //API NUEVA: cancel con named param
        await _plugin.cancel(id: id);
      }
    }
  }

  Future<void> scheduleTestIn2Minutes() async {
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = now.add(const Duration(minutes: 2));

    final canExact = await canExactAlarms();
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    debugPrint('TEST now=$now scheduled=$scheduled tz=${tz.local.name}');

    await _plugin.zonedSchedule(
      id: 123456,
      title: 'TEST PROGRAMADA',
      body: 'Debe salir en 2 minutos',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
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
    );
  }
}