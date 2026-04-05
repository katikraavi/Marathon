import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin _plugin;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize() async {
    _plugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(initSettings);

    // Create notification channel for Android only
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        description: AppConstants.notificationChannelDescription,
        importance: Importance.high,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> showWarningAlert({
    required int runnerId,
    required String reason,
  }) async {
    await _showNotification(
      id: runnerId,
      title: 'Warning: Runner $runnerId is at risk',
      body: reason,
      severity: NotificationSeverity.warning,
    );
  }

  Future<void> showEmergencyAlert({
    required int runnerId,
    required String reason,
  }) async {
    await _showNotification(
      id: runnerId,
      title: 'EMERGENCY: Runner $runnerId',
      body: reason,
      severity: NotificationSeverity.emergency,
    );
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required NotificationSeverity severity,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        channelDescription: AppConstants.notificationChannelDescription,
        importance: severity == NotificationSeverity.emergency
            ? Importance.max
            : Importance.high,
        priority: severity == NotificationSeverity.emergency
            ? Priority.max
            : Priority.high,
        enableVibration: true,
        playSound: true,
        tag: 'runner_health_alert',
        colorized: true,
        color: severity == NotificationSeverity.emergency
            ? const Color.fromARGB(255, 255, 0, 0)
            : const Color.fromARGB(255, 255, 193, 7),
      );

      const iOSDetails = DarwinNotificationDetails(
        presentSound: true,
        presentBadge: true,
        presentAlert: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _plugin.show(
        id,
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      // Notification service may not be available (e.g. Linux without DBus)
      // In-app snackbars are shown anyway as fallback, so we silently ignore
    }
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

enum NotificationSeverity { warning, emergency }
