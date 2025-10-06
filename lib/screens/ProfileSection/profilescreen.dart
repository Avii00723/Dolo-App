import 'package:flutter/material.dart';
import '../../Constants/colorconstant.dart';
import '../../Controllers/ProfileService.dart';
import '../../Controllers/AuthService.dart'; // Import AuthService
import '../LoginScreens/LoginSignupScreen.dart';
import '../LoginScreens/signup_page.dart';
import 'ProfileDetailPage.dart';
import '../../Models/LoginModel.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  UserProfile? userProfile;
  int? userId;
  bool isLoading = true;
  bool profileExists = false;
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

      // ✅ Get userId from AuthService (Secure Storage)
      userId = await AuthService.getUserId();

      if (userId != null) {
        final profile = await _profileService.getUserProfile(userId!);
        if (profile != null) {
          setState(() {
            userProfile = profile;
            profileExists = true;
            isLoading = false;
            notificationsEnabled = true;
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

  Future<void> _updateNotificationPreference(bool enabled) async {
    try {
      if (userId != null) {
        final success = await _profileService.updateUserProfile(
          userId!,
          {'notificationsEnabled': enabled},
        );
        if (success) {
          setState(() {
            notificationsEnabled = enabled;
          });
          _showSuccessSnackBar(
              enabled ? 'Notifications enabled' : 'Notifications disabled'
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update notification preference');
    }
  }

  String _getDisplayName() {
    return userProfile?.name ?? 'Complete Profile';
  }

  String _getPhoneNumber() {
    return userProfile?.phone ?? 'Not available';
  }

  String _getKycStatus() {
    return userProfile?.kycStatus ?? 'not_required';
  }

  bool _isProfileComplete() {
    return userProfile != null && userProfile!.name.isNotEmpty;
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

// ✅ ALTERNATIVE ROBUST LOGOUT METHOD
// ✅ FIXED LOGOUT METHOD - Replace the entire _showLogoutDialog method
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red[700]),
              const SizedBox(width: 12),
              const Text('Logout'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to logout?'),
              SizedBox(height: 8),
              Text(
                'You will need to login again to access your account.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                // Close confirmation dialog first
                Navigator.of(dialogContext).pop();

                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext loadingContext) {
                    return WillPopScope(
                      onWillPop: () async => false,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                );

                try {
                  // Clear secure storage
                  await AuthService.clearUserSession();

                  // Small delay to ensure storage is cleared
                  await Future.delayed(const Duration(milliseconds: 300));

                  // Close loading dialog - Use rootNavigator
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }

                  // Small delay before navigation
                  await Future.delayed(const Duration(milliseconds: 100));

                  // Navigate to login screen and remove all previous routes
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginSignupScreen(),
                      ),
                          (Route<dynamic> route) => false,
                    );
                  }
                } catch (e) {
                  print('Logout error: $e');

                  // Close loading dialog on error
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }

                  // Show error message
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logout failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
  // In _buildProfileCard method, wrap the Card with InkWell
  Widget _buildProfileCard() {
    return FadeTransition(
      opacity: _animation,
      child: InkWell(
        onTap: () {
          if (profileExists && userProfile != null && userId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileDetailsPage(
                  userProfile: userProfile!,
                  userId: userId!,
                ),
              ),
            ).then((result) {
              if (result == true) {
                // Reload profile data after update
                _loadUserData();
              }
            });
          } else {
            // Navigate to complete profile
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SignupScreen(
                  isKycRequired: false,
                  userId: userId,
                ),
              ),
            ).then((result) {
              if (result == true) {
                _loadUserData();
              }
            });
          }
        },
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          shadowColor: Colors.black12,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          backgroundImage: userProfile?.photoURL != null &&
                              userProfile!.photoURL.isNotEmpty
                              ? NetworkImage(userProfile!.photoURL)
                              : null,
                          child: userProfile?.photoURL == null ||
                              userProfile!.photoURL.isEmpty
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
                              Icons.verified_user,
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
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ],
            ),
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
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 12),
            SizedBox(width: 4),
            Text(
              'VERIFIED',
              style: TextStyle(
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
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 16),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
        title: const Text(
          'Profile',
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
                  _buildProfileCard(),
                  const SizedBox(height: 16),
                  _buildMenuSection(
                    'Preferences',
                    [
                      _buildMenuItem(
                        icon: Icons.language,
                        title: 'Language',
                        subtitle: 'English',
                        onTap: () {
                          _showSuccessSnackBar('Language selection coming soon!');
                        },
                        iconColor: Colors.blue,
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
                          _showSuccessSnackBar('Support page coming soon!');
                        },
                        iconColor: Colors.cyan,
                      ),
                      _buildMenuItem(
                        icon: Icons.feedback_outlined,
                        title: 'Send Feedback',
                        subtitle: 'Help us improve',
                        onTap: () {
                          _showSuccessSnackBar('Feedback form coming soon!');
                        },
                        iconColor: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // ✅ LOGOUT BUTTON CONNECTED
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
}
