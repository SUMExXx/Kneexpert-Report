import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kneexpertreport/firebase_options.dart';
import 'package:kneexpertreport/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform
  );

  FirebaseMessaging.onBackgroundMessage(NotificationService.backgroundHandler);

  await NotificationService.initialize();

  SharedPreferences prefs = await SharedPreferences.getInstance();

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

  late final StreamSubscription<ConnectivityResult> connectivitySubscription;

  @override
  void initState() {
    super.initState();

    connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        // This will rebuild UI when connectivity changes
      });
    });
  }

  @override
  void dispose() {
    connectivitySubscription.cancel();
    super.dispose();
  }

  InAppWebViewController? webViewController;
  static bool isUpdatingToken = false;
  static bool hasUpdatedToken = false;

  Future<bool> isConnected() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> updateToken(url, controller) async {
    if (hasUpdatedToken || isUpdatingToken) return;
    isUpdatingToken = true;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (url != null) {
      if (url.path == "/") {
        var userDetails = await controller.evaluateJavascript(
          source: "localStorage.getItem('user_details');",
        );
        if (userDetails != null) {

          await prefs.setString('user_details', userDetails);

          String? token = prefs.getString('fcm_token');
          if(token != null){
            final url = Uri.parse('https://lead.hipxpert.in/api/method/update_user_fcm_token_hip_api');
            final url2 = Uri.parse('https://lead.kneexpert.in/api/method/update_user_fcm_token_knee_api');

            final headers = {
              'Content-Type': 'application/json',
              'Cookie': 'full_name=Guest; sid=Guest; system_user=no; user_id=Guest; user_lang=en',
            };

            String? userdata = prefs.getString('user_details');
            List<dynamic> decoded = jsonDecode(userdata!);
            Map<String, dynamic> userDetails = decoded[0];
            String? email = userDetails['email'];

            final body = jsonEncode({
              "user": email,
              "fcm_token": token
            });

            try {
              final response = await http.post(url, headers: headers, body: body);

              if (response.statusCode == 200) {
                print('Success: ${response.body}');
              } else {
                print('Error ${response.statusCode}: ${response.body}');
              }
            } catch (e) {
              print('Exception: $e');
            }

            try {
              final response = await http.post(url2, headers: headers, body: body);

              if (response.statusCode == 200) {
                print('Success: ${response.body}');
              } else {
                print('Error ${response.statusCode}: ${response.body}');
              }
            } catch (e) {
              print('Exception: $e');
            }
            hasUpdatedToken = true;
          }
        }
        else {
          await prefs.remove('user_details');
        }
      }
    }
    isUpdatingToken = false;
  }

  Widget buildWebView() {
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
              initialOptions: InAppWebViewGroupOptions(
                crossPlatform: InAppWebViewOptions(
                  cacheEnabled: false,
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  useShouldOverrideUrlLoading: true,
                ),
                android: AndroidInAppWebViewOptions(
                  cacheMode: AndroidCacheMode.LOAD_NO_CACHE,
                  domStorageEnabled: false,
                  databaseEnabled: false,
                  builtInZoomControls: false,
                  displayZoomControls: false,
                  supportMultipleWindows: false,
                ),
                ios: IOSInAppWebViewOptions(
                  sharedCookiesEnabled: false,
                  allowsInlineMediaPlayback: true,
                ),
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
              onWebViewCreated: (controller) async {
                webViewController = controller;
                await controller.clearCache();
                NotificationService.webViewController = controller; // ✅ set globally
              },
              // onLoadStop: (controller, url) async {
              //   await updateToken(url, controller);
              // },
              onUpdateVisitedHistory: (controller, url, androidIsReload) async {
                await updateToken(url, controller);
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

  Widget buildNoInternetScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text('No Internet Connection',
                style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {}); // Retry by rebuilding FutureBuilder
              },
              child: const Text('Retry'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: isConnected(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData && snapshot.data == true) {
          return buildWebView(); // Separate method returning your PopScope + Scaffold
        } else {
          return buildNoInternetScreen();
        }
      },
    );
  }
}
