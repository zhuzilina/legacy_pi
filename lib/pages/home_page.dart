import 'package:flutter/material.dart';
import 'culture_page.dart';
import 'journey_page.dart';
import 'knowledge_page.dart';
import 'trip_page/trip_page.dart';
import 'profile_drawer.dart';
import '../services/global_state.dart';
import '../services/unified_cache_service.dart';
import '../widgets/floating_action_buttons.dart';
import '../l10n/app_localizations.dart';
import '../main.dart'; // 导入包含 routeObserver 的文件

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  int _currentIndex = 1; // 默认显示学文化页面（中间）
  final UnifiedCacheService _cacheService = UnifiedCacheService();

  // ------------------- 修改第 1 步：将 pages 变为成员变量 -------------------
  // 将原来的 getter 修改为 final List<Widget>
  late final List<Widget> _pages;

  final List<String> _titles = ['新旅途', '学文化', '学知识', '旅游'];

  // 为文化页面创建 GlobalKey，以便调用其悬浮按钮方法
  final GlobalKey<CulturePageState> _culturePageKey = GlobalKey<CulturePageState>();

  
    
  // 悬浮按钮管理器
  FloatingActionButtonsManager? _floatingButtonsManager;

  // 控制悬浮按钮可见性的状态
  bool _isFabVisible = true;

  @override
  void initState() {
    super.initState();
    
    // 在 initState 中只创建一次页面实例
    _pages = [
      JourneyPage(
        onScoreUpdated: () {
          // 当抽屉页面更新积分后，通知journey页面检查更新
          print('HomePage: 收到积分更新通知，将通知journey页面');
        },
      ), // 新旅途页面 (左侧)
      CulturePage(
        key: _culturePageKey,
        onHideFloatingButtons: _hideFloatingButtons,
        onShowFloatingButtons: _updateFloatingButtons,
      ), // 学文化页面 (中间) - 绑定 GlobalKey
      const KnowledgePage(), // 学知识页面 (右侧)
      const TripPage(), // 旅游页面 (新增)
    ];

    // 恢复底部TabBar状态
    _restoreBottomTabState();
    
    // 延迟初始化悬浮按钮，确保在 build 完成后执行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFloatingButtons();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 订阅路由观察者
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    // 取消订阅路由观察者
    routeObserver.unsubscribe(this);
    // 销毁悬浮按钮管理器
    _floatingButtonsManager?.dispose();
    super.dispose();
  }
  
  /// 当有新的路由被 push 到当前路由之上时调用
  @override
  void didPushNext() {
    // 当我们离开HomePage去往新页面时，隐藏悬浮按钮
    setState(() {
      _isFabVisible = false;
    });
    _hideFloatingButtons();
  }

  /// 当顶部的路由被 pop，当前路由重新变为顶部时调用
  @override
  void didPopNext() {
    // 当我们从新页面返回HomePage时，显示悬浮按钮
    setState(() {
      _isFabVisible = true;
    });
    _updateFloatingButtons();
  }

  // 保存当前页面状态 - 这个方法现在可以移除了，因为IndexedStack会自动处理
  // void _saveCurrentPageState() {
  //   print('HomePage: 页面状态由IndexedStack自动管理');
  // }

  // 保存底部TabBar状态
  void _saveBottomTabState(int index) {
    _cacheService.pageStateCacheService.saveBottomTabState(index);
  }

  // 恢复底部TabBar状态
  Future<void> _restoreBottomTabState() async {
    try {
      final savedIndex = await _cacheService.pageStateCacheService.getBottomTabState();
      if (savedIndex != null && savedIndex >= 0 && savedIndex < _pages.length) {
        setState(() {
          _currentIndex = savedIndex;
        });
        print('底部TabBar状态已恢复: $savedIndex');
      }
    } catch (e) {
      print('恢复底部TabBar状态失败: $e');
    }
  }
  
  // 初始化悬浮按钮
  void _initializeFloatingButtons() {
    if (_floatingButtonsManager != null) return;
    
    // 只有在文化页面时才显示悬浮按钮
    if (_currentIndex == 1) {
      _showFloatingButtons();
    }
  }
  
  // 显示悬浮按钮
  void _showFloatingButtons() {
    if (_floatingButtonsManager != null) return;
    
    final l10n = AppLocalizations.of(context)!;
    final buttonConfigs = [
      FloatingButtonConfig(
        text: l10n.studyFullText,
        onTap: () {
          _hideFloatingButtons(); // 点击时隐藏悬浮按钮
          _culturePageKey.currentState?.handleStudyFullText();
        },
      ),
      FloatingButtonConfig(
        text: l10n.summarizeKeyPoints,
        onTap: () {
          _hideFloatingButtons(); // 点击时隐藏悬浮按钮
          _culturePageKey.currentState?.handleSummarizeKeyPoints();
        },
      ),
      FloatingButtonConfig(
        text: l10n.enterConversation,
        onTap: () {
          _hideFloatingButtons(); // 点击时隐藏悬浮按钮
          _culturePageKey.currentState?.handleEnterConversation();
        },
      ),
      FloatingButtonConfig(
        text: '朗读\n全文',
        onTap: () {
          _hideFloatingButtons(); // 点击时隐藏悬浮按钮
          _culturePageKey.currentState?.handleReadFullTextWithTTS();
        },
      ),
    ];
    
    _floatingButtonsManager = FloatingActionButtonsManager(
      context: context,
      buttonConfigs: buttonConfigs,
      bottomOffset: 187,
      rightOffset: 20,
    );
    
    _floatingButtonsManager!.show();
  }
  
  // 隐藏悬浮按钮
  void _hideFloatingButtons() {
    _floatingButtonsManager?.dispose();
    _floatingButtonsManager = null;
  }
  
  // 更新悬浮按钮状态
  void _updateFloatingButtons() {
    // 如果悬浮按钮不可见（有页面覆盖），直接隐藏
    if (!_isFabVisible) {
      _hideFloatingButtons();
      return;
    }

    if (_currentIndex == 1) {
      // 文化页面，显示悬浮按钮
      if (_floatingButtonsManager == null) {
        _showFloatingButtons();
      }
    } else {
      // 其他页面，隐藏悬浮按钮
      _hideFloatingButtons();
    }
  }

  // 检查JourneyPage状态的方法
  void _checkJourneyPageState() {
    if (_currentIndex == 0) {
      // 当前是Journey页面，触发其状态检查
      print('HomePage: 触发Journey页面状态检查');
      // 直接调用JourneyPage的方法
      (_pages[0] as JourneyPage).checkAndUpdateGlobalState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // ------------------- 修改第 2 步：使用 IndexedStack -------------------
      // 将原来的 _pages[_currentIndex] 替换为 IndexedStack
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // 不再需要手动调用 _saveCurrentPageState()
          // _saveCurrentPageState();

          setState(() {
            _currentIndex = index;
          });

          // 更新悬浮按钮状态
          _updateFloatingButtons();

          // 如果切换到Journey页面，触发状态检查
          if (index == 0) {
            print('HomePage: 切换到Journey页面，触发状态检查');
            _checkJourneyPageState();
          }

          // 保存底部TabBar状态
          _saveBottomTabState(index);
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
          BottomNavigationBarItem(icon: Icon(Icons.travel_explore), label: '旅游'),
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
