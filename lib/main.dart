import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'pages/home_page.dart';
import 'services/global_state.dart';
import 'services/unified_cache_service.dart';
import 'config/api_config.dart';

// 创建一个全局可访问的 RouteObserver
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化全局状态
  await GlobalState().initialize();

  // 应用启动时清理所有缓存，确保从头初始化
  final cacheService = UnifiedCacheService();
  await cacheService.clearAllCache();
  debugPrint('应用启动：已清理所有缓存，将从头初始化');

  // 打印API配置信息
  ApiConfig.printConfig();

  runApp(const RedCultureApp());
}

class RedCultureApp extends StatefulWidget {
  const RedCultureApp({super.key});

  @override
  State<RedCultureApp> createState() => _RedCultureAppState();
}

class _RedCultureAppState extends State<RedCultureApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 注册应用生命周期观察者
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // 移除应用生命周期观察者
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.detached:
        // 应用被系统关闭（内存被清除）
        debugPrint('应用生命周期：应用被系统关闭，清理所有缓存');
        _cleanupAppData();
        break;
      case AppLifecycleState.paused:
        // 应用进入后台
        debugPrint('应用生命周期：应用进入后台');
        break;
      case AppLifecycleState.resumed:
        // 应用恢复到前台
        debugPrint('应用生命周期：应用恢复到前台');
        break;
      case AppLifecycleState.inactive:
        // 应用处于非活动状态
        debugPrint('应用生命周期：应用处于非活动状态');
        break;
      case AppLifecycleState.hidden:
        // 应用被隐藏（iOS多任务界面）
        debugPrint('应用生命周期：应用被隐藏');
        break;
    }
  }

  // 清理应用数据
  Future<void> _cleanupAppData() async {
    try {
      final cacheService = UnifiedCacheService();
      await cacheService.clearAllCache();
      debugPrint('应用数据清理完成');
    } catch (e) {
      debugPrint('清理应用数据时出错: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '红色文化学习',
      debugShowCheckedModeBanner: false,

      // 添加路由观察者
      navigatorObservers: [routeObserver],

      // 本地化支持
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh'), // 中文
        Locale('en'), // 英文
      ],
      locale: const Locale('zh'), // 默认使用中文

      theme: ThemeData(
        primarySwatch: Colors.red,
        primaryColor: Colors.red[700],
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red[700]!,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
