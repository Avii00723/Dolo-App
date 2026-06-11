import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../Controllers/LoginService.dart';
import '../../Controllers/AuthService.dart';
import '../../Controllers/DeviceTokenService.dart';
import '../BackendDownScreen.dart';
import 'signup_page.dart';
import 'package:dolo/screens/home/homepage.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String userId;

  const OTPScreen({
    Key? key,
    required this.phoneNumber,
    required this.userId,
  }) : super(key: key);

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final LoginService _loginService = LoginService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    for (final node in _focusNodes) {
      node.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final n in _focusNodes) {
      n.removeListener(_onFocusChange);
      n.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(String value, int index) {
    // Handle full OTP paste (e.g., from SMS auto-fill or clipboard)
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < digits.length && (index + i) < 6; i++) {
        _controllers[index + i].text = digits[i];
      }
      final nextIndex = (index + digits.length).clamp(0, 5);
      _focusNodes[nextIndex].requestFocus();
      setState(() {});
      _autoSubmitIfComplete();
      return;
    }

    setState(() {});

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _autoSubmitIfComplete();
      }
    } else if (index > 0) {
      // Backspace on a field that just became empty → go back
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _autoSubmitIfComplete() {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == 6) _verifyOTP();
  }

  Future<void> _verifyOTP() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      _showSnackBar('Please enter the complete 6-digit OTP', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _loginService.verifyOtp(widget.phoneNumber, otp);

      if (response != null) {
        final isProfileCompleted = response.nextScreen != 'SIGNUP';
        await AuthService.saveUserSession(
          userId: response.userId,
          phone: widget.phoneNumber,
          isProfileCompleted: isProfileCompleted,
        );
        await DeviceTokenService.initialize();

        if (mounted) {
          if (!isProfileCompleted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => SignupScreen(
                  widget.phoneNumber,
                  isKycRequired: false,
                  userId: response.userId,
                ),
              ),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomePageWithNav()),
              (route) => false,
            );
          }
        }
      } else {
        if (mounted)
          _showSnackBar('Invalid OTP. Please try again.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('BACKEND_DOWN')) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BackendDownScreen()),
          );
          return;
        }
        _showSnackBar('Error: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'LOGO',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 64),
                Text(
                  'OTP Verification',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter the 6-digit code sent to',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '+91 ${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF001127),
                  ),
                ),
                const SizedBox(height: 40),

                // ── OTP Fields ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                      6,
                      (index) => _OtpBox(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            enabled: !_isLoading,
                            onChanged: (v) => _onDigitChanged(v, index),
                          )),
                ),

                const SizedBox(height: 36),

                // ── Verify Button ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF001127),
                      disabledBackgroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Verify OTP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Resend hint ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code? ",
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    GestureDetector(
                      onTap: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text(
                        'Change Number',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF001127),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Individual OTP digit box ──────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFocused = focusNode.hasFocus;
    final isFilled = controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 46,
      height: 56,
      decoration: BoxDecoration(
        color: isFocused
            ? const Color(0xFF001127).withValues(alpha: 0.06)
            : isFilled
                ? const Color(0xFF001127).withValues(alpha: 0.03)
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused
              ? const Color(0xFF001127)
              : isFilled
                  ? const Color(0xFF001127).withValues(alpha: 0.4)
                  : Theme.of(context).dividerColor,
          width: isFocused ? 2 : 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 6, // allow pasting full OTP; distributed in onChanged
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface,
          height: 1,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
