import 'dart:async';

import 'package:dolo/screens/Inbox%20Section/indoxscreen.dart';
import 'package:dolo/screens/ProfileSection/profilescreen.dart';
import 'package:dolo/screens/orderSection/CreateOrderPage.dart';
import 'package:dolo/screens/orderSection/YourOrders.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/send_page.dart';
import 'home.dart';

class HomePageWithNav extends StatefulWidget {
  const HomePageWithNav({super.key});

  @override
  State<HomePageWithNav> createState() => _HomePageWithNavState();
}

class _HomePageWithNavState extends State<HomePageWithNav> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Fixed pages list - same for all users, including search tab
  List<Widget> get _pages {
    return [
      const CreateOrderPage(),    // Create (index 0)
      const SendPage(),           // Search (index 1)
      const YourOrdersPage(),     // Your Orders (index 2)
      const InboxScreen(),        // Inbox (index 3)
      const ProfilePage(),        // Profile (index 4)
    ];
  }

  // Fixed navigation items - same for all users
  List<BottomNavigationBarItem> get _navItems {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.add_circle_outline),
        label: 'Create',
        activeIcon: Icon(Icons.add_circle, size: 28),
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.search),
        label: 'Search',
        activeIcon: Icon(Icons.search, size: 28),
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.bookmark_border),
        label: 'Your Orders',
        activeIcon: Icon(Icons.bookmark, size: 28),
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.chat_bubble_outline),
        label: 'Inbox',
        activeIcon: Icon(Icons.chat_bubble, size: 28),
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        label: 'Profile',
        activeIcon: Icon(Icons.person, size: 28),
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

  @override
  Widget build(BuildContext context) {
    // Ensure selected index is within bounds
    if (_selectedIndex >= _pages.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      extendBody: true,
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
            items: _navItems,
          ),
        ),
      ),
    );
  }
}
