import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  // This will store notifications received while app is open
  List<Map<String, String>> notifications = [];

  @override
  void initState() {
    super.initState();

    // Listen to foreground notifications from NotificationService
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? 'No Title';
      final body = message.notification?.body ?? 'No Body';

      setState(() {
        notifications.insert(0, {"title": title, "body": body});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('សារដំណឹង', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey,
      ),
      body: Column(
        children: [
          Expanded(
            child: notifications.isEmpty
                ? const Center(child: Text('No notifications yet'))
                : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Card(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(notification['title'] ?? ''),
                    subtitle: Text(notification['body'] ?? ''),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}