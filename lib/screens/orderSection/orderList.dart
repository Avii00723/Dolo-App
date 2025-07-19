import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Route Orders',
      theme: ThemeData(
        primaryColor: Colors.blue[800],
        fontFamily: 'SF Pro Display',
      ),
      home: const OrderListScreen(),
    );
  }
}

class OrderListScreen extends StatelessWidget {
  const OrderListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route information section
              _buildRouteHeader(),
              const SizedBox(height: 24),

              // Available drivers list
              Expanded(
                child: ListView(
                  children: [
                    _buildDriverCard(
                      name: "Alok M.",
                      time: "7:00 AM",
                      origin: "Aurangabad",
                      destination: "Ahmednagar",
                      vehicleType: "Small truck",
                      spaceLeft: "40%",
                    ),
                    const SizedBox(height: 10),
                    _buildDriverCard(
                      name: "Alok M.",
                      time: "7:00 AM",
                      origin: "Aurangabad",
                      destination: "Ahmednagar",
                      vehicleType: "Small truck",
                      spaceLeft: "40%",
                    ),
                    const SizedBox(height: 10),
                    _buildDriverCard(
                      name: "Alok M.",
                      time: "7:00 AM",
                      origin: "Aurangabad",
                      destination: "Ahmednagar",
                      vehicleType: "Small truck",
                      spaceLeft: "40%",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 16),
            children: [
              TextSpan(
                text: "From ",
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const TextSpan(
                text: "Aurangabad",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 16),
            children: [
              TextSpan(
                text: "To ",
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const TextSpan(
                text: "Pune",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "April 15, 2024",
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverCard({
    required String name,
    required String time,
    required String origin,
    required String destination,
    required String vehicleType,
    required String spaceLeft,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Driver avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                color: Colors.black54,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Driver details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Driver name
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1A237E), // Deep indigo color
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Route time and locations
                  Text(
                    "$time – $origin – $destination",
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Vehicle type and space information
                  Row(
                    children: [
                      const Icon(
                        Icons.local_shipping,
                        size: 16,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$vehicleType - Space left: $spaceLeft",
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ],
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