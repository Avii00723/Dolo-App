import 'dart:async';
import 'package:dolo/screens/Inbox%20Section/indoxscreen.dart';
import 'package:dolo/screens/home/home.dart';
import 'package:dolo/screens/orderSection/CreateOrderPage.dart';
import 'package:dolo/screens/orderSection/YourOrders.dart';
import 'package:flutter/material.dart';
import 'package:motion_tab_bar_v2/motion-tab-bar.dart';
import 'package:motion_tab_bar_v2/motion-tab-controller.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../screens/send_page.dart';
import '../../Controllers/tutorial_service.dart';
import '../../widgets/tutorial_helper.dart';

class HomePageWithNav extends StatefulWidget {
  const HomePageWithNav({super.key});

  @override
  State<HomePageWithNav> createState() => _HomePageWithNavState();
}

class _HomePageWithNavState extends State<HomePageWithNav>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  MotionTabBarController? _motionTabBarController;
  TutorialCoachMark? _tutorialCoachMark;

  final GlobalKey _homeButtonKey = GlobalKey();
  final GlobalKey _searchButtonKey = GlobalKey();
  final GlobalKey _createButtonKey = GlobalKey();
  final GlobalKey _ordersButtonKey = GlobalKey();
  final GlobalKey _inboxButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motionTabBarController = MotionTabBarController(
      initialIndex: 0,
      length: 5,
      vsync: this,
    );
    _checkAndShowTutorial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motionTabBarController?.dispose();
    super.dispose();
  }

  void switchToOrdersTab() {
    _motionTabBarController?.index = 3;
  }

  List<Widget> get _pages => [
    const ModernHomeScreen(),
    const SendPage(),
    CreateOrderPage(onOrderCreated: switchToOrdersTab),
    const YourOrdersPage(),
    const InboxScreen(),
  ];

  Future<void> _checkAndShowTutorial() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final isCompleted = await TutorialService.isHomeTutorialCompleted();
    if (!isCompleted) {
      _showTutorial();
    }
  }

  void _showTutorial() {
    final targets = [
      TutorialHelper.createTarget(key: _homeButtonKey, title: 'Home', description: 'Your main dashboard...', order: 1, align: ContentAlign.top),
      TutorialHelper.createTarget(key: _searchButtonKey, title: 'Search Trips', description: 'Find available...', order: 2, align: ContentAlign.top),
      TutorialHelper.createTarget(key: _createButtonKey, title: 'Create Order', description: 'Create a new...', order: 3, align: ContentAlign.top),
      TutorialHelper.createTarget(key: _ordersButtonKey, title: 'Your Orders', description: 'View and manage...', order: 4, align: ContentAlign.top),
      TutorialHelper.createFinalTarget(key: _inboxButtonKey, title: 'Inbox & Chat', description: 'Communicate...', order: 5, align: ContentAlign.top, onFinish: () async {
        await TutorialService.markHomeTutorialCompleted();
      }),
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
      onFinish: () => TutorialService.markHomeTutorialCompleted(),
    );
    _tutorialCoachMark?.show(context: context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _motionTabBarController,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Reduced vertical padding
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: MotionTabBar(
          controller: _motionTabBarController,
          initialSelectedTab: "Home",
          labels: const ["Home", "Search", "Create", "Orders", "Inbox"],
          icons: const [
            Icons.home_outlined, Icons.search, Icons.add,
            Icons.receipt_long_outlined, Icons.chat_bubble_outline
          ],
          labelAlwaysVisible: true,
          tabIconColor: Colors.grey[600],
          tabIconSize: 24.0,
          tabIconSelectedSize: 24.0,
          tabSelectedColor: const Color(0xFF2C3E50),
          tabIconSelectedColor: Colors.white,
          tabBarColor: Colors.white, // Changed from transparent to white
          textStyle: TextStyle(
            fontSize: 11,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
            height: 1.0, // Reduced line height
          ),
          tabBarHeight: 55, // Reduced height
          onTabItemSelected: (int value) {
            setState(() {
              _motionTabBarController!.index = value;
            });
          },
          badges: [null, null, null, null, null],
        ),
      ),
    );
  }
}