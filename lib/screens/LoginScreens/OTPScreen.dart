import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home/homepage.dart'; // Import your home page

class OTPScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OTPScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OTPScreen> createState() => OTPScreenState();
}

class OTPScreenState extends State<OTPScreen> {
  // 6 controllers and focus nodes for 6-digit OTP
  final List<TextEditingController> _controllers =
  List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes =
  List.generate(6, (index) => FocusNode());

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = false;
  bool isResending = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty) {
      // Move to next field if not the last one
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        // Auto-verify when all 6 digits are entered
        if (_isOTPComplete()) {
          _verifyOTP();
        }
      }
    } else {
      // Handle backspace - move to previous field if current is empty
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _onKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  bool _isOTPComplete() {
    // Check if all 6 fields have exactly 1 digit each
    return _controllers.every((controller) =>
    controller.text.isNotEmpty && controller.text.length == 1);
  }

  String _getOTP() {
    // Combine all 6 digits into one string
    return _controllers.map((controller) => controller.text.trim()).join();
  }

  void _clearOTP() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _verifyOTP() async {
    final otpCode = _getOTP();

    // Ensure we have exactly 6 digits
    if (otpCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter complete 6-digit OTP')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otpCode,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Successfully verified
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePageWithNav()),
                (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        isLoading = false;
      });

      String errorMessage = 'Verification failed';
      if (e.code == 'invalid-verification-code') {
        errorMessage = 'Invalid 6-digit OTP. Please try again';
        _clearOTP(); // Clear all fields on invalid OTP
      } else if (e.code == 'session-expired') {
        errorMessage = 'OTP expired. Please request a new one';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _resendOTP() async {
    setState(() {
      isResending = true;
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomePageWithNav()),
                  (route) => false,
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            isResending = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to resend OTP: ${e.message}')),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            isResending = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('New 6-digit OTP sent successfully')),
            );

            // Replace current screen with new verification ID
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OTPScreen(
                  verificationId: verificationId,
                  phoneNumber: widget.phoneNumber,
                ),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            isResending = false;
          });
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        isResending = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resending OTP: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isTablet = screenWidth > 600;
    final isLandscape = screenWidth > screenHeight;

    // Responsive dimensions
    final horizontalPadding = isTablet ? screenWidth * 0.15 : 24.0;
    final logoSize = isTablet ? 100.0 : (isLandscape ? 60.0 : 80.0);
    final titleFontSize = isTablet ? 40.0 : (isLandscape ? 28.0 : 32.0);
    final subtitleFontSize = isTablet ? 20.0 : (isLandscape ? 14.0 : 16.0);
    final headerFontSize = isTablet ? 30.0 : (isLandscape ? 20.0 : 24.0);
    final otpFieldSize = isTablet ? 70.0 : (isLandscape ? 45.0 : 50.0);
    final otpFieldHeight = isTablet ? 80.0 : (isLandscape ? 55.0 : 60.0);
    final buttonHeight = isTablet ? 68.0 : (isLandscape ? 48.0 : 56.0);
    final buttonFontSize = isTablet ? 22.0 : (isLandscape ? 16.0 : 18.0);

    // Responsive spacing
    final topSpacing = isLandscape ? 20.0 : 40.0;
    final logoSpacing = isLandscape ? 16.0 : 24.0;
    final titleSpacing = isLandscape ? 24.0 : 48.0;
    final subtitleSpacing = isLandscape ? 4.0 : 8.0;
    final otpSpacing = isLandscape ? 24.0 : 48.0;
    final statusSpacing = isLandscape ? 16.0 : 24.0;
    final buttonSpacing = isLandscape ? 20.0 : 32.0;
    final bottomSpacing = isLandscape ? 16.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.black,
              size: isTablet ? 24 : 20
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    mainAxisAlignment: isLandscape
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          SizedBox(height: topSpacing),

                          // Logo
                          Container(
                            width: logoSize,
                            height: logoSize,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: logoSize * 0.2,
                                  top: logoSize * 0.2,
                                  child: Icon(
                                    Icons.inbox_outlined,
                                    color: Colors.white,
                                    size: logoSize * 0.4,
                                  ),
                                ),
                                Positioned(
                                  right: logoSize * 0.15,
                                  bottom: logoSize * 0.15,
                                  child: Icon(
                                    Icons.refresh,
                                    color: Colors.white,
                                    size: logoSize * 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: logoSpacing),

                          // DOLO Text
                          Text(
                            'DOLO',
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 2,
                            ),
                          ),

                          SizedBox(height: titleSpacing),

                          // Enter OTP Title
                          Text(
                            'Enter 6-Digit OTP',
                            style: TextStyle(
                              fontSize: headerFontSize,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),

                          SizedBox(height: subtitleSpacing),

                          // Subtitle
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 40.0 : 0.0
                            ),
                            child: Text(
                              'Enter the 6-digit verification code sent to\n${widget.phoneNumber}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: subtitleFontSize,
                                color: Colors.grey,
                                height: 1.4,
                              ),
                            ),
                          ),

                          SizedBox(height: otpSpacing),

                          // 6-Digit OTP Input Fields
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isTablet ? 500 : double.infinity,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(6, (index) {
                                return Container(
                                  width: otpFieldSize,
                                  height: otpFieldHeight,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _controllers[index].text.isNotEmpty
                                          ? Colors.black
                                          : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: _controllers[index].text.isNotEmpty
                                        ? Colors.grey.shade50
                                        : Colors.white,
                                  ),
                                  child: KeyboardListener(
                                    focusNode: FocusNode(),
                                    onKeyEvent: (event) => _onKeyEvent(event, index),
                                    child: TextField(
                                      controller: _controllers[index],
                                      focusNode: _focusNodes[index],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      maxLength: 1,
                                      enabled: !isLoading,
                                      style: TextStyle(
                                        fontSize: isTablet ? 28 : (isLandscape ? 20 : 24),
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(1),
                                      ],
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        counterText: '',
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (value) => _onChanged(value, index),
                                      onTap: () {
                                        _controllers[index].selection = TextSelection.fromPosition(
                                          TextPosition(offset: _controllers[index].text.length),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),

                          SizedBox(height: statusSpacing),

                          // OTP Status Text
                          Text(
                            'Enter all 6 digits (${_getOTP().length}/6)',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : (isLandscape ? 12 : 14),
                              color: _isOTPComplete() ? Colors.green : Colors.grey,
                              fontWeight: _isOTPComplete() ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),

                          SizedBox(height: buttonSpacing),

                          // Verify Button
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isTablet ? 400 : double.infinity,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: buttonHeight,
                              child: ElevatedButton(
                                onPressed: (_isOTPComplete() && !isLoading) ? _verifyOTP : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isOTPComplete() ? Colors.black : Colors.grey.shade300,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: isLoading
                                    ? SizedBox(
                                  height: isTablet ? 24 : 20,
                                  width: isTablet ? 24 : 20,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                                    : Text(
                                  'Verify 6-Digit Code',
                                  style: TextStyle(
                                    fontSize: buttonFontSize,
                                    fontWeight: FontWeight.w600,
                                    color: _isOTPComplete() ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Resend Option
                      Padding(
                        padding: EdgeInsets.only(
                          top: isLandscape ? 20.0 : 0.0,
                          bottom: bottomSpacing,
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Didn't receive the 6-digit code?",
                              style: TextStyle(
                                fontSize: isTablet ? 18 : (isLandscape ? 14 : 16),
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: isLandscape ? 4 : 8),
                            TextButton(
                              onPressed: isResending ? null : _resendOTP,
                              child: isResending
                                  ? SizedBox(
                                height: isTablet ? 20 : 16,
                                width: isTablet ? 20 : 16,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                                  : Text(
                                'Resend Code',
                                style: TextStyle(
                                  fontSize: isTablet ? 18 : (isLandscape ? 14 : 16),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}