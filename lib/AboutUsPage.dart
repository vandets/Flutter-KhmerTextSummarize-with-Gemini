import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('អំពីកម្មវិធី', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// --- University Logo ---
            Center(
              child: Image.asset(
                'assets/logo.png', // your logo image
                height: 120,
              ),
            ),
            const SizedBox(height: 20),

            /// --- University Name ---
            // const Text(
            //   'សាកលវិទ្យាល័យ អាស៊ី អឺរ៉ុប\nASIA EURO UNIVERSITY',
            //   textAlign: TextAlign.center,
            //   style: TextStyle(
            //     fontSize: 22,
            //     fontWeight: FontWeight.bold,
            //     color: Colors.blueGrey,
            //   ),
            // ),

            const Text(
              'ADVANCED KHMER TEXT SUMMARIZER',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 10),

            // const Text(
            //   'អក្សរនេះជាអក្សរឧទ្ទិសនៃការអប់រំ និងចំណេះដឹង',
            //   textAlign: TextAlign.center,
            //   style: TextStyle(
            //     fontStyle: FontStyle.italic,
            //     fontSize: 16,
            //     color: Colors.redAccent,
            //   ),
            // ),
            // const SizedBox(height: 30),

            /// --- Topic ---
            buildSectionTitle('📘 Project Topic'),
            buildCard(
              'Khmer Text Summarizer Using Java, Flutter and AI',
            ),

            /// --- Benefit ---
            buildSectionTitle('🎯 Project Benefit'),
            buildCard(
              'This project provides an intelligent tool that summarizes long Khmer texts into concise and meaningful summaries. '
                  'It aims to save time for readers, students, and researchers by using AI and NLP technologies for the Khmer language.',
            ),

            /// --- Solution ---
            buildSectionTitle('💡 Our Solution'),
            buildCard(
              'We developed an AI-powered summarizer that integrates a Java backend with Flutter frontend. '
                  'It uses Natural Language Processing (NLP) to extract key information and display the summary in real-time. '
                  'The app also supports uploading or typing Khmer text directly.',
            ),

            /// --- Professor ---
            buildSectionTitle('👨‍🏫 Project Advisor'),
            buildCard(
              'Advisor: សាស្រ្តាចារ្យ សុខ ពង្សសមេត្រី, Professor of Computer Science\nAsia Euro University',
            ),

            /// --- Team Members ---
            buildSectionTitle('👥 Our Project Team'),
            const SizedBox(height: 10),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: const [
                TeamCard(
                  name: 'SOK Vandet',
                  role: 'Project Manager & Developer',
                  image: 'assets/team/vandet.jpg',
                ),
                TeamCard(
                  name: 'CHEM Sidet',
                  role: 'Project Coordinator',
                  image: 'assets/team/sidet.jpg',
                ),
                TeamCard(
                  name: 'RA Borey',
                  role: 'Project Researcher',
                  image: 'assets/team/borey.jpg',
                ),
                TeamCard(
                  name: 'SAT Seyla',
                  role: 'UX/UI Designer',
                  image: 'assets/team/seyla.jpg',
                ),
                TeamCard(
                  name: 'SAMOEUN Ketya',
                  role: 'Contributor',
                  image: 'assets/team/boy.png',
                ),
                TeamCard(
                  name: 'KHOU Long',
                  role: 'Contributor',
                  image: 'assets/team/boy.png',
                ),
              ],
            ),

            const SizedBox(height: 30),

            /// --- Academic Year ---
            const Text(
              'ឆ្នាំសិក្សា៖ ២០២៥ - ២០២៦',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Section title widget
  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  /// Content card widget
  Widget buildCard(String text) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, height: 1.5),
          textAlign: TextAlign.justify,
        ),
      ),
    );
  }
}

/// --- Team Card Widget ---
class TeamCard extends StatelessWidget {
  final String name;
  final String role;
  final String image;

  const TeamCard({
    super.key,
    required this.name,
    required this.role,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundImage: AssetImage(image),
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                role,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}