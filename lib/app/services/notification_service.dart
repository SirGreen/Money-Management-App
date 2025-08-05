// lib/app/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'daily_reminders_channel';
  static const String channelName = 'Daily Reminders';
  static const String channelDescription =
      'Channel for daily reminder notifications';

  static const int dailyLoginReminderId = 99;
  static const int incompleteItemsReminderId = 98;

  Future<void> initForApp() async {
    await _initializePlugin();

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.defaultImportance,
      ),
    );
  }

  Future<bool> requestPermissions() async {
    final status = await Permission.notification.request();


    return status.isGranted || status.isProvisional;
  }

  Future<bool> areNotificationsEnabled() async {
    if (Platform.isIOS) {
      final status = await Permission.notification.status;
      return status.isGranted || status.isProvisional;
    } else if (Platform.isAndroid) {
      final bool? status = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      return status ?? false;
    }

    return false;
  }

  Future<void> _initializePlugin() async {
    tz.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleDailyLoginReminder({
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    tz.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    print('--- Daily Login Reminder ---');
    print(
      'Cancelling any existing reminder with ID $dailyLoginReminderId and rescheduling.',
    );
    print(
      'Next reminder scheduled for: $scheduledDate, repeating daily at this time.',
    );
    print('----------------------------');

    await _notificationsPlugin.zonedSchedule(
      dailyLoginReminderId,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleIncompleteItemsReminder({
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    tz.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      print(
        'Incomplete items reminder time for today has already passed. Not scheduling.',
      );
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    print('--- Incomplete Items Reminder ---');
    print('Scheduling one-time reminder for: $scheduledDate');
    print('---------------------------------');

    await _notificationsPlugin.zonedSchedule(
      incompleteItemsReminderId,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelIncompleteItemsReminder() async {
    await _notificationsPlugin.cancel(incompleteItemsReminderId);
    print(
      'Cancelled incomplete items reminder with ID: $incompleteItemsReminderId',
    );
  }

  Future<void> cancelDailyLoginReminder() async {
    await _notificationsPlugin.cancel(dailyLoginReminderId);
    print('Cancelled daily login reminder with ID: $dailyLoginReminderId');
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    tz.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
