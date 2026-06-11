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
import '../../Controllers/ChatService.dart';
import '../../Controllers/SocketService.dart';
import '../../Controllers/tutorial_service.dart';
import '../../Controllers/UnreadCountService.dart';
import '../../widgets/tutorial_helper.dart';

class HomePageWithNav extends StatefulWidget {
  const HomePageWithNav({super.key});

  @override
  State<HomePageWithNav> createState() => _HomePageWithNavState();
}

class _HomePageWithNavState extends State<HomePageWithNav>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  MotionTabBarController? _motionTabBarController;
  late final VoidCallback _tabControllerListener;
  TutorialCoachMark? _tutorialCoachMark;
  final SocketService _socketService = SocketService();
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  // ✅ Cached pages list — built once in initState, never rebuilt.
  // Prevents ModernHomeScreen (and other tabs) from being destroyed and
  // recreated on every setState / tab switch, which was the root cause of
  // the "setState() called after dispose()" crash in _loadUserData.
  late final List<Widget> _pages;

  final GlobalKey _homeButtonKey = GlobalKey();
  final GlobalKey _searchButtonKey = GlobalKey();
  final GlobalKey _createButtonKey = GlobalKey();
  final GlobalKey _ordersButtonKey = GlobalKey();
  final GlobalKey _inboxButtonKey = GlobalKey();

  // ── Tab indices ──────────────────────────────────────────────────
  static const int _tabHome = 0;
  static const int _tabSearch = 1;
  static const int _tabCreate = 2;
  static const int _tabOrders = 3;
  static const int _tabInbox = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabControllerListener = () {
      if (!mounted) return;
      setState(() {});
    };

    _motionTabBarController = MotionTabBarController(
      initialIndex: _tabHome,
      length: 5,
      vsync: this,
    )..addListener(_tabControllerListener);

    // ✅ Build pages exactly once — tab-switch helpers are ready by this point.
    _pages = [
      // Tab 0 – Home
      ModernHomeScreen(
        onGoToCreate: switchToCreateTab,
        onGoToSearch: switchToSearchTab,
        onGoToOrders: switchToOrdersTab,
      ),

      // Tab 1 – Search
      const SendPage(),

      // Tab 2 – Create
      CreateOrderPage(onOrderCreated: switchToOrdersTab),

      // Tab 3 – Orders
      const YourOrdersPage(),

      // Tab 4 – Inbox
      const InboxScreen(),
    ];

    _checkAndShowTutorial();
    _initializeChatUnreadListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageSubscription?.cancel();
    _socketService.releaseConnection();
    _motionTabBarController?.removeListener(_tabControllerListener);
    _motionTabBarController?.dispose();
    super.dispose();
  }

  Future<void> _initializeChatUnreadListener() async {
    try {
      await _socketService.connect();
      if (!mounted || _socketService.socket == null) return;

      _messageSubscription = _socketService.onReceiveMessage((data) {
        _syncUnreadChatCount();
      });

      await _syncUnreadChatCount();
    } catch (e) {
      debugPrint('Error initializing home chat listener: $e');
    }
  }

  Future<void> _syncUnreadChatCount() async {
    try {
      final result = await ChatService.getInbox();
      if (!mounted || result['success'] != true) return;

      final inbox = result['inbox'] as List<dynamic>;
      final totalUnread = inbox.fold<int>(
        0,
        (sum, chat) {
          if (chat is! Map) return sum;
          final unread = chat['unread_count'];
          if (unread is int) return sum + unread;
          return sum + (int.tryParse(unread?.toString() ?? '') ?? 0);
        },
      );
      UnreadCountService.setCount(totalUnread);
    } catch (e) {
      debugPrint('Error syncing unread chat count: $e');
    }
  }

  // ── Public tab-switch helpers ────────────────────────────────────
  void switchToOrdersTab() => _switchTab(_tabOrders);
  void switchToCreateTab() => _switchTab(_tabCreate);
  void switchToSearchTab() => _switchTab(_tabSearch);

  void _swapSearchCreateTab() {
    final currentIndex = _motionTabBarController?.index;
    if (currentIndex == _tabSearch) {
      _switchTab(_tabCreate);
    } else if (currentIndex == _tabCreate) {
      _switchTab(_tabSearch);
    }
  }

  void _switchTab(int index) {
    if (_motionTabBarController == null) return;
    setState(() => _motionTabBarController!.index = index);
  }

  // ── Tutorial ─────────────────────────────────────────────────────
  Future<void> _checkAndShowTutorial() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final isCompleted = await TutorialService.isHomeTutorialCompleted();
    if (!mounted) return;
    if (!isCompleted) {
      _showTutorial();
    }
  }

  void _showTutorial() {
    final targets = [
      TutorialHelper.createTarget(
          key: _homeButtonKey,
          title: 'Home',
          description: 'Your main dashboard...',
          order: 1,
          align: ContentAlign.top),
      TutorialHelper.createTarget(
          key: _searchButtonKey,
          title: 'Search Trips',
          description: 'Find available...',
          order: 2,
          align: ContentAlign.top),
      TutorialHelper.createTarget(
          key: _createButtonKey,
          title: 'Create Order',
          description: 'Create a new...',
          order: 3,
          align: ContentAlign.top),
      TutorialHelper.createTarget(
          key: _ordersButtonKey,
          title: 'Your Orders',
          description: 'View and manage...',
          order: 4,
          align: ContentAlign.top),
      TutorialHelper.createFinalTarget(
        key: _inboxButtonKey,
        title: 'Inbox & Chat',
        description: 'Communicate...',
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
      onFinish: () => TutorialService.markHomeTutorialCompleted(),
    );

    _tutorialCoachMark?.show(context: context);
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: TabBarView(
        controller: _motionTabBarController,
        children: _pages, // ✅ cached field — never rebuilt
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // ✅ ValueListenableBuilder rebuilds only the tab bar when the
          // unread count changes — the rest of the Scaffold is untouched.
          child: ValueListenableBuilder<int>(
            valueListenable: UnreadCountService.unreadCount,
            builder: (context, unreadCount, _) {
              return MotionTabBar(
                controller: _motionTabBarController,
                initialSelectedTab: "Home",
                labels: const ["Home", "Search", "Create", "Orders", "Inbox"],
                icons: const [
                  Icons.home_outlined,
                  Icons.search,
                  Icons.add,
                  Icons.receipt_long_outlined,
                  Icons.chat_bubble_outline,
                ],
                labelAlwaysVisible: true,
                tabIconColor: Colors.grey,
                tabIconSize: 24.0,
                tabIconSelectedSize: 24.0,
                tabSelectedColor: Theme.of(context).primaryColor,
                tabIconSelectedColor: Colors.white,
                tabBarColor: Theme.of(context).cardColor,
                textStyle: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                tabBarHeight: 55,
                onTabItemSelected: (int value) {
                  setState(() {
                    _motionTabBarController!.index = value;
                  });
                  // ✅ Clear the badge the moment the user taps Inbox.
                  // InboxScreen._loadInbox() will re-sync from the API
                  // and call UnreadCountService.setCount() with real data.
                  if (value == _tabInbox) {
                    UnreadCountService.reset();
                  } else {
                    _syncUnreadChatCount();
                  }
                },
                // ✅ Show red badge on Inbox tab only when there are unread
                // messages. All other tabs always get null (no badge).
                badges: [
                  null,
                  null,
                  null,
                  null,
                  unreadCount > 0 ? Text('$unreadCount') : null,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
