import 'package:dolo/screens/LoginScreens/login_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../Constants/colorconstant.dart';
import '../LoginScreens/signup_page.dart';
import 'ProfileDetailPage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool profileExists = false;
  bool isUpdatingUserType = false;
  bool notificationsEnabled = true;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        isLoading = true;
      });

      final String? userId = _auth.currentUser?.uid;
      if (userId != null) {
        final DocumentSnapshot doc =
        await _firestore.collection('users').doc(userId).get();

        if (doc.exists) {
          setState(() {
            userData = doc.data() as Map<String, dynamic>;
            profileExists = true;
            isLoading = false;
            notificationsEnabled = userData!['notificationsEnabled'] ?? true;
          });
          _animationController.forward();
        } else {
          setState(() {
            profileExists = false;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Failed to load profile data');
    }
  }

  Future<void> _updateUserType(String newUserType) async {
    if (isUpdatingUserType) return;

    setState(() {
      isUpdatingUserType = true;
    });

    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'userType': newUserType,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          if (userData != null) {
            userData!['userType'] = newUserType;
          }
        });

        _showSuccessSnackBar('Switched to ${newUserType.toUpperCase()} mode');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update user type: $e');
    } finally {
      setState(() {
        isUpdatingUserType = false;
      });
    }
  }

  Future<void> _updateNotificationPreference(bool enabled) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'notificationsEnabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          notificationsEnabled = enabled;
          if (userData != null) {
            userData!['notificationsEnabled'] = enabled;
          }
        });

        _showSuccessSnackBar(enabled ? 'Notifications enabled' : 'Notifications disabled');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update notification preference');
    }
  }

  String _getDisplayName() {
    if (userData != null && userData!['name'] != null) {
      return userData!['name'];
    }
    return 'Complete Profile';
  }

  String _getPhoneNumber() {
    if (userData != null && userData!['phone'] != null) {
      return userData!['phone'];
    }
    return _auth.currentUser?.phoneNumber ?? 'Not available';
  }

  String _getKycStatus() {
    if (userData != null && userData!['kycStatus'] != null) {
      return userData!['kycStatus'];
    }
    return 'not_required';
  }

  String _getUserType() {
    if (userData != null && userData!['userType'] != null) {
      return userData!['userType'];
    }
    return 'sender';
  }

  bool _isProfileComplete() {
    return userData != null && (userData!['profileCompleted'] ?? false);
  }

  String _getUserInitials() {
    String name = _getDisplayName();
    if (name == 'Complete Profile') return 'U';

    List<String> nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // Theme Toggle Style User Type Selector
  Widget _buildUserTypeToggle() {
    if (!_isProfileComplete()) return const SizedBox.shrink();

    String currentUserType = _getUserType();
    bool isTraveller = currentUserType.toLowerCase() == 'traveller';

    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(_animation),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: Colors.black12,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.swap_horiz,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'User Mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Main Toggle Section
                Row(
                  children: [
                    // Left Label (Active Mode)
                    Text(
                      isTraveller ? 'TRAVELLER' : 'SENDER',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),

                    // Toggle Switch Container
                    GestureDetector(
                      onTap: isUpdatingUserType ? null : () {
                        _updateUserType(isTraveller ? 'sender' : 'traveller');
                      },
                      child: Container(
                        width: 80,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.grey[400]!,
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Animated toggle button
                            AnimatedAlign(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              alignment: isTraveller
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                width: 36,
                                height: 36,
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 150),
                                    child: Icon(
                                      isTraveller
                                          ? Icons.local_shipping
                                          : Icons.inventory_2,
                                      key: ValueKey(isTraveller),
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Description Text
                Text(
                  isTraveller
                      ? 'Tap to switch to SENDER mode'
                      : 'Tap to switch to TRAVELLER mode',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // Loading indicator
                if (isUpdatingUserType) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Updating user mode...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Feature description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isTraveller ? Icons.local_shipping : Icons.inventory_2,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isTraveller
                              ? 'Deliver packages on your travel routes and earn money'
                              : 'Send packages through trusted travellers safely',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            height: 1.3,
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
      ),
    );
  }

  Widget _buildProfileCard() {
    return FadeTransition(
      opacity: _animation,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
        shadowColor: Colors.black12,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // User Avatar and Basic Info
              Row(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        backgroundImage: userData?['profileUrl'] != null &&
                            userData!['profileUrl'].isNotEmpty
                            ? NetworkImage(userData!['profileUrl'])
                            : null,
                        child: userData?['profileUrl'] == null || userData!['profileUrl'].isEmpty
                            ? Text(
                          _getUserInitials(),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                            : null,
                      ),
                      if (_isProfileComplete())
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getUserType().toLowerCase() == 'traveller'
                                ? Icons.local_shipping
                                : Icons.inventory_2,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getDisplayName(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: profileExists ? Colors.black : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getPhoneNumber(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildProfileStatusChip(),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (profileExists) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileDetailsPage(userData: userData!),
                          ),
                        ).then((result) {
                          if (result == true) {
                            _loadUserData();
                          }
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit, size: 16),
                    ),
                  ),
                ],
              ),

              // Complete Profile Button
              if (!_isProfileComplete()) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignupScreen(isKycRequired: false),
                        ),
                      ).then((result) {
                        if (result == true) {
                          _loadUserData();
                        }
                      });
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Complete Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],

              // KYC Information
              if (_isProfileComplete()) ...[
                const SizedBox(height: 20),
                Divider(color: Colors.grey[300]),
                const SizedBox(height: 16),
                _buildKycSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStatusChip() {
    if (!_isProfileComplete()) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 12),
            SizedBox(width: 4),
            Text(
              'Incomplete',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 12),
            const SizedBox(width: 4),
            Text(
              _getUserType().toUpperCase(),
              style: const TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildKycSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verification Status',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        _buildKycItem('KYC Status', _getKycStatusText(), _getKycStatusIcon(), _getKycStatusColor()[0]),
        if (userData?['aadhaar'] != null)
          _buildKycItem('Aadhaar', '****${userData!['aadhaar'].toString().substring(8)}', Icons.credit_card, Colors.blue),
        if (userData?['licenseStatus'] != null)
          _buildKycItem('License', userData!['licenseStatus'] == 'uploaded' ? 'Uploaded' : 'Not Uploaded', Icons.drive_eta, Colors.purple),
      ],
    );
  }

  Widget _buildKycItem(String title, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 1,
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: iconColor ?? AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null ? Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 16),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  List<dynamic> _getKycStatusColor() {
    switch (_getKycStatus()) {
      case 'verified':
        return [Colors.green, Colors.green[50]];
      case 'pending':
        return [Colors.orange, Colors.orange[50]];
      case 'not_required':
        return [Colors.blue, Colors.blue[50]];
      default:
        return [Colors.grey, Colors.grey[50]];
    }
  }

  IconData _getKycStatusIcon() {
    switch (_getKycStatus()) {
      case 'verified':
        return Icons.verified;
      case 'pending':
        return Icons.pending;
      case 'not_required':
        return Icons.info;
      default:
        return Icons.help;
    }
  }

  String _getKycStatusText() {
    switch (_getKycStatus()) {
      case 'verified':
        return 'Verified';
      case 'pending':
        return 'Pending';
      case 'not_required':
        return 'Not Required';
      default:
        return 'Unknown';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'DOLO',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _loadUserData,
              tooltip: 'Refresh profile',
            ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your profile...'),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadUserData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // User Profile Card
                  _buildProfileCard(),
                  const SizedBox(height: 16),
                  //
                  // // User Type Toggle
                  // _buildUserTypeToggle(),
                  // const SizedBox(height: 16),

                  // Settings Menu
                  _buildMenuSection(
                    'Preferences',
                    [
                      _buildMenuItem(
                        icon: Icons.language,
                        title: 'Language',
                        subtitle: 'English',
                        onTap: () {
                          // TODO: Implement language selection
                          _showSuccessSnackBar('Language selection coming soon!');
                        },
                        iconColor: Colors.blue,
                      ),
                      _buildMenuItem(
                        icon: Icons.lock_outline,
                        title: 'Change Password',
                        subtitle: 'Update your password',
                        onTap: () {
                          // TODO: Implement password change
                          _showSuccessSnackBar('Password change coming soon!');
                        },
                        iconColor: Colors.orange,
                      ),
                      _buildMenuItem(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: notificationsEnabled ? 'Enabled' : 'Disabled',
                        onTap: () {},
                        trailing: Switch(
                          value: notificationsEnabled,
                          onChanged: _updateNotificationPreference,
                          activeColor: AppColors.primary,
                        ),
                        iconColor: Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildMenuSection(
                    'Support & Info',
                    [
                      _buildMenuItem(
                        icon: Icons.help_outline,
                        title: 'Support',
                        subtitle: 'Get help and contact us',
                        onTap: () {
                          // TODO: Implement support
                          _showSuccessSnackBar('Support page coming soon!');
                        },
                        iconColor: Colors.cyan,
                      ),
                      _buildMenuItem(
                        icon: Icons.feedback_outlined,
                        title: 'Send Feedback',
                        subtitle: 'Help us improve',
                        onTap: () {
                          // TODO: Implement feedback
                          _showSuccessSnackBar('Feedback form coming soon!');
                        },
                        iconColor: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Log Out Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Log Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performLogout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _performLogout(BuildContext context) async {
    try {
      await _auth.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      _showErrorSnackBar('Error signing out: $e');
    }
  }
}
