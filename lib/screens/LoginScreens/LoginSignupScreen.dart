// import 'package:dolo/LoginScreens/signup_page.dart';

import 'package:flutter/material.dart';

import '../../Constants/colorconstant.dart';
import 'login_page.dart';

class LoginSignupScreen extends StatefulWidget {
  const LoginSignupScreen({super.key});

  @override
  State<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen> {
  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Heading
          // const Center(
          //   child: Text(
          //     'Login',
          //     style: TextStyle(
          //       fontSize: 28,
          //       fontWeight: FontWeight.bold,
          //       color: Color(0xFF001127),
          //     ),
          //   ),
          // ),

          const SizedBox(height: 60),

          // Logo
          Center(
            child: Image.asset(
              'assets/images/companynamelogo.png',
              height: 190,
              width: 190,
            ),
          ),

          const SizedBox(height: 60),

          const Text(
            'Welcome ',
            style: TextStyle(
              color: Color(0xff282828),
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          // const Text(
          //   'DOLO',
          //   style: TextStyle(
          //     color: Color(0xFF0A2A66),
          //     fontSize: 32,
          //     fontWeight: FontWeight.bold,
          //   ),
          // ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Text(
              "We offer lightning-fast P2P parcel pooling—just like carpooling, but for your packages! "
    "With DOLO, sending and receiving parcels becomes smarter, faster, and more economical. "
    "We’re your most reliable delivery companion, always by your side.",
              softWrap: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xff65656f),
                fontSize: 15,
              ),
            ),
          ),

          const SizedBox(height: 50),

          // Login Button
          SizedBox(
            height: height * 0.065,
            width: width * 0.7,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Login",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Sign Up Button
          // SizedBox(
          //   height: height * 0.065,
          //   width: width * 0.7,
          //   child: ElevatedButton(
          //     onPressed: () {
          //       Navigator.push(context,
          //           MaterialPageRoute(builder: (context) => SignupScreen()));
          //     },
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: Colors.white,
          //       side: const BorderSide(color: Color(0xFF4B4B4B)),
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(10),
          //       ),
          //     ),
          //     child: const Text(
          //       "Sign Up",
          //       style: TextStyle(
          //         color: Color(0xFF4B4B4B),
          //         fontWeight: FontWeight.bold,
          //         fontSize: 18,
          //       ),
          //     ),
          //   ),
          // ),

          const SizedBox(height: 30),

         
          const Spacer(),
        ],
      ),
    );
  }
}
