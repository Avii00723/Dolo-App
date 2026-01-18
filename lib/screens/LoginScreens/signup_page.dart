import 'package:flutter/material.dart';
import '../../Controllers/LoginService.dart';
import '../../Controllers/AuthService.dart';
import '../../Models/LoginModel.dart';
import 'package:dolo/screens/home/homepage.dart';

class SignupScreen extends StatefulWidget {
  final bool isKycRequired;
  final String? userId;

  const SignupScreen({
    Key? key,
    this.isKycRequired = false,
    this.userId,
  }) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final LoginService _loginService = LoginService();

  // Form controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  bool _isLoading = false;
  String? _currentUserId;
  String _selectedGender = 'male';

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // Load user ID from secure storage
  Future<void> _loadUserId() async {
    try {
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        setState(() {
          _currentUserId = widget.userId;
        });
        debugPrint('✅ UserId loaded from parameter: ${widget.userId}');
        return;
      }

      final userId = await AuthService.getUserId();
      setState(() {
        _currentUserId = userId;
      });
      debugPrint('✅ UserId loaded from secure storage: $userId');
    } catch (e) {
      debugPrint('❌ Error loading userId: $e');
    }
  }

  // Submit signup form - NEW API LOGIC
  Future<void> _submitSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? userId = _currentUserId ?? widget.userId;
      if (userId == null || userId.isEmpty) {
        userId = await AuthService.getUserId();
      }

      debugPrint('=== Submit Signup Started ===');
      debugPrint('UserId: $userId');

      if (userId == null || userId.isEmpty) {
        _showSnackBar('User not authenticated. Please login again.', isError: true);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Create signup request with NEW API structure
      final signupRequest = SignupRequest(
        userId: userId,
        name: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        dob: _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
        gender: _selectedGender,
        isEmailVerified: true, // Assuming email is verified during signup
      );

      debugPrint('Calling signup API with data: ${signupRequest.toJson()}');

      final signupResult = await _loginService.completeSignup(signupRequest);

      if (signupResult == null) {
        throw Exception('Failed to complete signup');
      }

      debugPrint('✅ Signup completed successfully');
      debugPrint('Next Screen: ${signupResult.nextScreen}');

      // Save user session to secure storage
      final phone = await AuthService.getPhone();
      if (phone != null) {
        await AuthService.saveUserSession(
          userId: userId,
          phone: phone,
        );
        debugPrint('✅ User session confirmed in secure storage');
      }

      _showSnackBar('Profile created successfully!');

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        // Navigate based on nextScreen response
        if (signupResult.nextScreen == 'KYC') {
          // Navigate to KYC screen or show KYC prompt
          debugPrint('KYC required - navigating to home');
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePageWithNav()),
              (route) => false,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _submitSignup: $e');
      debugPrint('Stack trace: $stackTrace');
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Pick date of birth
  Future<void> _pickDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF001127),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // Sign Up Title
                const Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF001127),
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Enter Information to Create a Account',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 30),

                // Tagline
                const Text(
                  'Lets Learn and Celebrate\nFestivals Together!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF001127),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // First Name and Last Name in Row
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _firstNameController,
                        hintText: 'First Name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (value.trim().length < 2) {
                            return 'Min 2 chars';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _lastNameController,
                        hintText: 'Last Name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (value.trim().length < 2) {
                            return 'Min 2 chars';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Email Field
                _buildTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Date of Birth Field (Optional)
                GestureDetector(
                  onTap: _pickDateOfBirth,
                  child: AbsorbPointer(
                    child: _buildTextField(
                      controller: _dobController,
                      hintText: 'Date of Birth',
                      suffixIcon: Icons.calendar_today,
                      validator: null, // Optional field
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Gender Selection
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gender',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGenderOption('Male', 'male'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildGenderOption('Female', 'female'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Get Started Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF001127),
                      disabledBackgroundColor: Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                        : const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    IconData? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: keyboardType == TextInputType.emailAddress
          ? TextCapitalization.none
          : TextCapitalization.words,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF001127),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 14,
          color: Colors.grey[400],
        ),
        suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.grey[600]) : null,
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFF001127), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildGenderOption(String label, String value) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? const Color(0xFF001127) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF001127) : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF001127) : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                child: Icon(
                  Icons.circle,
                  size: 10,
                  color: Colors.white,
                ),
              )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.black : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}