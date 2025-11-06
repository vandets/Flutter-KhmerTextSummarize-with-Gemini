import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SummaryBox extends StatelessWidget {
  final String summaryText;
  const SummaryBox({super.key, required this.summaryText});

  Future<void> _downloadText(BuildContext context) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/summary.txt');
    await file.writeAsString(summaryText);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Saved as summary.txt in ${directory.path}")),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the remaining height from current position to bottom of screen
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding =
        MediaQuery.of(context).padding.top + kToolbarHeight; // optional
    final containerHeight = screenHeight - topPadding - 20; // adjust as needed

    return Container(
      height: containerHeight,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Scrollable text
          Positioned.fill(
            child: SingleChildScrollView(
              child: Text(
                summaryText,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          // Tiny top-right buttons
          Positioned(
            top: 0.1,
            right: 0.1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: summaryText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Copied to Clipboard ✔️")),
                    );
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
    );
  }
}
