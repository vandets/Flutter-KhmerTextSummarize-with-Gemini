import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:http_parser/http_parser.dart';

import 'AboutUsPage.dart';
import 'NotificationPage.dart';
import 'UserProfile.dart';
import 'Utils/ServerSettingPage.dart';
import 'Utils/detectLanguage.dart';

class HomePage extends StatefulWidget {
  final User user;
  const HomePage({super.key, required this.user});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();

  String baseUrl = "";
  String summaryText = "";
  Map<String, dynamic> evaluation = {};
  bool _loading = false;
  String detectedLanguage = "";
  int wordCount = 0;
  int originalLength = 0;
  Timer? _debounce;

  String detectedTask = "";

  String selectedMode = 'Summary';
  String selectedLanguage = 'Khmer';
  String selectedSummarizer = 'Gemini';

  final List<String> modes = ['Summary', 'Concise', 'Smooth'];
  final List<String> summarizers = ['Gemini', 'Local Khmer'];

  final Map<String, String> languageFlags = {
    'Detected': '-',
    'Khmer': '🇰🇭',
    'English': '🇺🇸',
  };

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  bool isKhmerOrEnglish(String text) {
    final khmerRegex = RegExp(r'[\u1780-\u17FF]');
    final englishRegex = RegExp(r'[A-Za-z]');
    return khmerRegex.hasMatch(text) || englishRegex.hasMatch(text);
  }

  Future<http.Response?> _retryPost(Uri url, Map<String, dynamic> body,
      {int retries = 3, int delayMs = 1000}) async {
    for (int i = 0; i < retries; i++) {
      try {
        final response = await http
            .post(url,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(body))
            .timeout(const Duration(seconds: 60));
        return response;
      } catch (e) {
        if (i == retries - 1) rethrow;
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    return null;
  }

  // --------------------------- ENHANCED TEXT SUMMARIZATION ---------------------------
  Future<void> summarizeText(String text) async {
    if (text.trim().isEmpty) {
      showMessage('សូមបញ្ចូលអត្ថបទ...');
      return;
    }

    setState(() {
      _loading = true;
      summaryText = "";
      originalLength = 0;
    });

    try {
      if (selectedSummarizer == 'Gemini') {
        final url = Uri.parse('$baseUrl/api/summarize/text');
        final response = await _retryPost(url, {
          'text': text,
          'mode': selectedMode,
          'enhance': true,
        });

        if (response != null && response.statusCode == 200) {
          final decoded = utf8.decode(response.bodyBytes);
          final data = jsonDecode(decoded);

          setState(() {
            summaryText = data['summary'] ?? "";
            originalLength = data['originalLength'] ?? 0;
          });
        } else {
          showMessage('Error: ${response?.statusCode ?? "No response"}');
        }
      } else if (selectedSummarizer == 'Local Khmer') {
        final summary = await summarizeTextLocally(text);
        setState(() => summaryText = summary);
      }
    } catch (e) {
      showMessage('Exception: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<String> summarizeTextLocally(String text) async {
    final url = Uri.parse('$baseUrl/api/local-summarize/text');
    final response = await _retryPost(url, {'text': text});
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['summary'] ?? '';
    } else {
      return 'Failed to summarize locally';
    }
  }

  // --------------------------- ENHANCED PDF UPLOAD ---------------------------
  Future<void> uploadPdfDirect(File file) async {
    setState(() {
      _loading = true;
      summaryText = "";
      detectedTask = "";
    });

    try {
      final uri = Uri.parse('$baseUrl/api/summarize/upload');
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType('application', 'pdf'),
      ));

      // ---------------------- ADD GEMINI ENHANCEMENT ----------------------
      if (selectedSummarizer == 'Gemini') {
        request.fields['mode'] = selectedMode;
        request.fields['enhance'] = 'true';
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String combinedText =
            (data['ocrText'] as List<dynamic>?)?.join("\n\n") ?? data['summary'] ?? "";

        setState(() {
          summaryText = data['summary'] ?? "";
          _controller.text = combinedText;
          detectedTask = data['taskType'] ?? "Unknown";
          originalLength = combinedText.length;
          _handleLanguageDetection(_controller.text);
        });
      } else {
        showMessage('Error: ${response.statusCode}');
        print(response.body);
      }
    } catch (e) {
      showMessage('Exception: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> pickFileAndSummarize() async {
    setState(() => summaryText = "");

    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['txt', 'pdf']);

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      try {
        if (file.path.endsWith('.txt')) {
          String content = await file.readAsString();
          if (content.trim().isEmpty) {
            showMessage('The file is empty or cannot be read.');
            return;
          }
          if (!isKhmerOrEnglish(content)) {
            showMessage('Only Khmer or English text allowed.');
            return;
          }

          _controller.text = content;
          _handleLanguageDetection(_controller.text);
          await summarizeText(content);

        } else if (file.path.endsWith('.pdf')) {
          await uploadPdfDirect(file);
        } else {
          showMessage('File format not supported.');
        }
      } catch (e) {
        showMessage('Failed to read file: $e');
      }
    } else {
      showMessage('No file selected.');
    }
  }

  Future<void> _downloadText(BuildContext context) async {
    if (summaryText.isEmpty) {
      showMessage("No summary to save.");
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/summary.txt');
    await file.writeAsString(summaryText);
    showMessage("Saved as summary.txt in ${directory.path}");
  }

  int countKhmerWords(String text) {
    final wordRegex = RegExp(r'[\u1780-\u17FF]+');
    return wordRegex.allMatches(text).length;
  }

  void _handleLanguageDetection(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (text.isEmpty) {
        setState(() {
          detectedLanguage = '';
          wordCount = 0;
        });
        return;
      }
      try {
        final langResult = await detectLanguageWithGemini(text);
        final countResult = await countKhmerWordsWithGemini(text);
        if (mounted) {
          setState(() {
            detectedLanguage = langResult;
            wordCount = countResult;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            detectedLanguage = 'Error';
            wordCount = 0;
          });
        }
        print('API call failed: $e');
      }
    });
  }

