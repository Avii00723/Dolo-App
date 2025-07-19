import 'package:dolo/screens/Inbox%20Section/indoxscreen.dart';
import 'package:dolo/screens/ProfileSection/profilescreen.dart';
import 'package:dolo/screens/orderSection/CreateOrderPage.dart';
import 'package:dolo/screens/orderSection/YourOrders.dart';
import 'package:flutter/material.dart';
import '../../screens/send_page.dart';
import 'home.dart'; // Make sure HomePageContent is defined in home.dart
class HomePageWithNav extends StatefulWidget {
  const HomePageWithNav({super.key});

  @override
  State<HomePageWithNav> createState() => _HomePageWithNavState();
}

class _HomePageWithNavState extends State<HomePageWithNav> {
  int _selectedIndex = 0;

  // List of pages for each tab
  final List<Widget> _pages = [
    const SendPage(),
    const CreateOrderPage(),
    const  YourOrdersPage(),// Add SendPage for the 'Send' tab
    const InboxScreen(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allow content to show behind the nav bar (for floating effect)
      body: _pages[_selectedIndex],

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              backgroundColor: Colors.white,
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              iconSize: 26,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
                BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Create'),
                BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Your Orders'),
                BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Inbox'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
