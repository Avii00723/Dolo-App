import 'package:dolo/screens/LoginScreens/login_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Constants/colorconstant.dart';
import '../../Constants/ApiConstants.dart';
import '../../Controllers/ProfileService.dart';
import '../../Controllers/AuthService.dart';
import '../../Controllers/tutorial_service.dart';
import '../../Models/TrustScoreModel.dart';
import '../../widgets/TrustScoreWidget.dart';
import '../LoginScreens/LoginSignupScreen.dart';
import '../LoginScreens/signup_page.dart';
import '../LoginScreens/kyc_screen.dart';
import 'ProfileDetailPage.dart';
import '../../Models/LoginModel.dart';
import '../../widgets/NotificationBellIcon.dart';
import '../../theme/theme_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  UserProfile? userProfile;
  TrustScore? trustScoreData;
  String? userId;
  bool isLoading = true;
  bool profileExists = false;
  bool notificationsEnabled = true;
  bool locationEnabled = true;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Stats data
  int deliveredCount = 15;
  int createdCount = 35;
  double ratingsScore = 3.5;

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
      if (!mounted) return;
      setState(() {
        isLoading = true;
      });

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

      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar('Failed to load profile data');
      }
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

  String _getDisplayName() => userProfile?.name ?? 'Complete Profile';
  String _getPhoneNumber() => userProfile?.phone ?? 'Not available';
  String _getEmail() => userProfile?.email ?? 'Not available';
  bool _isKycVerified() => userProfile?.kycStatus == 'approved';
  bool _isProfileComplete() => userProfile != null && userProfile!.name.isNotEmpty;

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
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await AuthService.clearUserSession();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (Route<dynamic> route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
              Icon(Icons.refresh),
              SizedBox(width: 12),
              Text('Reset Tutorial'),
            ],
          ),
          content: const Text('This will reset all tutorial progress.'),
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
                  _showSuccessSnackBar('Tutorial reset successfully!');
                }
              },
              child: const Text('Reset'),
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
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor, size: 24),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildCompletionStepCard({
    required String title,
    required String buttonText,
    required IconData icon,
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: isCompleted ? Colors.green : Colors.grey),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: isCompleted ? null : onTap,
            child: Text(isCompleted ? 'Completed' : buttonText, style: const TextStyle(fontSize: 11)),
          ),
        ],
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
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
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
          Text(label, style: const TextStyle(fontSize: 14)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
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
            Text(label, style: const TextStyle(fontSize: 14)),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadUserData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 220,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2B6390), // denimDark
                          Color(0xFF3E83AE), // denim
                        ],
                      ),
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
                                NotificationBellIcon(onNotificationHandled: _loadUserData),
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
                                        if (result == true) _loadUserData();
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
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(150),
                          topRight: Radius.circular(150),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF2B6390), // denimDark
                        backgroundImage: userProfile?.photoURL != null && userProfile!.photoURL.isNotEmpty
                            ? NetworkImage(userProfile!.photoURL.startsWith('http')
                            ? userProfile!.photoURL
                            : '${ApiConstants.imagebaseUrl}${userProfile!.photoURL}')
                            : null,
                        child: (userProfile?.photoURL == null || userProfile!.photoURL.isEmpty)
                            ? Text(
                          _getDisplayName().isNotEmpty
                              ? _getDisplayName()[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  Text(_getDisplayName(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBox('Delivered', '$deliveredCount', Icons.local_shipping_outlined),
                        _buildStatBox('Ratings', '$ratingsScore/4', Icons.star_outline),
                        _buildStatBox('Trust', trustScoreData != null ? '${trustScoreData!.trustScore}' : '0', Icons.shield_outlined),
                        _buildStatBox('Created', '$createdCount', Icons.add_box_outlined),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (trustScoreData != null && trustScoreData!.completionPercentage < 100)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Complete your profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('${trustScoreData!.completionPercentage}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: trustScoreData!.trustScore / trustScoreData!.maxScore,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
                            minHeight: 8,
                          ),
                          const SizedBox(height: 20),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildCompletionStepCard(
                                  title: 'Upload profile picture',
                                  buttonText: 'Upload',
                                  icon: Icons.person_outline,
                                  isCompleted: trustScoreData?.isProfileImageUploaded ?? false,
                                  onTap: () {},
                                ),
                                const SizedBox(width: 12),
                                _buildCompletionStepCard(
                                  title: 'Enter Email',
                                  buttonText: 'Continue',
                                  icon: Icons.email_outlined,
                                  isCompleted: trustScoreData?.isEmailVerified ?? false,
                                  onTap: () {},
                                ),
                                const SizedBox(width: 12),
                                _buildCompletionStepCard(
                                  title: 'Verify KYC',
                                  buttonText: 'Continue',
                                  icon: Icons.verified_user_outlined,
                                  isCompleted: _isKycVerified(),
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildSection(
                    title: 'Account Details',
                    children: [
                      _buildAccountDetailRow(Icons.phone_outlined, _getPhoneNumber()),
                      _buildAccountDetailRow(Icons.email_outlined, _getEmail()),
                      if (_isKycVerified()) _buildAccountDetailRow(Icons.verified_user, 'KYC verified'),
                    ],
                  ),
                  _buildSection(
                    title: 'Preferences',
                    children: [
                      _buildPreferenceRow('Location', locationEnabled, (val) => setState(() => locationEnabled = val)),
                      _buildPreferenceRow('Dark Mode', themeProvider.isDarkMode, (val) => themeProvider.toggleTheme()),
                    ],
                  ),
                  _buildSection(
                    title: 'Support & Info',
                    children: [
                      _buildSupportInfoRow('Help & Support', () {}),
                      _buildSupportInfoRow('Tutorial', _resetTutorial),
                      _buildSupportInfoRow('About Us', () {}),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showLogoutDialog(context),
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
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

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}