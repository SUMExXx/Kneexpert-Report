import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static InAppWebViewController? webViewController;

  /// Initialize Firebase Messaging and Local Notifications
  static Future<void> initialize() async {
    // Request notification permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('Notification permission status: ${settings.authorizationStatus}');

    // Initialize flutter_local_notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    await _localNotificationsPlugin.initialize(
      initializationSettings,
      // Updated callback
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null) {
          print('Notification payload: $payload');
          if (webViewController != null) {
            String url = "https://report.kneexpert.in$payload";
            await webViewController!.loadUrl(
              urlRequest: URLRequest(url: WebUri(url)),
            );
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground, // optional for background taps
    );

    // Get FCM token
    String? token = await _messaging.getToken();
    print('FCM Token: $token');

    // Store token in SharedPreferences
    if (token != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      print('FCM token saved to SharedPreferences.');
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received message in foreground:');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');

      // Show local notification
      if (message.notification != null) {
        _showLocalNotification(
          message.notification!.title ?? '',
          message.notification!.body ?? '',
          message.data['path'],
        );
      }
    });

    // Handle when app is opened from a background message
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      print('User tapped on notification: ${message.messageId}');
      if (message.data.containsKey('path')) {
        String path = message.data['path'];
        print('Navigate to path: $path');

        if (webViewController != null) {
          String url = "https://report.kneexpert.in$path";
          await webViewController!.loadUrl(
            urlRequest: URLRequest(url: WebUri(url)),
          );
        } else {
          print('WebView controller not available.');
        }
      }
    });
  }

  /// Show local notification
  static Future<void> _showLocalNotification(String title, String body, String? payload) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails('default_channel', 'Default',
        channelDescription: 'Default channel for app notifications',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker');

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotificationsPlugin.show(
      0, // notification id
      title,
      body,
      platformChannelSpecifics,
      payload: payload, // Pass path as payload for navigation
    );
  }

  /// Background message handler (must be a top-level function)
  static Future<void> backgroundHandler(RemoteMessage message) async {
    print('Handling background message: ${message.messageId}');
    // Initialize Firebase if using other services here
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Handle background notification tap here if needed
  print('Notification tapped in background with payload: ${response.payload}');
}
