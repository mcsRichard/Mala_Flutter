import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'practice/practice_list_screen.dart';
import 'stats/stats_screen.dart';
import 'group/group_screen.dart';
import 'profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    PracticeListScreen(),
    GroupScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '今日'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: '功课'),
          NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: '小组'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: '统计'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的'),
        ],
      ),
    );
  }
}
