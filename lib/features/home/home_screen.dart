import 'package:flutter/material.dart';

import '../map/map_screen.dart';
import '../nearby/nearby_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _pages = [SearchScreen(), MapScreen(), NearbyScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search), label: '搜尋'),
            NavigationDestination(icon: Icon(Icons.map_outlined), label: '地圖'),
            NavigationDestination(icon: Icon(Icons.near_me), label: '附近'),
            NavigationDestination(icon: Icon(Icons.person), label: '我的'),
          ],
        ),
      );
}
