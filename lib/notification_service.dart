import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static InAppWebViewController? webViewController;

  /// Initialize Firebase Messaging
  static Future<void> initialize() async {
    // Request notification permissions (especially important for iOS)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('Notification permission status: ${settings.authorizationStatus}');

    // Get FCM token
    String? token = await _messaging.getToken();
    print('FCM Token: $token');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received message in foreground:');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      // Add logic here to show UI or update state as needed
    });

    // Handle when app is opened from a background message
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      print('User tapped on notification: ${message.messageId}');
      if (message.data.containsKey('path')) {
        String path = message.data['path'];
        print('Navigate to path: $path');

        // If you store the controller globally, navigate here:
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

  /// Background message handler (must be a top-level function)
  static Future<void> backgroundHandler(RemoteMessage message) async {
    print('Handling background message: ${message.messageId}');
    // Initialize Firebase if using other services here
  }
}
