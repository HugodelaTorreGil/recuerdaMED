import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';

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
    final String localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    // Init settings
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    const initSettings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(initSettings);

    // Android channel
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Permissions
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  int _notifId(String medicationId, DateTime day, String timeHHmm) {
    // ID determinista (siempre el mismo para ese med+día+hora)
    // yyyymmdd como int + hash simple del medicationId
    final dayId =
        '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    final base = int.parse(dayId);
    final hash = medicationId.codeUnits.fold(0, (a, b) => (a + b) & 0x7fffffff);
    final t = timeHHmm.replaceAll(':', '');
    final timePart = int.tryParse(t) ?? 0;
    // Mezcla para reducir colisiones
    return (base + (hash % 100000) + timePart) & 0x7fffffff;
  }

  Future<void> scheduleDailyBetweenDates({
    required String medicationId,
    required String title, // e.g. "Paracetamol"
    required String body,  // e.g. "500mg"
    required String timeHHmm, // "08:00"
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final parts = timeHHmm.split(':');
    final hour = parts.length > 0 ? int.tryParse(parts[0]) ?? 8 : 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    // Normaliza a solo día
    DateTime start = DateTime(startDate.year, startDate.month, startDate.day);
    DateTime end = DateTime(endDate.year, endDate.month, endDate.day);

    if (end.isBefore(start)) end = start;

    // Limita para evitar programar miles (DAM: suficiente)
    const maxDays = 365;
    int count = 0;

    for (DateTime d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      count++;
      if (count > maxDays) break;

      final scheduled = tz.TZDateTime(
        tz.local,
        d.year,
        d.month,
        d.day,
        hour,
        minute,
      );

      // Si ya pasó esa hora hoy, no programes para hoy
      if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
        continue;
      }

      final id = _notifId(medicationId, d, timeHHmm);

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelScheduledBetweenDates({
    required String medicationId,
    required String timeHHmm,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    DateTime start = DateTime(startDate.year, startDate.month, startDate.day);
    DateTime end = DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) end = start;

    const maxDays = 365;
    int count = 0;

    for (DateTime d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      count++;
      if (count > maxDays) break;

      final id = _notifId(medicationId, d, timeHHmm);
      await _plugin.cancel(id);
    }
  }
}