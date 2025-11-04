import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'OTPScreen.dart';
import '../../Controllers/LoginService.dart';
import '../../Widgets/ModernInputField.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final LoginService _loginService = LoginService();
  bool isLoading = false;

  void sendOTP() async {
    String phoneNumber = phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter phone number')),
      );
      return;
    }

    if (phoneNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter valid 10-digit phone number')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await _loginService.sendOtp(phoneNumber);
      if (response != null && response.userId.isNotEmpty) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPScreen(
                phoneNumber: phoneNumber,
                userId: response.userId,
                // You can pass OTP for debugging if needed: otp: response.otp,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send OTP')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              Column(
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/companynamelogo.png',
                      height: 190,
                      width: 190,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Stack(
                            children: [
                              Positioned(
                                left: 16,
                                top: 16,
                                child: Icon(
                                  Icons.inbox_outlined,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF001127),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 60),

              // Phone Number Input with Modern Design
              ModernInputField(
                controller: phoneController,
                label: "Phone Number",
                hint: "Enter your phone number",
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                enabled: !isLoading,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),

              const SizedBox(height: 40),

              // Continue Button
              ModernButton(
                text: "Send OTP",
                onPressed: isLoading ? null : sendOTP,
                isLoading: isLoading,
              ),

              const SizedBox(height: 280),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'By continuing, you agree to our Terms\nof Service and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
