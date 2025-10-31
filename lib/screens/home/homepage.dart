import 'dart:async';
import 'package:dolo/screens/Inbox%20Section/indoxscreen.dart';
import 'package:dolo/screens/ProfileSection/profilescreen.dart';
import 'package:dolo/screens/orderSection/CreateOrderPage.dart';
import 'package:dolo/screens/orderSection/YourOrders.dart';
import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../screens/send_page.dart';
import '../../Controllers/tutorial_service.dart';
import '../../widgets/tutorial_helper.dart';

class HomePageWithNav extends StatefulWidget {
  const HomePageWithNav({super.key});

  @override
  State<HomePageWithNav> createState() => _HomePageWithNavState();
}

class _HomePageWithNavState extends State<HomePageWithNav> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  TutorialCoachMark? _tutorialCoachMark;

  // GlobalKeys for tutorial targets
  final GlobalKey _createButtonKey = GlobalKey();
  final GlobalKey _searchButtonKey = GlobalKey();
  final GlobalKey _ordersButtonKey = GlobalKey();
  final GlobalKey _inboxButtonKey = GlobalKey();
  final GlobalKey _profileButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndShowTutorial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Method to switch to Orders tab (called by CreateOrderPage)
  void switchToOrdersTab() {
    setState(() {
      _selectedIndex = 2; // Your Orders is at index 2
    });
  }

  // Fixed pages list with callback
  List<Widget> get _pages {
    return [
      CreateOrderPage(onOrderCreated: switchToOrdersTab), // Pass callback
      const SendPage(), // Search (index 1)
      const YourOrdersPage(), // Your Orders (index 2)
      const InboxScreen(), // Inbox (index 3)
      const ProfilePage(), // Profile (index 4)
    ];
  }

  // Fixed navigation items - same for all users
  List<BottomNavigationBarItem> _navItems() {
    return [
      BottomNavigationBarItem(
        icon: Container(
          key: _createButtonKey,
          child: const Icon(Icons.add_circle_outline),
        ),
        label: 'Create',
        activeIcon: const Icon(Icons.add_circle, size: 28),
      ),
      BottomNavigationBarItem(
        icon: Container(
          key: _searchButtonKey,
          child: const Icon(Icons.search),
        ),
        label: 'Search',
        activeIcon: const Icon(Icons.search, size: 28),
      ),
      BottomNavigationBarItem(
        icon: Container(
          key: _ordersButtonKey,
          child: const Icon(Icons.bookmark_border),
        ),
        label: 'Your Orders',
        activeIcon: const Icon(Icons.bookmark, size: 28),
      ),
      BottomNavigationBarItem(
        icon: Container(
          key: _inboxButtonKey,
          child: const Icon(Icons.chat_bubble_outline),
        ),
        label: 'Inbox',
        activeIcon: const Icon(Icons.chat_bubble, size: 28),
      ),
      BottomNavigationBarItem(
        icon: Container(
          key: _profileButtonKey,
          child: const Icon(Icons.person_outline),
        ),
        label: 'Profile',
        activeIcon: const Icon(Icons.person, size: 28),
      ),
    ];
  }

  void _onItemTapped(int index) {
    // Ensure index is within valid range
    if (index >= _pages.length || index < 0) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Check if tutorial should be shown for new users
  Future<void> _checkAndShowTutorial() async {
    // Wait for the widget to be built
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Check if home tutorial has been completed
    final isCompleted = await TutorialService.isHomeTutorialCompleted();

    if (!isCompleted) {
      _showTutorial();
    }
  }

  /// Show the home page tutorial
  void _showTutorial() {
    final targets = [
      TutorialHelper.createTarget(
        key: _createButtonKey,
        title: 'Create Order',
        description: 'Tap here to create a new delivery order. You can send packages, documents, or any items you need delivered.',
        order: 1,
        align: ContentAlign.top,
      ),
      TutorialHelper.createTarget(
        key: _searchButtonKey,
        title: 'Search Trips',
        description: 'Find available delivery trips posted by other users. You can join trips going in your direction to save money.',
        order: 2,
        align: ContentAlign.top,
      ),
      TutorialHelper.createTarget(
        key: _ordersButtonKey,
        title: 'Your Orders',
        description: 'View all your delivery orders and trip requests. Track the status of your deliveries and manage them easily.',
        order: 3,
        align: ContentAlign.top,
      ),
      TutorialHelper.createTarget(
        key: _inboxButtonKey,
        title: 'Inbox & Chat',
        description: 'Communicate with other users about your orders. Get real-time updates and notifications about your deliveries.',
        order: 4,
        align: ContentAlign.top,
      ),
      TutorialHelper.createFinalTarget(
        key: _profileButtonKey,
        title: 'Your Profile',
        description: 'Manage your account settings, view your delivery history, and update your personal information.',
        order: 5,
        align: ContentAlign.top,
        onFinish: () async {
          await TutorialService.markHomeTutorialCompleted();
        },
      ),
    ];

    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: const Color(0xFF001127),
      paddingFocus: 10,
      opacityShadow: 0.8,
      hideSkip: false,
      onSkip: () {
        TutorialService.markHomeTutorialCompleted();
        return true;
      },
      onFinish: () {
        TutorialService.markHomeTutorialCompleted();
      },
    );

    _tutorialCoachMark?.show(context: context);
  }

  @override
  Widget build(BuildContext context) {
    // Ensure selected index is within bounds
    if (_selectedIndex >= _pages.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      extendBody: false, // CHANGED: Set to false to prevent overlap
      backgroundColor: Colors.grey[50],
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: const Color(0xFF001127),
            unselectedItemColor: Colors.grey[600],
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedFontSize: 12,
            unselectedFontSize: 10,
            iconSize: 24,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w400,
            ),
            items: _navItems(),
          ),
        ),
      ),
    );
  }
}
