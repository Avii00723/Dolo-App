import 'package:flutter/material.dart';
import '../../Constants/colorconstant.dart';
import '../../Constants/ApiConstants.dart';
import '../../Controllers/ProfileService.dart';
import '../../Controllers/AuthService.dart';
import '../../Controllers/tutorial_service.dart';
import '../../Models/TrustScoreModel.dart';
import '../LoginScreens/LoginSignupScreen.dart';
import '../LoginScreens/signup_page.dart';
import 'ProfileDetailPage.dart';
import '../../Models/LoginModel.dart';
import '../../widgets/NotificationBellIcon.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  UserProfile? userProfile;
  TrustScore? trustScoreData; // UPDATED TYPE
  String? userId;
  bool isLoading = true;
  bool profileExists = false;
  bool notificationsEnabled = true;
  bool locationEnabled = true;
  bool darkModeEnabled = false;
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

      userId = await AuthService.getUserId();

      if (userId == null) {
        print('⚠️ No userId found - navigating to login');
        await _navigateToLogin('Session expired. Please login again.');
        return;
      }

      final results = await Future.wait([
        _profileService.getUserProfile(userId!),
        _profileService.getUserTrustScore(userId!),
      ]);

      final profile = results[0] as UserProfile?;
      final trustScore = results[1] as TrustScore?; // UPDATED TYPE

      if (profile != null) {
        setState(() {
          userProfile = profile;
          trustScoreData = trustScore;
          profileExists = true;
          isLoading = false;
          notificationsEnabled = true;
        });
        _animationController.forward();
      } else {
        final stillLoggedIn = await AuthService.isLoggedIn();

        if (!stillLoggedIn) {
          print('🚨 User session cleared - user does not exist in database');
          await _navigateToLogin('User account not found. Please login again.');
        } else {
          setState(() {
            profileExists = false;
            isLoading = false;
            trustScoreData = null;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Failed to load profile data');
    }
  }

  Future<void> _navigateToLogin(String message) async {
    await AuthService.clearUserSession();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginSignupScreen()),
          (Route<dynamic> route) => false,
    );
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
          _showSuccessSnackBar(enabled ? 'Notifications enabled' : 'Notifications disabled');
        } else {
          final stillLoggedIn = await AuthService.isLoggedIn();
          if (!stillLoggedIn) {
            print('🚨 User session cleared during update - user does not exist');
            await _navigateToLogin('User account not found. Please login again.');
          } else {
            _showErrorSnackBar('Failed to update notification preference');
          }
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

  String _getEmail() {
    return userProfile?.email ?? 'Not available';
  }

  String _getKycStatus() {
    return userProfile?.kycStatus ?? 'not_required';
  }

  bool _isProfileComplete() {
    return userProfile != null && userProfile!.name.isNotEmpty;
  }

  bool _isKycVerified() {
    return _getKycStatus() == 'approved';
  }

  // UPDATED: Get trust score display
  String _getTrustScoreDisplay() {
    if (trustScoreData == null) return '0/7';
    return '${trustScoreData!.trustScore}/${trustScoreData!.maxScore}';
  }

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
                Navigator.of(dialogContext).pop();
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext loadingContext) {
                    return WillPopScope(
                      onWillPop: () async => false,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                );

                try {
                  await AuthService.clearUserSession();
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginSignupScreen()),
                          (Route<dynamic> route) => false,
                    );
                  }
                } catch (e) {
                  print('❌ Logout error: $e');
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetTutorial() async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.refresh, color: Color(0xFF001127)),
              SizedBox(width: 12),
              Text('Reset Tutorial'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This will reset all tutorial progress and show the tutorials again when you navigate through the app.'),
              SizedBox(height: 8),
              Text(
                'This is useful if you want to learn about the app features again.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await TutorialService.resetAllTutorials();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tutorial reset successfully! Navigate through the app to see tutorials again.'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001127),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Reset Tutorial'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.grey[700], size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.grey[700], size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceRow(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF001127),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportInfoRow(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[600]),
          ],
        ),
      ),
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
      backgroundColor: Colors.grey[100],
      body: isLoading
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
        child: CustomScrollView(
          slivers: [
            // Custom App Bar with curved design
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Gray curved background
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Row(
                              children: [
                                NotificationBellIcon(
                                  onNotificationHandled: () => _loadUserData(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white),
                                  onPressed: () {
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
                                          _loadUserData();
                                        }
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // White curved overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(150),
                          topRight: Radius.circular(150),
                        ),
                      ),
                    ),
                  ),
                  // Profile Avatar
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[300],
                              child: Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          if (_isKycVerified())
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 16,
                              ),
                            )
                          else if (!_isProfileComplete())
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                'Unverified',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Profile Content
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 50),

                  // Name
                  Text(
                    _getDisplayName(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats Row - UPDATED with trust score
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBox('Trust Score', _getTrustScoreDisplay(), Icons.verified_user_outlined),
                        _buildStatBox('Ratings', '5.0 ★', Icons.star_outline),
                        _buildStatBox('Created', '35', Icons.add_box_outlined),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Complete Profile Progress (if incomplete)
                  if (!_isProfileComplete())
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Complete your profile',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '(${trustScoreData?.trustScore ?? 0}/${trustScoreData?.maxScore ?? 7})',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: trustScoreData != null
                                  ? trustScoreData!.trustScore / trustScoreData!.maxScore
                                  : 0.0,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF001127)),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        _buildActionButton(
                          'Upload your\nprofile picture',
                          Icons.person_outline,
                              () {
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
                                  _loadUserData();
                                }
                              });
                            } else {
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
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          'Verify\nEmail',
                          Icons.email_outlined,
                              () {
                            // Safe null/type checking for breakdown map
                            final emailVerified = trustScoreData?.breakdown != null &&
                                trustScoreData!.breakdown['email'] == 1;

                            if (emailVerified) {
                              _showSuccessSnackBar('Email already verified!');
                            } else {
                              _showSuccessSnackBar('Email verification coming soon!');
                            }
                          },
                        ),

                        const SizedBox(width: 12),
                        _buildActionButton(
                          'Verify KYC',
                          Icons.verified_user_outlined,
                              () => _showSuccessSnackBar('KYC verification coming soon!'),
                        ),
                      ],
                    ),
                  ),

                  // Account Details Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildAccountDetailRow(
                          Icons.phone_outlined,
                          _getPhoneNumber(),
                        ),
                        _buildAccountDetailRow(
                          Icons.email_outlined,
                          _getEmail(),
                        ),
                        if (_isKycVerified())
                          _buildAccountDetailRow(
                            Icons.verified_user,
                            'KYC verified',
                          ),
                      ],
                    ),
                  ),

                  // Preferences Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Preferences',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPreferenceRow('Location', locationEnabled, (val) {
                          setState(() {
                            locationEnabled = val;
                          });
                        }),
                        _buildPreferenceRow('Dark Mode', darkModeEnabled, (val) {
                          setState(() {
                            darkModeEnabled = val;
                          });
                        }),
                      ],
                    ),
                  ),

                  // Support & Info Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Support & Info',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSupportInfoRow('Help & Support', () => _showSuccessSnackBar('Support page coming soon!')),
                        _buildSupportInfoRow('Tutorial', _resetTutorial),
                        _buildSupportInfoRow('Contact Us', () => _showSuccessSnackBar('Contact page coming soon!')),
                        _buildSupportInfoRow('About Us', () => _showSuccessSnackBar('About page coming soon!')),
                        _buildSupportInfoRow('Terms & Conditions', () => _showSuccessSnackBar('Terms page coming soon!')),
                        _buildSupportInfoRow('Privacy Policy', () => _showSuccessSnackBar('Privacy policy coming soon!')),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // App Version
                  const Text(
                    'Dolo v1',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}