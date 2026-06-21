import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../data/models/practice.dart';

class Reminder {
  final int id;
  final int hour;
  final int minute;
  final bool enabled;

  const Reminder({
    required this.id,
    required this.hour,
    required this.minute,
    required this.enabled,
  });

  Reminder copyWith({bool? enabled, int? hour, int? minute}) => Reminder(
        id: id,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'hour': hour, 'minute': minute, 'enabled': enabled};

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as int,
        hour: j['hour'] as int,
        minute: j['minute'] as int,
        enabled: j['enabled'] as bool,
      );

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class ReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Request notification permission (Android 13+)
    await androidImpl?.requestNotificationsPermission();

    // Request exact alarm permission (Android 12+)
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
  }

  static Future<List<Reminder>> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('reminders') ?? [];
    return raw
        .map((s) => Reminder.fromJson(json.decode(s) as Map<String, dynamic>))
        .toList();
  }

  // Saves to prefs and reschedules. Returns normally even if scheduling fails.
  static Future<void> saveReminders(List<Reminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'reminders', reminders.map((r) => json.encode(r.toJson())).toList());
    for (final r in reminders) {
      if (r.enabled) {
        await _schedule(r);
      } else {
        try {
          await _plugin.cancel(id: r.id);
        } catch (_) {}
      }
    }
  }

  static Future<void> _schedule(Reminder r) =>
      _scheduleWithContent(r, '功课提醒', '该做今日功课了 🙏', const []);

  static Future<void> _scheduleWithContent(
      Reminder r, String title, String body, List<String> lines) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, r.hour, r.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final styleInformation = lines.isNotEmpty
        ? InboxStyleInformation(
            lines,
            htmlFormatLines: false,
            contentTitle: '待完成：',
          )
        : null;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mala_reminder',
        '功课提醒',
        channelDescription: '每日功课提醒',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: styleInformation,
      ),
      iOS: DarwinNotificationDetails(
        subtitle: lines.isNotEmpty ? lines.join('、') : null,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id: r.id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// Called whenever today's practice data changes. Reschedules all enabled
  /// reminders with up-to-date content showing which practices are incomplete.
  static Future<void> updateDailyStatus(
      List<Practice> practices, List<PracticeLog> todayLogs) async {
    if (!_initialized) return;
    final reminders = await loadReminders();
    if (reminders.isEmpty) return;

    // Don't update if practices haven't loaded yet — avoids overwriting with blank content
    if (practices.isEmpty) return;

    final countById = <String, int>{};
    for (final log in todayLogs) {
      countById[log.practiceId] = (countById[log.practiceId] ?? 0) + log.count;
    }

    final incomplete = practices.where((p) {
      if (!p.hasDaily) return false;
      final cnt = countById[p.id] ?? 0;
      if (p.goalType == GoalType.checkin) return cnt < 1;
      return p.targetCount > 0 && cnt < p.targetCount;
    }).toList();

    final String title;
    final String body;
    final List<String> lines;
    if (incomplete.isEmpty && practices.any((p) => p.hasDaily)) {
      title = '功课提醒';
      body = '今日功课已全部完成 🎉';
      lines = const [];
    } else if (incomplete.isEmpty) {
      title = '功课提醒';
      body = '该做今日功课了 🙏';
      lines = const [];
    } else {
      title = '修行提醒（还有 ${incomplete.length} 项）';
      body = incomplete.map((p) => p.name).join('、');
      lines = incomplete.map((p) => p.name).toList();
    }

    for (final r in reminders) {
      if (!r.enabled) continue;
      try {
        await _scheduleWithContent(r, title, body, lines);
      } catch (_) {}
    }
  }

  static int _nextId(List<Reminder> existing) {
    if (existing.isEmpty) return 1;
    return existing.map((r) => r.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  static Future<List<Reminder>> addReminder(
      List<Reminder> existing, int hour, int minute) async {
    final r = Reminder(
        id: _nextId(existing), hour: hour, minute: minute, enabled: true);
    final updated = [...existing, r];
    await saveReminders(updated);
    return updated;
  }

  static Future<List<Reminder>> toggleReminder(
      List<Reminder> existing, int id, bool enabled) async {
    final updated = existing
        .map((r) => r.id == id ? r.copyWith(enabled: enabled) : r)
        .toList();
    await saveReminders(updated);
    return updated;
  }

  static Future<List<Reminder>> deleteReminder(
      List<Reminder> existing, int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
    final updated = existing.where((r) => r.id != id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'reminders', updated.map((r) => json.encode(r.toJson())).toList());
    return updated;
  }
}
