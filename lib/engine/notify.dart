import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../l10n2.dart';

class Notifier {
  static final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _fln.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _fln.initialize(const InitializationSettings(android: android));
      await _android?.createNotificationChannel(AndroidNotificationChannel(
        'signals',
        t2('sig_notif_channel'),
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
      _ready = true;
    } catch (_) {}
  }

  static Future<void> requestNotifications() async {
    await init();
    try {
      await _android?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<void> requestBattery() async {
    try {
      final ok = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!ok) await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    } catch (_) {}
  }

  static Future<void> show(int id, String title, String body) async {
    await init();
    try {
      await _fln.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'signals',
            t2('sig_notif_channel'),
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
      );
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
void fgStartCallback() {
  FlutterForegroundTask.setTaskHandler(_IdleHandler());
}

class _IdleHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

class FgService {
  static bool _inited = false;

  static void _init() {
    if (_inited) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'monitor_service',
        channelName: 'Auto analysis',
        channelDescription: 'Auto analysis is running',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions:
          const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _inited = true;
  }

  static Future<void> start(int pairs) async {
    _init();
    try {
      await FlutterForegroundTask.startService(
        serviceId: 777,
        notificationTitle: t2('nt_fg_title'),
        notificationText: t2('nt_fg_text', '$pairs'),
        callback: fgStartCallback,
      );
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}
  }
}
