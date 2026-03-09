import 'package:dolo/Controllers/AuthService.dart';
import 'package:dolo/Controllers/ProfileService.dart';
import 'package:dolo/screens/NotificationsScreen.dart';
import 'package:dolo/screens/ProfileSection/profilescreen.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class ModernHomeScreen extends StatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  State<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends State<ModernHomeScreen> {
  int _currentCarouselIndex = 0;
  int _currentStep = 0;
  String? _userName;

  // ── Carousel items — colors adapt to theme inside build ──
  final List<Map<String, dynamic>> _carouselItems = [
    {
      'title': 'Fast Delivery',
      'description': 'Get your parcels delivered quickly',
      'iconData': Icons.local_shipping_outlined,
    },
    {
      'title': 'Track Orders',
      'description': 'Monitor your shipments in real-time',
      'iconData': Icons.track_changes_outlined,
    },
    {
      'title': 'Secure Payment',
      'description': 'Safe and encrypted transactions',
      'iconData': Icons.lock_outline,
    },
  ];

  final List<Map<String, String>> _howItWorksSteps = [
    {
      'step': '1',
      'title': 'Create Order',
      'description': 'Post your delivery requirements',
    },
    {
      'step': '2',
      'title': 'Find Traveler',
      'description': 'Match with available travelers',
    },
    {
      'step': '3',
      'title': 'Track Shipment',
      'description': 'Monitor your parcel in transit',
    },
    {
      'step': '4',
      'title': 'Receive Parcel',
      'description': 'Get your delivery confirmed',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = await AuthService.getUserId();
    if (userId != null) {
      final profileService = ProfileService();
      final userProfile = await profileService.getUserProfile(userId);
      if (userProfile != null) {
        setState(() {
          _userName = userProfile.name;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme, colorScheme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildGreeting(theme, colorScheme),
                    const SizedBox(height: 20),
                    _buildCarousel(theme, colorScheme, isDark),
                    const SizedBox(height: 24),
                    _buildActionButtons(theme, colorScheme),
                    const SizedBox(height: 24),
                    _buildTrackOrdersButton(theme, colorScheme),
                    const SizedBox(height: 32),
                    _buildHowItWorksSection(theme, colorScheme),
                    const SizedBox(height: 32),
                    _buildFooter(theme, colorScheme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Header
  // ────────────────────────────────────────────────────────────────
  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      // Use card colour so it lifts slightly from scaffold in both modes
      color: theme.cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'LOGO',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                letterSpacing: 1,
              ),
            ),
          ),

          // Icons
          Row(
            children: [
              // Notification
              IconButton(
                icon: Icon(Icons.notifications_outlined,
                    color: colorScheme.onSurface),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),

              // Profile avatar
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.primary,
                      child: Text(
                        _userName != null && _userName!.isNotEmpty
                            ? _userName![0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: theme.cardColor, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Greeting
  // ────────────────────────────────────────────────────────────────
  Widget _buildGreeting(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, ${_userName ?? 'there'} 👋',
            style: theme.textTheme.displayMedium?.copyWith(fontSize: 26) ??
                TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Where are you delivering today?',
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Carousel
  // ────────────────────────────────────────────────────────────────
  Widget _buildCarousel(
      ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 160,
            viewportFraction: 0.85,
            enlargeCenterPage: true,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            onPageChanged: (index, reason) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
          ),
          items: _carouselItems.asMap().entries.map((entry) {
            final item = entry.value;
            // Rotate through brand palette
            final gradients = [
              [colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.12),
                colorScheme.secondary.withValues(alpha: isDark ? 0.2 : 0.06)],
              [colorScheme.secondary.withValues(alpha: isDark ? 0.35 : 0.15),
                colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.05)],
              [colorScheme.tertiary.withValues(alpha: isDark ? 0.35 : 0.2),
                colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.05)],
            ];
            final grad = gradients[entry.key % gradients.length];

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: grad,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'],
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['description'],
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      item['iconData'] as IconData,
                      size: 48,
                      color: colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _carouselItems.asMap().entries.map((entry) {
            final isActive = _currentCarouselIndex == entry.key;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isActive ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Action Buttons
  // ────────────────────────────────────────────────────────────────
  Widget _buildActionButtons(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              theme, colorScheme,
              'Send Parcel',
              Icons.send_outlined,
              isPrimary: true,
              onTap: () {},
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionButton(
              theme, colorScheme,
              'Find Parcel',
              Icons.search,
              isPrimary: false,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      ThemeData theme,
      ColorScheme colorScheme,
      String label,
      IconData icon, {
        required bool isPrimary,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isPrimary
              ? colorScheme.primary
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary
              ? null
              : Border.all(color: theme.dividerColor),
          boxShadow: isPrimary
              ? [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 30,
                color: isPrimary
                    ? Colors.white
                    : colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary
                    ? Colors.white
                    : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Track Orders
  // ────────────────────────────────────────────────────────────────
  Widget _buildTrackOrdersButton(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.my_location_outlined,
                  size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Track Orders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // How It Works
  // ────────────────────────────────────────────────────────────────
  Widget _buildHowItWorksSection(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: theme.textTheme.titleLarge ??
                TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 16),

          // Step circles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _howItWorksSteps.map((step) {
              final index = _howItWorksSteps.indexOf(step);
              final isActive = index == _currentStep;

              return GestureDetector(
                onTap: () => setState(() => _currentStep = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? colorScheme.primary
                          : theme.dividerColor,
                      width: 1.5,
                    ),
                    boxShadow: isActive
                        ? [
                      BoxShadow(
                        color: colorScheme.primary
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      step['step']!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? Colors.white
                            : colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Step description card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _howItWorksSteps[_currentStep]['title']!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _howItWorksSteps[_currentStep]['description']!,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Footer
  // ────────────────────────────────────────────────────────────────
  Widget _buildFooter(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        children: [
          // Logo box
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'dolo',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: colorScheme.primary,
                letterSpacing: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Illustration grid
          Container(
            width: 200,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 32,
                        color: colorScheme.primary.withValues(alpha: 0.5)),
                    Icon(Icons.local_shipping_outlined,
                        size: 32,
                        color: colorScheme.primary.withValues(alpha: 0.5)),
                    Icon(Icons.delivery_dining_outlined,
                        size: 32,
                        color: colorScheme.primary.withValues(alpha: 0.5)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(Icons.directions_car_outlined,
                        size: 32,
                        color: colorScheme.secondary.withValues(alpha: 0.5)),
                    Icon(Icons.inventory_2_outlined,
                        size: 32,
                        color: colorScheme.secondary.withValues(alpha: 0.5)),
                    Icon(Icons.location_pin,
                        size: 32,
                        color: colorScheme.secondary.withValues(alpha: 0.5)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tagline
          Text(
            'Smarter Logistics.',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.45),
              letterSpacing: 0.5,
            ),
          ),
          Text(
            'Connected Community.',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.45),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}