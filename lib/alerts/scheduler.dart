import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'planner.dart';

class AlertPermissions {
  const AlertPermissions({required this.notifications, required this.exactAlarms});
  final bool notifications;
  final bool exactAlarms;
  bool get all => notifications && exactAlarms;
}

/// Memasang pengingat di Android. Diganti palsu di tes.
abstract class AlertScheduler {
  Future<void> init({required String timeZone, required void Function(String payload) onTap});

  /// Payload notifikasi yang membuka aplikasi dari keadaan mati, bila ada.
  Future<String?> launchPayload();

  /// Samakan pengingat berulang di Android dengan [plan]; yang tidak ada di rencana dibatalkan.
  Future<void> sync(List<PlannedAlert> plan);

  Future<void> scheduleBreak({required int minutes, required String title, required String body});
  Future<void> cancelBreak();
  Future<void> showNow({required String title, required String body});

  Future<AlertPermissions> permissions();
  Future<AlertPermissions> requestPermissions();
  Future<void> openNotificationSettings();
}

class LocalAlertScheduler implements AlertScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channels = {
    AlertChannel.tayang: AndroidNotificationDetails(
      'tayang',
      'Pengingat tayang',
      channelDescription: 'Pengingat saat drama favorit akan tayang',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      icon: 'ic_stat_lantern',
    ),
    AlertChannel.istirahat: AndroidNotificationDetails(
      'istirahat',
      'Istirahat mata',
      channelDescription: 'Pengingat beristirahat setelah menonton lama',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      icon: 'ic_stat_lantern',
    ),
    AlertChannel.tidur: AndroidNotificationDetails(
      'tidur',
      'Waktu tidur',
      channelDescription: 'Pengingat harian untuk berhenti menonton dan tidur',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      icon: 'ic_stat_lantern',
    ),
  };

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> init({required String timeZone, required void Function(String payload) onTap}) async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(timeZone));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_lantern')),
      onDidReceiveNotificationResponse: (r) {
        final p = r.payload;
        if (p != null) onTap(p);
      },
    );
    _ready = true;
  }

  @override
  Future<String?> launchPayload() async {
    if (!_ready) return null;
    final d = await _plugin.getNotificationAppLaunchDetails();
    return (d?.didNotificationLaunchApp ?? false) ? d?.notificationResponse?.payload : null;
  }

  Future<AndroidScheduleMode> _mode() async {
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    return exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  tz.TZDateTime _next(int? weekday, int minuteOfDay) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, minuteOfDay ~/ 60, minuteOfDay % 60);
    if (weekday != null) t = t.add(Duration(days: (weekday - t.weekday) % 7));
    if (!t.isAfter(now)) t = t.add(Duration(days: weekday == null ? 1 : 7));
    return t;
  }

  @override
  Future<void> sync(List<PlannedAlert> plan) async {
    if (!_ready) return;
    final wanted = {for (final a in plan) a.id};
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id != kBreakAlertId && !wanted.contains(p.id)) await _plugin.cancel(id: p.id);
    }
    final mode = await _mode();
    for (final a in plan) {
      try {
        await _plugin.zonedSchedule(
          id: a.id,
          title: a.title,
          body: a.body,
          scheduledDate: _next(a.weekday, a.minuteOfDay),
          notificationDetails: NotificationDetails(android: _channels[a.channel]),
          androidScheduleMode: mode,
          matchDateTimeComponents:
              a.weekday == null ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime,
          payload: a.payload,
        );
      } catch (e) {
        debugPrint('Gagal memasang pengingat ${a.id}: $e');
      }
    }
  }

  @override
  Future<void> scheduleBreak({required int minutes, required String title, required String body}) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id: kBreakAlertId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes)),
        notificationDetails: NotificationDetails(android: _channels[AlertChannel.istirahat]),
        androidScheduleMode: await _mode(),
      );
    } catch (e) {
      debugPrint('Gagal memasang pengingat istirahat: $e');
    }
  }

  @override
  Future<void> cancelBreak() async {
    if (_ready) await _plugin.cancel(id: kBreakAlertId);
  }

  @override
  Future<void> showNow({required String title, required String body}) async {
    if (!_ready) return;
    await _plugin.show(
      id: 4,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: _channels[AlertChannel.tayang]),
    );
  }

  @override
  Future<AlertPermissions> permissions() async {
    final a = _android;
    return AlertPermissions(
      notifications: await a?.areNotificationsEnabled() ?? false,
      exactAlarms: await a?.canScheduleExactNotifications() ?? false,
    );
  }

  @override
  Future<AlertPermissions> requestPermissions() async {
    final a = _android;
    await a?.requestNotificationsPermission();
    if (!(await a?.canScheduleExactNotifications() ?? true)) {
      await a?.requestExactAlarmsPermission();
    }
    return permissions();
  }

  @override
  Future<void> openNotificationSettings() async {
    await _plugin.openAppNotificationSettings();
  }
}
