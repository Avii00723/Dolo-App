import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'ChatScreen.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Inbox',
          style: TextStyle(
            color: Colors.black,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.black,
                size: 28,
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _buildMessageItem(
            context: context,
            profileImage: 'assets/profile.jpg',
            name: 'George',
            time: 'Now',
            route: 'Aurangabad to Pune, 6 May',
            message: 'Hi! I have a small parcel',
            productName: 'Delivery Service',
            price: '₹450',
          ),
          const Divider(height: 1, indent: 88),
          _buildMessageItem(
            context: context,
            name: 'Sohini K.',
            time: '10:30 AM',
            route: 'Bangalore to Mumbai, 10 May',
            message: 'Is the item still available?',
            productName: 'Suzuki Mini Truck',
            price: '₹450',
          ),
          const Divider(height: 1, indent: 88),
          _buildMessageItem(
            context: context,
            name: 'Raj Kumar',
            time: 'Yesterday',
            route: 'Delhi to Jaipur, 15 May',
            message: 'When can you deliver it?',
            productName: 'Shipping Service',
            price: '₹1,200',
          ),
          const Divider(height: 1, indent: 88),
          // Add more message items here as needed
        ],
      ),
    );
  }

  Widget _buildMessageItem({
    required BuildContext context,
    String? profileImage,
    required String name,
    required String time,
    required String route,
    required String message,
    required String productName,
    required String price,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              // name: name,
              // profileImage: profileImage,
              // productName: productName,
              // price: price,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: profileImage != null ? AssetImage(profileImage) : null,
              backgroundColor: Colors.grey[300],
              child: profileImage == null
                  ? Text(
                name[0],
                style: const TextStyle(fontSize: 20, color: Colors.white),
              )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    route,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}