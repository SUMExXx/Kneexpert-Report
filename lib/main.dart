import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kneexpertreport/firebase_options.dart';
import 'package:kneexpertreport/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? globalUserDetails;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform
  );

  FirebaseMessaging.onBackgroundMessage(NotificationService.backgroundHandler);

  await NotificationService.initialize();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  globalUserDetails = prefs.getString('user_details');

  // print("Loaded globalUserDetails: $globalUserDetails");

  await Permission.locationWhenInUse.request();
  await Permission.locationAlways.request();
  await Permission.camera.request();
  await Permission.phone.request();
  await Permission.storage.request();
  await Permission.bluetoothScan.request();
  await Permission.bluetoothConnect.request();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? webViewController;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (webViewController != null) {
          bool canGoBack = await webViewController!.canGoBack();
          if (canGoBack) {
            webViewController!.goBack();
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pop();
            });
          }
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
          });
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri("https://report.kneexpert.in"),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              geolocationEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              cacheEnabled: false,
              clearCache: true,
              useShouldOverrideUrlLoading: true,
              supportZoom: false, // Disable zoom controls
              builtInZoomControls: false, // Disable built-in zoom controls (Android specific)
              displayZoomControls: false, // Hide zoom controls (Android specific)
              // userScalable: false, // Prevent user scaling (iOS specific)
            ),
            onGeolocationPermissionsShowPrompt: (controller, origin) async {
              return GeolocationPermissionShowPromptResponse(
                origin: origin,
                allow: true,
                retain: true,
              );
            },
            onWebViewCreated: (controller) {
              webViewController = controller;
              NotificationService.webViewController = controller; // ✅ set globally
            },
            onLoadStop: (controller, url) async {
              SharedPreferences prefs = await SharedPreferences.getInstance();

              if (url != null) {
                // ✅ If path is /login, clear user_details
                if (url.path == "/login") {
                  await prefs.remove('user_details');
                  globalUserDetails = null;
                  // print("Cleared user_details from SharedPreferences");
                }

                // ✅ If path is / and globalUserDetails is null, fetch and save
                if (url.path == "/" && globalUserDetails == null) {
                  var userDetails = await controller.evaluateJavascript(
                    source: "localStorage.getItem('user_details');",
                  );
                  if (userDetails != null) {
                    await prefs.setString('user_details', userDetails);
                    globalUserDetails = userDetails;
                    // print("Fetched and saved user_details: $globalUserDetails");
                  }
                }
              }
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final uri = navigationAction.request.url;

              if (uri != null) {
                final scheme = uri.scheme.toLowerCase();

                if (scheme == "tel" || scheme == "mailto") {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    return NavigationActionPolicy.CANCEL;
                  } else {
                    // print("Cannot launch $uri");
                  }
                }

                if (!uri.host.contains("kneexpert.in")) {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    return NavigationActionPolicy.CANCEL;
                  }
                }
              }

              return NavigationActionPolicy.ALLOW;
            },
          )
        ),
      ),
    );
  }
}
