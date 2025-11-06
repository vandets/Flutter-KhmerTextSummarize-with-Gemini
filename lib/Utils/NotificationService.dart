import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  NotificationService._privateConstructor();
  static final NotificationService instance = NotificationService._privateConstructor();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  String deviceToken = '';

  Future<void> init() async {
    // Local notifications initialization
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print('Notification clicked: ${details.payload}');
      },
    );

    // FCM setup
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      deviceToken = await messaging.getToken() ?? '';
      print('Device Token: $deviceToken');

      // Foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        showLocalNotification(
          title: message.notification?.title ?? 'No title',
          body: message.notification?.body ?? 'No body',
        );
      });

      // Background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // When app opened via notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Notification clicked!');
      });
    } else {
      print('User declined notification permission');
    }
  }

  Future<void> showLocalNotification({required String title, required String body}) async {
    await flutterLocalNotificationsPlugin.show(
      title.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          'Default Channel',
          channelDescription: 'General notifications',
          importance: Importance.max,
          priority: Priority.high,
          number: 1, // badge count
        ),
      ),
    );
  }

  // -----------------------------
  // FCM Push Notification via Service Account
  // -----------------------------
  Future<AccessCredentials> _getAccessToken() async {
    final serviceAccountPath = dotenv.env['PATH_TO_SECRETS']!;
    final serviceAccountJson = await rootBundle.loadString(serviceAccountPath);

    final serviceAccount = ServiceAccountCredentials.fromJson(serviceAccountJson);
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

    final client = await clientViaServiceAccount(serviceAccount, scopes);
    return client.credentials;
  }

  Future<bool> sendPushNotification({
    required String deviceToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (deviceToken.isEmpty) return false;

    final credentials = await _getAccessToken();
    final accessToken = credentials.accessToken.data;
    final projectId = dotenv.env['PROJECT_ID'];

    final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

    final message = {
      'message': {
        'token': deviceToken,
        'notification': {'title': title, 'body': body},
        'apns': {
          'payload': {'aps': {'badge': 1}}
        }, // iOS badge
        'android': {
          'notification': {'tag': 'general', 'channel_id': 'default_channel'}
        },
        'data': data ?? {},
      },
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully.');
      return true;
    } else {
      print('Failed to send notification: ${response.body}');
      return false;
    }
  }
}

// Background message handler must be top-level
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received: ${message.notification?.title}');
}
