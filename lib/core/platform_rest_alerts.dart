import 'dart:developer' as developer;

import 'package:app_settings/app_settings.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const int restNotificationId = 4201;
const String restNotificationPayload = 'workout';

/// Android notification channel id for the given alert settings.
String channelFor({required bool sound, required bool vibrate}) {
  if (sound && vibrate) return 'rest_sound_vibrate';
  if (sound) return 'rest_sound';
  if (vibrate) return 'rest_vibrate';
  return 'rest_silent';
}

/// Notification body for the rest-over alert.
String restBodyFor(String exerciseName) =>
    'Time for your next set · $exerciseName';

/// Production [RestAlerts] backed by flutter_local_notifications and
/// audioplayers.
class PlatformRestAlerts implements RestAlerts {
  new();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  AudioPlayer? _player;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  void _log(String what, Object error, StackTrace stack) => developer.log(
    'RestAlerts.$what failed',
    name: 'fitapp.rest_alerts',
    error: error,
    stackTrace: stack,
  );

  @override
  Future<void> init({required void Function() onOpenWorkout}) async {
    try {
      tz_data.initializeTimeZones();
      void handle(NotificationResponse r) {
        if (r.payload == restNotificationPayload) onOpenWorkout();
      }

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: handle,
      );
      final android = _android;
      if (android != null) {
        for (final (sound, vibrate) in const [
          (true, true),
          (true, false),
          (false, true),
          (false, false),
        ]) {
          await android.createNotificationChannel(
            AndroidNotificationChannel(
              channelFor(sound: sound, vibrate: vibrate),
              'Rest timer (${sound ? 'sound' : 'no sound'}, '
              '${vibrate ? 'vibration' : 'no vibration'})',
              description: 'Alerts when your rest period ends',
              importance: Importance.high,
              playSound: sound,
              sound: sound
                  ? const RawResourceAndroidNotificationSound('rest_chime')
                  : null,
              enableVibration: vibrate,
            ),
          );
        }
      }
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if ((launch?.didNotificationLaunchApp ?? false) &&
          launch?.notificationResponse?.payload == restNotificationPayload) {
        SchedulerBinding.instance.addPostFrameCallback((_) => onOpenWorkout());
      }
    } on Object catch (e, s) {
      _log('init', e, s);
    }
  }

  @override
  Future<AlertStatus> status() async {
    try {
      final enabled = await _android?.areNotificationsEnabled();
      final exact = await _android?.canScheduleExactNotifications();
      var notifications = (enabled ?? true)
          ? AlertPermission.granted
          : AlertPermission.denied;
      final ios = _ios;
      if (ios != null) {
        final options = await ios.checkPermissions();
        notifications = (options?.isEnabled ?? false)
            ? AlertPermission.granted
            : AlertPermission.notAsked;
      }
      return AlertStatus(
        notifications: notifications,
        exactAlarms: exact ?? true,
      );
    } on Object catch (e, s) {
      _log('status', e, s);
      return const AlertStatus(
        notifications: AlertPermission.granted,
        exactAlarms: true,
      );
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      final android = _android;
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      return await _ios?.requestPermissions(alert: true, sound: true) ?? false;
    } on Object catch (e, s) {
      _log('requestNotificationPermission', e, s);
      return false;
    }
  }

  @override
  Future<void> openNotificationSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    } on Object catch (e, s) {
      _log('openNotificationSettings', e, s);
    }
  }

  @override
  Future<void> openExactAlarmSettings() async {
    try {
      await _android?.requestExactAlarmsPermission();
    } on Object catch (e, s) {
      _log('openExactAlarmSettings', e, s);
    }
  }

  @override
  Future<void> playChime() async {
    try {
      var player = _player;
      if (player == null) {
        player = AudioPlayer();
        _player = player;
        await player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              usageType: AndroidUsageType.notificationEvent,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
            iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          ),
        );
        await player.setReleaseMode(ReleaseMode.stop);
      }
      await player.play(AssetSource('sounds/rest_chime.ogg'));
    } on Object catch (e, s) {
      _log('playChime', e, s);
    }
  }

  @override
  Future<void> schedule({
    required DateTime at,
    required String exerciseName,
    required bool sound,
    required bool vibrate,
  }) async {
    try {
      await _plugin.cancel(id: restNotificationId);
      if (!at.isAfter(DateTime.now())) return;
      final exact = await _android?.canScheduleExactNotifications();
      final channel = channelFor(sound: sound, vibrate: vibrate);
      await _plugin.zonedSchedule(
        id: restNotificationId,
        title: 'Rest over',
        body: restBodyFor(exerciseName),
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel,
            'Rest timer',
            channelDescription: 'Alerts when your rest period ends',
            importance: Importance.high,
            priority: Priority.high,
            playSound: sound,
            enableVibration: vibrate,
            sound: sound
                ? const RawResourceAndroidNotificationSound('rest_chime')
                : null,
          ),
          iOS: DarwinNotificationDetails(presentSound: sound),
        ),
        androidScheduleMode: exact ?? true
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: restNotificationPayload,
      );
    } on Object catch (e, s) {
      _log('schedule', e, s);
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _plugin.cancel(id: restNotificationId);
    } on Object catch (e, s) {
      _log('cancel', e, s);
    }
  }
}