  Future<void> _loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final ip = prefs.getString('server_ip') ?? "192.168.1.249:8080";
      baseUrl = "http://$ip";
    });
  }

  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title:
        const Text('សង្ខេបអត្ថបទខ្មែរ', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notification',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationPage()),
              );            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(user: widget.user),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: widget.user.photoURL != null
                    ? NetworkImage(widget.user.photoURL!)
                    : null,
                child: widget.user.photoURL == null
                    ? const Icon(Icons.person, color: Colors.blueGrey, size: 22)
                    : null,
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(color: Colors.blueGrey[800]),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          backgroundImage: widget.user.photoURL != null
                              ? NetworkImage(widget.user.photoURL!)
                              : null,
                          child: widget.user.photoURL == null
                              ? const Icon(Icons.person, color: Colors.blueGrey, size: 40)
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.user.displayName ?? widget.user.email ?? 'Unknown User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.book_rounded, color: Colors.grey),
                    title: const Text('ការប្រើប្រាស់'),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.list, color: Colors.grey),
                    title: const Text('បញ្ជី AI Prompt'),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings, color: Colors.grey),
                    title: const Text('Server Settings'),
                    onTap: () async {
                      Navigator.pop(context);
                      final newIp = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ServerSettingsPage()),
                      );
                      if (newIp != null) {
                        setState(() {
                          baseUrl = "http://$newIp";
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Updated server: $baseUrl')),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.grey),
                    title: const Text('អំពីយើង'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AboutUsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summarizer Selector
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: DropdownButtonFormField<String>(
                      value: selectedSummarizer,
                      items: summarizers
                          .map((summ) => DropdownMenuItem(value: summ, child: Text(summ)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedSummarizer = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: "Summarizer",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedMode,
                          items: ['Summary', 'Concise', 'Smooth']
                              .map((mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(mode),
                          ))
                              .toList(),
                          onChanged: selectedSummarizer == 'Gemini'
                              ? (value) {
                            setState(() {
                              selectedMode = value!;
                            });
                          }
                              : null,
                          decoration: InputDecoration(
                            labelText: "Mode",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: detectedLanguage.isEmpty ? 'Detecting' : detectedLanguage,
                          items: [
                            DropdownMenuItem(
                              value: detectedLanguage.isEmpty ? 'Detecting' : detectedLanguage,
                              child: Row(
                                children: [
                                  Text(
                                    detectedLanguage == 'Khmer'
                                        ? '🇰🇭'
                                        : detectedLanguage == 'English'
                                        ? '🇺🇸'
                                        : '-',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(detectedLanguage.isEmpty ? 'Detecting' : detectedLanguage),
                                ],
                              ),
                            ),
                          ],
                          onChanged: null,
                          decoration: InputDecoration(
                            labelText: "Language",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "អត្ថបទដើម:",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    maxLines: 10,
                    onChanged: (text) {
                      setState(() {});
                      _handleLanguageDetection(text);
                    },
                    decoration: InputDecoration(
                      hintText: "សូមបញ្ចូលអត្ថបទ...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "ចំនួនពាក្យខ្មែរ: $originalLength",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : pickFileAndSummarize,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            minimumSize: const Size(0, 50),
                          ),
                          child: const Text('យកពី', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : () => summarizeText(_controller.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey[800],
                            minimumSize: const Size(0, 50),
                          ),
                          child: _loading
                              ? SizedBox(
                            height: 20,
                            width: 20,
                            child: Center(
                              child: LoadingAnimationWidget.waveDots(color: Colors.white, size: 30),
                            ),
                          )
                              : const Text('សង្ខែប', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("សេចក្តីសង្ខេបអត្ថបទដូចខាងលើក្រោម៖",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12)),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Stack(
                        alignment: Alignment.topLeft,
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(10, 25, 10, 10),
                            child: Text(summaryText, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: summaryText));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Copied to Clipboard ✔️")));
                                  },
                                  child: const Icon(Icons.copy, size: 16),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _downloadText(context),
                                  child: const Icon(Icons.download, size: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: LoadingAnimationWidget.dotsTriangle(color: Colors.white, size: 50),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
