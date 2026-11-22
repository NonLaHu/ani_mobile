import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Cross-platform notification service managing background download alerts and progress indicators.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open ani-mobile',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        linux: linuxSettings,
      );

      await _notificationsPlugin.initialize(settings: initSettings);
      _isInitialized = true;
    } catch (e) {
      print('NotificationService init error (ignored gracefully): $e');
    }
  }

  /// Displays or updates an active download progress notification
  Future<void> showDownloadProgress({
    required int id,
    required String title,
    required String body,
    required int progressPercent, // 0 to 100
  }) async {
    if (!_isInitialized) await init();

    try {
      final androidDetails = AndroidNotificationDetails(
        'ani_mobile_downloads_progress',
        'Download Progress',
        channelDescription: 'Ongoing anime video download progress',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: 100,
        progress: progressPercent,
        ongoing: true,
      );

      const linuxDetails = LinuxNotificationDetails();

      final details = NotificationDetails(
        android: androidDetails,
        linux: linuxDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      print('Progress notification error: $e');
    }
  }

  /// Displays notification when an episode download successfully finishes
  Future<void> showDownloadCompleted({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await init();

    try {
      const androidDetails = AndroidNotificationDetails(
        'ani_mobile_downloads_complete',
        'Completed Downloads',
        channelDescription: 'Notifications for finished anime episode downloads',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: false,
      );

      const linuxDetails = LinuxNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        linux: linuxDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      print('Completion notification error: $e');
    }
  }

  /// Cancels an active notification by ID
  Future<void> cancel(int id) async {
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (_) {}
  }
}
