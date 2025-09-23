import 'package:flutter/material.dart';
import '../LoginScreens/signup_page.dart';

class ProfileDetailsPage extends StatelessWidget {
  final Map<String, dynamic> userData;

  const ProfileDetailsPage({
    Key? key,
    required this.userData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile Details',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SignupScreen(isKycRequired: false),
                ),
              ).then((result) {
                if (result == true) {
                  Navigator.pop(context, true); // Return to previous screen and refresh
                }
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo[600]!, Colors.indigo[800]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Profile Image
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: userData['profileUrl'] != null &&
                              userData['profileUrl'].isNotEmpty
                              ? NetworkImage(userData['profileUrl'])
                              : null,
                          child: userData['profileUrl'] == null ||
                              userData['profileUrl'].isEmpty
                              ? Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.grey[400],
                          )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name
                      Text(
                        userData['name'] ?? 'No Name',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // User Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          userData['userType']?.toString().toUpperCase() ?? 'USER',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Personal Information Card
              _buildInfoCard(
                title: 'Personal Information',
                icon: Icons.person_outline,
                children: [
                  _buildInfoRow('Full Name', userData['name'] ?? 'Not provided'),
                  _buildInfoRow('Email', userData['email'] ?? 'Not provided'),
                  _buildInfoRow('Phone', userData['phone'] ?? 'Not provided'),
                  _buildInfoRow('User Type', userData['userType'] ?? 'Not specified'),
                ],
              ),
              const SizedBox(height: 16),

              // Account Information Card
              _buildInfoCard(
                title: 'Account Information',
                icon: Icons.account_circle_outlined,
                children: [
                  _buildInfoRow('User ID', userData['uid'] ?? 'Not available'),
                  _buildInfoRow('Profile Status',
                      (userData['profileCompleted'] ?? false) ? 'Complete' : 'Incomplete'),
                  _buildInfoRow('Wallet Balance', '₹${userData['walletBalance'] ?? 0}'),
                  _buildInfoRow('Member Since',
                      _formatDate(userData['createdAt'])),
                  _buildInfoRow('Last Login',
                      _formatDate(userData['lastLogin'])),
                ],
              ),
              const SizedBox(height: 16),

              // KYC Information Card
              if (userData['userType'] == 'traveller' ||
                  userData['kycStatus'] != 'not_required')
                _buildInfoCard(
                  title: 'KYC Information',
                  icon: Icons.security_outlined,
                  children: [
                    _buildInfoRowWithStatus(
                      'KYC Status',
                      userData['kycStatus'] ?? 'Not started',
                      _getKycStatusColor(userData['kycStatus']),
                    ),
                    if (userData['aadhaar'] != null)
                      _buildInfoRow('Aadhaar',
                          '****-****-${userData['aadhaar'].toString().substring(8)}'),
                    if (userData['licenseStatus'] != null)
                      _buildInfoRowWithStatus(
                        'Driving License',
                        userData['licenseStatus'] == 'uploaded' ? 'Uploaded' : 'Not uploaded',
                        userData['licenseStatus'] == 'uploaded' ? Colors.green : Colors.orange,
                      ),
                  ],
                ),
              const SizedBox(height: 24),

              // Update Profile Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignupScreen(isKycRequired: false),
                      ),
                    ).then((result) {
                      if (result == true) {
                        Navigator.pop(context, true);
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF001127),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Update Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.indigo[800],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithStatus(String label, String value, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getKycStatusColor(String? status) {
    switch (status) {
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'not_required':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Not available';

    try {
      DateTime date;
      if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        date = timestamp.toDate();
      }

      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Not available';
    }
  }
}