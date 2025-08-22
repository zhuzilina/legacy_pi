import 'package:flutter/material.dart';
import 'culture_page.dart';
import 'journey_page.dart';
import 'knowledge_page.dart';
import 'profile_drawer.dart';
import '../services/global_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 1; // 默认显示学文化页面（中间）

  final List<Widget> _pages = [
    JourneyPage(
      onScoreUpdated: () {
        // 当抽屉页面更新积分后，通知journey页面检查更新
        print('HomePage: 收到积分更新通知，将通知journey页面');
      },
    ), // 新旅途页面 (左侧)
    const CulturePage(), // 学文化页面 (中间)
    const KnowledgePage(), // 学知识页面 (右侧)
  ];

  final List<String> _titles = ['新旅途', '学文化', '学知识'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.red[700],
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '新旅途'),
          BottomNavigationBarItem(icon: Icon(Icons.flag), label: '学文化'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: '学知识'),
        ],
      ),
      drawer: ProfileDrawer(
        onScoreUpdated: () {
          // 这个回调现在不会被立即调用，只是保留接口
        },
        onDrawerClosed: () {
          // 当抽屉关闭时，通知journey页面检查更新
          print('HomePage: 收到抽屉关闭回调');
          if (_currentIndex == 0) {
            // 如果当前是journey页面
            print('HomePage: 抽屉已关闭，通知journey页面检查更新');
            GlobalState().notifyCheckDatabaseUpdate();
          } else {
            print('HomePage: 当前不是journey页面，不通知更新');
          }
        },
      ),
    );
  }
}
