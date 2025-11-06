import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ServerSettingsPage extends StatefulWidget {
  const ServerSettingsPage({super.key});

  @override
  State<ServerSettingsPage> createState() => _ServerSettingsPageState();
}

class _ServerSettingsPageState extends State<ServerSettingsPage> {
  final TextEditingController _ipController = TextEditingController();
  String? savedIp;
  bool _testingConnection = false;
  bool _tracingRoute = false;
  List<String> traceResults = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  Future<void> _testPing() async {
    String ip = _ipController.text.trim();
    if (ip.startsWith('http://')) ip = ip.replaceFirst('http://', '');
    final uri = Uri.parse('http://$ip/api/summarize/ping');

    setState(() => _testingConnection = true);

    String message = '';

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        message = '✅ Ping response: ${response.body}';
      } else {
        message = '⚠️ Ping responded with status: ${response.statusCode}';
      }
    } catch (e) {
      message = '⚠️ Ping failed: $e';
    }

    setState(() => _testingConnection = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }


  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      savedIp = prefs.getString('server_ip');
      if (savedIp != null) _ipController.text = savedIp!;
    });
  }

  Future<void> _saveIp() async {
    final prefs = await SharedPreferences.getInstance();
    String ip = _ipController.text.trim();
    if (ip.startsWith('http://')) ip = ip.replaceFirst('http://', '');

    final ipPortRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}:\d{1,5}$');
    if (!ipPortRegex.hasMatch(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid IP:port, e.g., 192.168.1.249:8080')),
      );
      return;
    }

    await prefs.setString('server_ip', ip);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Server IP saved: $ip')),
    );

    Navigator.pop(context, ip);
  }

  Future<void> _testConnection() async {
    String ip = _ipController.text.trim();
    if (ip.startsWith('http://')) ip = ip.replaceFirst('http://', '');
    final host = ip.split(':')[0];
    final port = int.tryParse(ip.split(':').length > 1 ? ip.split(':')[1] : '8080') ?? 8080;

    setState(() => _testingConnection = true);

    String message = '';

    // --- Step 1: TCP Socket check (ping-style) ---
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
      message += '✅ Server reachable at $host:$port\n';
      socket.destroy();
    } catch (_) {
      message += '⚠️ Cannot reach server at $host:$port\n';
      setState(() => _testingConnection = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    // --- Step 2: POST request check to your API ---
    try {
      final uri = Uri.parse('http://$ip/api/summarize');
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: '{"text":"Test connection"}',
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        message += '✅ API POST successful';
      } else {
        message += '⚠️ API POST responded: ${response.statusCode}';
      }
    } catch (e) {
      message += '⚠️ API POST failed: $e';
    }

    setState(() => _testingConnection = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }


  Future<void> _startTraceroute() async {
    String host = _ipController.text.trim();
    if (host.startsWith('http://')) host = host.replaceFirst('http://', '');
    host = host.split(':')[0]; // remove port

    setState(() {
      _tracingRoute = true;
      traceResults.clear();
    });

    int maxHops = 10; // you can increase this
    for (int ttl = 1; ttl <= maxHops; ttl++) {
      String line;
      try {
        final stopwatch = Stopwatch()..start();
        final socket = await Socket.connect(host, 80, timeout: const Duration(seconds: 2));
        stopwatch.stop();
        line = '$ttl    ${stopwatch.elapsedMilliseconds} ms    ${socket.remoteAddress.address}';
        socket.destroy();
        traceResults.add(line);
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 300));
        break; // destination reached
      } catch (_) {
        line = '$ttl    *    Request timed out.';
        traceResults.add(line);
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 300));
      }
      // Auto-scroll to bottom
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }

    setState(() => _tracingRoute = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter Server IP:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'e.g., 192.168.1.249:8080',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixText: 'http://',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: _saveIp,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 50),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _testingConnection ? null : _testConnection,
                  icon: _testingConnection
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.wifi),
                  label: const Text('Test Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // ElevatedButton.icon(
            //   onPressed: _testingConnection ? null : _testPing,
            //   icon: _testingConnection
            //       ? const SizedBox(
            //     width: 16,
            //     height: 16,
            //     child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            //   )
            //       : const Icon(Icons.route),
            //   label: const Text('Test /ping'),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.teal,
            //     foregroundColor: Colors.white,
            //     minimumSize: const Size(double.infinity, 50),
            //   ),
            // ),
            // const SizedBox(height: 20),
            // ElevatedButton.icon(
            //   onPressed: _tracingRoute ? null : _startTraceroute,
            //   icon: _tracingRoute
            //       ? const SizedBox(
            //     width: 16,
            //     height: 16,
            //     child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            //   )
            //       : const Icon(Icons.route),
            //   label: const Text('Traceroute'),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.deepPurple,
            //     foregroundColor: Colors.white,
            //     minimumSize: const Size(double.infinity, 50),
            //   ),
            // ),
            // const SizedBox(height: 20),
            // Expanded(
            //   child: Container(
            //     padding: const EdgeInsets.all(8),
            //     decoration: BoxDecoration(
            //       color: Colors.black,
            //       borderRadius: BorderRadius.circular(6),
            //       border: Border.all(color: Colors.greenAccent),
            //     ),
            //     child: ListView.builder(
            //       controller: _scrollController,
            //       itemCount: traceResults.length,
            //       itemBuilder: (_, index) => Text(
            //         traceResults[index],
            //         style: const TextStyle(
            //           color: Colors.greenAccent,
            //           fontFamily: 'Courier', // monospace
            //           fontSize: 14,
            //         ),
            //       ),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
