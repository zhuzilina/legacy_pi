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
  
  // 应用启动时清理文章数据缓存，确保获取最新数据
  final cacheService = UnifiedCacheService();
  cacheService.clearAllArticleCache();
  print('应用启动：已清理所有文章数据缓存，将重新获取最新数据');
  
  // 打印API配置信息
  ApiConfig.printConfig();

  runApp(const RedCultureApp());
}

class RedCultureApp extends StatelessWidget {
  const RedCultureApp({super.key});

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
