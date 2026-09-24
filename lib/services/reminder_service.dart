import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ScheduledReminder {
  final int id;
  final DateTime fireTime;
  final String label;

  const ScheduledReminder({
    required this.id,
    required this.fireTime,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fireTime': fireTime.toIso8601String(),
    'label': label,
  };

  factory ScheduledReminder.fromJson(Map<String, dynamic> json) {
    return ScheduledReminder(
      id: json['id'] as int,
      fireTime: DateTime.parse(json['fireTime'] as String),
      label: json['label'] as String,
    );
  }
}

class ReminderService {
  static const String _channelId = 'follow_up_reminders';
  static const String _channelName = 'Follow-up reminders';
  static const String _storageKey = 'felivet_scheduled_reminders';
  static const int _firstNotificationId = 1001;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _plugin.initialize(settings: settings);
    await requestPermissions();
  }

  static Future<bool> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await android?.requestNotificationsPermission();
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return (androidGranted ?? iosGranted ?? true);
  }

  static Future<bool> notificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  static Future<void> openNotificationSettings() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.openAppNotificationSettings();
  }

  static Future<List<ScheduledReminder>> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (item) => ScheduledReminder.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveReminders(List<ScheduledReminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(reminders.map((reminder) => reminder.toJson()).toList()),
    );
  }

  static Future<List<ScheduledReminder>> reconcileReminders() async {
    final stored = await loadReminders();
    final pending = await _plugin.pendingNotificationRequests();
    final pendingIds = pending.map((item) => item.id).toSet();
    final now = DateTime.now();
    final active =
        stored
            .where(
              (reminder) =>
                  reminder.fireTime.isAfter(now) &&
                  pendingIds.contains(reminder.id),
            )
            .toList()
          ..sort((a, b) => a.fireTime.compareTo(b.fireTime));
    await _saveReminders(active);
    return active;
  }

  static Future<ScheduledReminder> scheduleReminder(
    Duration delay, {
    String? catName,
  }) async {
    if (delay < const Duration(minutes: 1)) {
      throw ArgumentError('Reminder must be at least one minute from now.');
    }

    final notificationId = await _nextNotificationId();
    final subject = catName == null || catName.trim().isEmpty
        ? 'your cat\'s skin'
        : '${catName.trim()}\'s skin';
    final fireTime = DateTime.now().add(delay);
    final label = 'Check $subject';
    final scheduledDate = tz.TZDateTime.from(fireTime, tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Reminders to check your cat after a scan',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Time to check $subject again',
      body: 'Take a new photo to see how your cat\'s skin is doing.',
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    final reminders = await loadReminders();
    final reminder = ScheduledReminder(
      id: notificationId,
      fireTime: fireTime,
      label: label,
    );
    await _saveReminders([...reminders, reminder]);
    return reminder;
  }

  static Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id: id);
    final reminders = await loadReminders();
    await _saveReminders(
      reminders.where((reminder) => reminder.id != id).toList(),
    );
  }

  static Future<int> _nextNotificationId() async {
    final reminders = await loadReminders();
    var id = _firstNotificationId;
    final used = reminders.map((reminder) => reminder.id).toSet();
    while (used.contains(id)) {
      id++;
    }
    return id;
  }
}
