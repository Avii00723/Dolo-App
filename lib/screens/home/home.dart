import 'package:flutter/material.dart';

class HomePageContent extends StatelessWidget {
  const HomePageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set background color
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Vertically centered
            children: [
              const SizedBox(height: 40),

              // App image (e.g., WhatsApp illustration)
              // Image.asset(
              //   'assets/images/companynamelogo.png',
              //   width: 236,
              //   height: 250,
              //   fit: BoxFit.fill,
              // ),

              const SizedBox(height: 40),

              // Title text
              const Text(
                'Are you a sender \nor a traveler?',
                style: TextStyle(
                  fontSize: 32,
                  color: Color(0xFF00142C),
                  letterSpacing: 0.05,
                  fontFamily: 'Roboto',
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Sender and Traveler Cards
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Sender card
                  Container(
                    width: 150,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Color(0xFF5E5C5C), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.send, size: 40, color: Colors.black54),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Sender',
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Roboto',
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Traveler card
                  Container(
                    width: 150,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Color(0xFF5E5C5C), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.flight_takeoff, size: 40, color: Colors.black54),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Traveler',
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Roboto',
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
