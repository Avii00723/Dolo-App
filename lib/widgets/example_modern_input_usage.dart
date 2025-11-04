import 'package:flutter/material.dart';
import 'ModernInputField.dart';

/// Example usage of ModernInputField widget with Floating Label Animation
/// This file demonstrates the modern input field with animated floating labels
/// Perfect for login, profile, and KYC pages
class ModernInputFieldExample extends StatefulWidget {
  const ModernInputFieldExample({super.key});

  @override
  State<ModernInputFieldExample> createState() => _ModernInputFieldExampleState();
}

class _ModernInputFieldExampleState extends State<ModernInputFieldExample> {
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Modern Input Field Examples'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Login Page Example
            const Text(
              'Login Page',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ModernInputField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'Enter your email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            ModernInputField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Enter your password',
              prefixIcon: Icons.lock_outlined,
              obscureText: true,
              showClearButton: false, // Usually don't show clear for password
            ),
            const SizedBox(height: 24),
            ModernButton(
              text: 'Login',
              onPressed: () {},
            ),

            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 48),

            // Profile Page Example
            const Text(
              'Profile Page',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ModernInputField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              prefixIcon: Icons.person_outlined,
            ),
            const SizedBox(height: 16),
            ModernInputField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: 'Enter your phone number',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 48),

            // Search Field (No Label)
            const Text(
              'Search Field',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ModernInputField(
              controller: _searchController,
              label: 'Search',
              hint: 'Type your text',
              prefixIcon: Icons.search,
              showLabel: false,
            ),

            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 48),

            // KYC Page Example
            const Text(
              'KYC Page',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ModernInputField(
              controller: TextEditingController(),
              label: 'PAN Card Number',
              hint: 'Enter PAN number',
              prefixIcon: Icons.credit_card,
            ),
            const SizedBox(height: 16),
            ModernInputField(
              controller: TextEditingController(),
              label: 'Aadhaar Number',
              hint: 'Enter Aadhaar number',
              prefixIcon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              maxLength: 12,
            ),
            const SizedBox(height: 16),
            ModernInputField(
              controller: TextEditingController(),
              label: 'Address',
              hint: 'Enter your complete address',
              prefixIcon: Icons.home_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ModernButton(
              text: 'Submit KYC',
              icon: Icons.check_circle_outline,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
