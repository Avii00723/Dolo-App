import 'package:flutter/material.dart';
import 'ContactOption.dart';
import 'ChatSupportScreen.dart';
import 'SupportFormScreen.dart';

/// Simple FAQ data for the support screen.
const List<String> faqItems = [
  'How do I track my order?',
  'What should I do if I have an issue with delivery?',
  'How do I contact support?',
];

class SupportScreen extends StatelessWidget {
  final String? orderId;

  const SupportScreen({super.key, this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Support an issue',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sub-title
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 20),
              child: Center(
                child: Text(
                  "We're here to help",
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            ),

            // ── Contact options ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ContactOption(
                    icon: Icons.chat_bubble_outline,
                    label: 'Chat Support',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ChatSupportScreen(orderId: orderId)),
                    ),
                  ),
                  const SizedBox(width: 32),
                  ContactOption(
                    icon: Icons.mail_outline,
                    label: 'Email Support',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupportFormScreen(isChatMode: false, orderId: orderId),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── FAQ Section ──
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Most Frequent Questions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              color: Colors.white,
              child: Column(
                children: faqItems
                    .map((faq) => FaqTile(question: faq))
                    .toList(),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
