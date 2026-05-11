import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ContactOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ContactOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class FaqTile extends StatelessWidget {
  final String question;
  const FaqTile({required this.question});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          title: Text(
            question,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.black54),
          onTap: () {
            // TODO: navigate to FAQ detail page
          },
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),
      ],
    );
  }
}
