import 'package:dolo/screens/LoginScreens/login_page.dart';
import 'package:flutter/material.dart';
import '../../Constants/ApiConstants.dart';
import '../../Controllers/ProfileService.dart';
import '../../Controllers/AuthService.dart';
import '../../Controllers/tutorial_service.dart';
import '../../Models/TrustScoreModel.dart';
import '../../widgets/TrustScoreWidget.dart';
import '../LoginScreens/LoginSignupScreen.dart';
import '../LoginScreens/signup_page.dart';
import 'ProfileDetailPage.dart';
import '../../Models/LoginModel.dart';
import '../../widgets/NotificationBellIcon.dart';
import '../../theme/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  UserProfile? userProfile;
  TrustScore? trustScoreData;
  String? userId;
  bool isLoading = true;
  bool profileExists = false;
  bool notificationsEnabled = true;
  bool locationEnabled = true;
  bool darkModeEnabled = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int deliveredCount = 15;
  int createdCount = 35;
  double ratingsScore = 3.5;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
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
      setState(() => isLoading = true);
      userId = await AuthService.getUserId();

      if (userId == null) {
        await _navigateToLogin('Session expired. Please login again.');
        return;
      }

      final results = await Future.wait([
        _profileService.getUserProfile(userId!),
        _profileService.getUserTrustScore(userId!),
      ]);

      final profile = results[0] as UserProfile?;
      final trustScore = results[1] as TrustScore?;

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
      setState(() => isLoading = false);
      _showErrorSnackBar('Failed to load profile data');
    }
  }

  Future<void> _navigateToLogin(String message) async {
    await AuthService.clearUserSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          setState(() => notificationsEnabled = enabled);
          _showSuccessSnackBar(
              enabled ? 'Notifications enabled' : 'Notifications disabled');
        } else {
          final stillLoggedIn = await AuthService.isLoggedIn();
          if (!stillLoggedIn) {
            await _navigateToLogin(
                'User account not found. Please login again.');
          } else {
            _showErrorSnackBar('Failed to update notification preference');
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update notification preference');
    }
  }

  String _getDisplayName() => userProfile?.name ?? 'Complete Profile';
  String _getPhoneNumber() => userProfile?.phone ?? 'Not available';
  String _getEmail() => userProfile?.email ?? 'Not available';
  String _getKycStatus() => userProfile?.kycStatus ?? 'not_required';
  bool _isProfileComplete() =>
      userProfile != null && userProfile!.name.isNotEmpty;
  bool _isKycVerified() => _getKycStatus() == 'approved';
  bool _isProfilePictureUploaded() =>
      trustScoreData?.isProfileImageUploaded ?? false;
  bool _isEmailVerified() => trustScoreData?.isEmailVerified ?? false;
  bool _isKycCompleted() => _isKycVerified();

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.logout, color: AppColors.error),
            const SizedBox(width: 12),
            const Text('Logout'),
          ]),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to logout?'),
              SizedBox(height: 8),
              Text(
                'You will need to login again to access your account.',
                style: TextStyle(fontSize: 12, color: AppColors.mutedInk),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.mutedInk)),
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
                      child: const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primaryBlue)),
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
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Logout failed: $e'),
                        backgroundColor: AppColors.error));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.refresh, color: AppColors.primaryBlue),
            SizedBox(width: 12),
            Text('Reset Tutorial'),
          ]),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'This will reset all tutorial progress and show the tutorials again when you navigate through the app.'),
              SizedBox(height: 8),
              Text(
                'This is useful if you want to learn about the app features again.',
                style: TextStyle(fontSize: 12, color: AppColors.mutedInk),
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
                  _showSuccessSnackBar(
                      'Tutorial reset successfully! Navigate through the app to see tutorials again.');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Reset Tutorial'),
            ),
          ],
        );
      },
    );
  }

  // ── Stat box ──────────────────────────────────────────────────────────────
  Widget _buildStatBox(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.mutedInk),
            ),
          ],
        ),
      ),
    );
  }

  // ── Completion step card ──────────────────────────────────────────────────
  Widget _buildCompletionStepCard({
    required String title,
    required String buttonText,
    required IconData icon,
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? AppColors.success.withOpacity(0.5)
              : AppColors.border,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.mist,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color:
                      isCompleted ? AppColors.success : AppColors.primaryBlue,
                ),
              ),
              if (isCompleted)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: AppColors.success, shape: BoxShape.circle),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCompleted ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isCompleted ? AppColors.success : AppColors.primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.success,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 7),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                isCompleted ? 'Done' : buttonText,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section card wrapper ──────────────────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    required IconData titleIcon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(titleIcon, color: AppColors.primaryBlue, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.ink)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceRow(
      String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: AppColors.ink)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.ink)),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.mutedInk),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: AppColors.error,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mist,
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryBlue),
                  SizedBox(height: 16),
                  Text('Loading your profile...',
                      style: TextStyle(color: AppColors.mutedInk)),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppColors.primaryBlue,
              onRefresh: _loadUserData,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: CustomScrollView(
                  slivers: [
                    // ── Header ──────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Gradient banner
                          Container(
                            height: 230,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primaryBlueDark,
                                  AppColors.primaryBlue,
                                  AppColors.heroBlue,
                                ],
                              ),
                            ),
                            child: SafeArea(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back,
                                          color: Colors.white),
                                      onPressed: () =>
                                          Navigator.pop(context),
                                    ),
                                    Row(
                                      children: [
                                        NotificationBellIcon(
                                          onNotificationHandled: () =>
                                              _loadUserData(),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              color: Colors.white),
                                          onPressed: () {
                                            if (profileExists &&
                                                userProfile != null &&
                                                userId != null) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ProfileDetailsPage(
                                                    userProfile: userProfile!,
                                                    userId: userId!,
                                                  ),
                                                ),
                                              ).then((result) {
                                                if (result == true)
                                                  _loadUserData();
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

                          // Curved white base
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 72,
                              decoration: const BoxDecoration(
                                color: AppColors.mist,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(140),
                                  topRight: Radius.circular(140),
                                ),
                              ),
                            ),
                          ),

                          // Avatar
                          Positioned(
                            bottom: 32,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 4),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              AppColors.ink.withOpacity(0.18),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 52,
                                      backgroundColor: AppColors.heroBlue,
                                      child: userProfile?.photoURL != null &&
                                              userProfile!.photoURL!.isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                userProfile!.photoURL!
                                                        .startsWith('http')
                                                    ? userProfile!.photoURL!
                                                    : '${ApiConstants.imagebaseUrl}${userProfile!.photoURL}',
                                                width: 104,
                                                height: 104,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(Icons.person,
                                                        size: 52,
                                                        color: Colors.white),
                                                loadingBuilder: (_, child,
                                                    progress) {
                                                  if (progress == null)
                                                    return child;
                                                  return const CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2);
                                                },
                                              ),
                                            )
                                          : const Icon(Icons.person,
                                              size: 52, color: Colors.white),
                                    ),
                                  ),
                                  if (_isKycVerified())
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                          color: AppColors.success,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.verified,
                                          color: Colors.white, size: 14),
                                    )
                                  else if (!_isProfileComplete())
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.mutedInk,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'Incomplete',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Body ────────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 48),

                          // Name + status
                          Text(
                            _getDisplayName(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_isKycVerified())
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.success.withOpacity(0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified,
                                      size: 13, color: AppColors.success),
                                  SizedBox(width: 4),
                                  Text('KYC Verified',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Stats row
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                _buildStatBox('Delivered',
                                    '$deliveredCount', Icons.local_shipping_outlined),
                                const SizedBox(width: 10),
                                _buildStatBox(
                                    'Ratings', '$ratingsScore/4', Icons.star_outline),
                                const SizedBox(width: 10),
                                _buildStatBox(
                                  'Trust',
                                  trustScoreData != null
                                      ? '${trustScoreData!.trustScore}/${trustScoreData!.maxScore}'
                                      : '0/7',
                                  Icons.shield_outlined,
                                ),
                                const SizedBox(width: 10),
                                _buildStatBox('Created',
                                    '$createdCount', Icons.add_box_outlined),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Trust score widget
                          if (trustScoreData != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 4),
                              child: TrustScoreWidget(
                                trustScore: trustScoreData,
                                showBreakdown: true,
                                isCompact: false,
                              ),
                            ),

                          // Profile completion
                          if (trustScoreData != null &&
                              trustScoreData!.completionPercentage < 100)
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                                boxShadow: const [
                                  BoxShadow(
                                      color: AppColors.shadow,
                                      blurRadius: 8,
                                      offset: Offset(0, 3)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Complete your profile',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.ink)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryBlue
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${trustScoreData!.completionPercentage}%',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: trustScoreData!.trustScore /
                                          trustScoreData!.maxScore,
                                      backgroundColor: AppColors.border,
                                      valueColor:
                                          const AlwaysStoppedAnimation(
                                              AppColors.primaryBlue),
                                      minHeight: 7,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildCompletionStepCard(
                                          title: 'Upload\nProfile Photo',
                                          buttonText: 'Upload',
                                          icon: Icons.person_outline,
                                          isCompleted:
                                              _isProfilePictureUploaded(),
                                          onTap: () async {
                                            if (profileExists &&
                                                userProfile != null &&
                                                userId != null) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ProfileDetailsPage(
                                                    userProfile: userProfile!,
                                                    userId: userId!,
                                                  ),
                                                ),
                                              ).then((result) {
                                                if (result == true)
                                                  _loadUserData();
                                              });
                                            } else {
                                              final phone = await AuthService
                                                  .getPhone();
                                              if (!mounted) return;
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      SignupScreen(
                                                    phone ?? '',
                                                    isKycRequired: false,
                                                    userId: userId,
                                                  ),
                                                ),
                                              ).then((result) {
                                                if (result == true)
                                                  _loadUserData();
                                              });
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        _buildCompletionStepCard(
                                          title: 'Enter Valid\nEmail',
                                          buttonText: 'Continue',
                                          icon: Icons.email_outlined,
                                          isCompleted: _isEmailVerified(),
                                          onTap: () => _showSuccessSnackBar(
                                              'Email verification coming soon!'),
                                        ),
                                        const SizedBox(width: 12),
                                        _buildCompletionStepCard(
                                          title: 'Complete\nKYC',
                                          buttonText: 'Verify',
                                          icon: Icons.verified_user_outlined,
                                          isCompleted: _isKycCompleted(),
                                          onTap: () => _showSuccessSnackBar(
                                              'KYC verification coming soon!'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 4),

                          // Account Details
                          _buildSectionCard(
                            title: 'Account Details',
                            titleIcon: Icons.account_circle_outlined,
                            children: [
                              _buildDetailRow(
                                  Icons.phone_outlined, _getPhoneNumber()),
                              const Divider(
                                  height: 1,
                                  indent: 46,
                                  color: AppColors.border),
                              _buildDetailRow(
                                  Icons.email_outlined, _getEmail()),
                              if (_isKycVerified()) ...[
                                const Divider(
                                    height: 1,
                                    indent: 46,
                                    color: AppColors.border),
                                _buildDetailRow(
                                    Icons.verified_user, 'KYC Verified'),
                              ],
                            ],
                          ),

                          // Preferences
                          _buildSectionCard(
                            title: 'Preferences',
                            titleIcon: Icons.tune_outlined,
                            children: [
                              _buildPreferenceRow(
                                'Location Services',
                                locationEnabled,
                                (val) =>
                                    setState(() => locationEnabled = val),
                              ),
                              const Divider(
                                  height: 1,
                                  indent: 16,
                                  color: AppColors.border),
                              _buildPreferenceRow(
                                'Dark Mode',
                                darkModeEnabled,
                                (val) =>
                                    setState(() => darkModeEnabled = val),
                              ),
                            ],
                          ),

                          // Support & Info
                          _buildSectionCard(
                            title: 'Support & Info',
                            titleIcon: Icons.help_outline_rounded,
                            children: [
                              _buildNavRow(
                                  Icons.headset_mic_outlined,
                                  'Help & Support',
                                  () => _showSuccessSnackBar(
                                      'Support page coming soon!')),
                              const Divider(
                                  height: 1,
                                  indent: 46,
                                  color: AppColors.border),
                              _buildNavRow(Icons.school_outlined, 'Tutorial',
                                  _resetTutorial),
                              const Divider(
                                  height: 1,
                                  indent: 46,
                                  color: AppColors.border),
                              _buildNavRow(
                                  Icons.mail_outline,
                                  'Contact Us',
                                  () => _showSuccessSnackBar(
                                      'Contact page coming soon!')),
                              const Divider(
                                  height: 1,
                                  indent: 46,
                                  color: AppColors.border),
                              _buildNavRow(
                                  Icons.info_outline,
                                  'About Us',
                                  () => _showSuccessSnackBar(
                                      'About page coming soon!')),
                              const Divider(
                                  height: 1,
                                  indent: 46,
                                  color: AppColors.border),
                              _buildNavRow(
                                  Icons.description_outlined,
                                  'Terms & Conditions',
                                  () => _showSuccessSnackBar(
                                      'Terms page coming soon!')),
                              const Divider(
                                  height: 1,
                                  indent: 46,
                                  color: AppColors.border),
                              _buildNavRow(
                                  Icons.privacy_tip_outlined,
                                  'Privacy Policy',
                                  () => _showSuccessSnackBar(
                                      'Privacy policy coming soon!')),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Logout button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _showLogoutDialog(context),
                                icon: const Icon(Icons.logout,
                                    color: AppColors.error, size: 18),
                                label: const Text('Logout',
                                    style: TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  side: const BorderSide(
                                      color: AppColors.error, width: 1.4),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // App version
                          Text(
                            'Dolo v1',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedInk.withOpacity(0.6),
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
