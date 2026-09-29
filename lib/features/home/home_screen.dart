import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../place/place_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // 分享連結（網頁版）：?place=<place_id> 直接開店家頁
    final placeId = Uri.base.queryParameters['place'];
    if (placeId != null && placeId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(CupertinoPageRoute(
          builder: (_) => PlaceDetailScreen(placeId: placeId),
        ));
      });
    }
  }

  static const _pages = [
    SearchScreen(),
    MapScreen(),
    NearbyScreen(),
    ProfileScreen()
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
      // iOS 風格分頁列：無陰影、上緣細線、選取用系統藍
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        // 半透明時 CupertinoTabBar 會自動加毛玻璃
        backgroundColor: (theme.cardTheme.color ?? theme.colorScheme.surface)
            .withValues(alpha: 0.75),
        activeColor: theme.colorScheme.primary,
        inactiveColor: theme.colorScheme.onSurfaceVariant,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.search), label: '搜尋'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.map), label: '地圖'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.location), label: '附近'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person), label: '我的'),
        ],
      ),
    );
  }
}
