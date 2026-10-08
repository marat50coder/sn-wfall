import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'aurora_vault.dart';
import 'prism_agent.dart';

// ============================================================
//  SignalRelay — Firebase Messaging + local notifications
// ============================================================
//  Cold-start push taps (app killed) are stashed in the vault
//  so the boot pipeline picks them up on the next frame. Warm
//  taps (background/foreground) deliver through [onTargetArrived]
//  and are NOT persisted — single-shot delivery.
//
//  The channel id is Snowfall-specific (`snf_notice_chan`) and
//  matches `default_notification_channel_id` in AndroidManifest.
// ============================================================

const String kNoticeChannelId = 'snf_notice_chan';
const String kNoticeChannelName = 'Snowfall Alerts';
const String _flameIcon = '@drawable/ic_notification';

@pragma('vm:entry-point')
Future<void> _bgSink(RemoteMessage message) async {
  // OS renders the notification; the tap is handled on resume.
}

class SignalRelay {
  SignalRelay(this._vault);

  final AuroraVault _vault;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _messaging;
  String? _token;
  bool _wired = false;

  void Function(String url)? onTargetArrived;
  void Function(String token)? onTokenRolled;

  String? get token => _token;

  Future<void> ignite() async {
    if (_wired) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_bgSink);

      await _wireLocal();

      _token = await _messaging!.getToken();
      _messaging!.onTokenRefresh.listen((String t) {
        _token = t;
        onTokenRolled?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final RemoteMessage? initial = await _messaging!.getInitialMessage();
      if (initial != null) _onColdTap(initial);

      _wired = true;
    } catch (_) {
      // Firebase missing — push stays dormant.
    }
  }

  Future<void> _wireLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_flameIcon);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? payload = r.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(payload) as Map<String, dynamic>;
          final String? url = data['url'] as String?;
          if (url != null && url.isNotEmpty) onTargetArrived?.call(url);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          kNoticeChannelId,
          kNoticeChannelName,
          description: 'Snowfall bonus offers and promos',
          importance: Importance.high,
        ),
      );
    }
  }

  Future<bool> requestPushPermission() async {
    if (_messaging == null) return false;
    final NotificationSettings settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus s = settings.authorizationStatus;
    final bool granted = s == AuthorizationStatus.authorized ||
        s == AuthorizationStatus.provisional;
    await _vault.markPushGranted(granted);
    if (s == AuthorizationStatus.denied) {
      await _vault.markPushOsBlocked();
    }
    return granted;
  }

  void _onForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? imageUrl = n.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _pullImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kNoticeChannelId,
          kNoticeChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _flameIcon,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      kNoticeChannelId,
      kNoticeChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _flameIcon,
    );

    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onColdTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      _vault.parkColdUrl(url);
    }
  }

  void _onWarmTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      onTargetArrived?.call(url);
    }
  }

  Future<Uint8List?> _pullImage(String url) async {
    try {
      final dynamic res = await prismAgent
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes as Uint8List;
    } catch (_) {}
    return null;
  }
}
