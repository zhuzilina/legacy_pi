import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 页面状态缓存服务，提供页面状态的持久化存储
class PageStateCacheService {
  static final PageStateCacheService _instance = PageStateCacheService._internal();
  factory PageStateCacheService() => _instance;
  PageStateCacheService._internal();

  // 缓存键前缀
  static const String _culturePageKey = 'culture_page_state';
  static const String _bottomTabKey = 'bottom_tab_index';
  static const String _pageTabKey = 'page_tab_index';
  static const String _currentPageKey = 'current_page_index';
  static const String _categoryPagePositionsKey = 'category_page_positions';

  /// 保存文化页面状态
  Future<void> saveCulturePageState({
    required int bottomTabIndex,
    required int pageTabIndex,
    required int currentPageIndex,
    required String currentCategory,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final stateData = {
        'bottomTabIndex': bottomTabIndex,
        'pageTabIndex': pageTabIndex,
        'currentPageIndex': currentPageIndex,
        'currentCategory': currentCategory,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString(_culturePageKey, jsonEncode(stateData));
      print('文化页面状态已保存: 底部Tab=$bottomTabIndex, 页面Tab=$pageTabIndex, 当前页=$currentPageIndex, 分类=$currentCategory');
    } catch (e) {
      print('保存文化页面状态失败: $e');
    }
  }

  /// 保存分类页面位置映射
  Future<void> saveCategoryPagePositions(Map<String, int> categoryPagePositions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_categoryPagePositionsKey, jsonEncode(categoryPagePositions));
      print('分类页面位置映射已保存: $categoryPagePositions');
    } catch (e) {
      print('保存分类页面位置映射失败: $e');
    }
  }

  /// 获取分类页面位置映射
  Future<Map<String, int>> getCategoryPagePositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final positionsString = prefs.getString(_categoryPagePositionsKey);
      
      if (positionsString != null) {
        final positionsData = jsonDecode(positionsString) as Map<String, dynamic>;
        final result = <String, int>{};
        positionsData.forEach((key, value) {
          result[key] = value as int;
        });
        print('获取分类页面位置映射: $result');
        return result;
      }
    } catch (e) {
      print('获取分类页面位置映射失败: $e');
    }
    
    return {};
  }

  /// 获取文化页面状态
  Future<Map<String, dynamic>?> getCulturePageState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateString = prefs.getString(_culturePageKey);
      
      if (stateString != null) {
        final stateData = jsonDecode(stateString) as Map<String, dynamic>;
        print('获取文化页面状态: $stateData');
        return stateData;
      }
    } catch (e) {
      print('获取文化页面状态失败: $e');
    }
    
    return null;
  }

  /// 保存底部TabBar状态
  Future<void> saveBottomTabState(int tabIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bottomTabKey, tabIndex);
      print('底部TabBar状态已保存: $tabIndex');
    } catch (e) {
      print('保存底部TabBar状态失败: $e');
    }
  }

  /// 获取底部TabBar状态
  Future<int?> getBottomTabState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabIndex = prefs.getInt(_bottomTabKey);
      if (tabIndex != null) {
        print('获取底部TabBar状态: $tabIndex');
      }
      return tabIndex;
    } catch (e) {
      print('获取底部TabBar状态失败: $e');
      return null;
    }
  }

  /// 保存页面内TabBar状态
  Future<void> savePageTabState(int tabIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_pageTabKey, tabIndex);
      print('页面TabBar状态已保存: $tabIndex');
    } catch (e) {
      print('保存页面TabBar状态失败: $e');
    }
  }

  /// 获取页面内TabBar状态
  Future<int?> getPageTabState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabIndex = prefs.getInt(_pageTabKey);
      if (tabIndex != null) {
        print('获取页面TabBar状态: $tabIndex');
      }
      return tabIndex;
    } catch (e) {
      print('获取页面TabBar状态失败: $e');
      return null;
    }
  }

  /// 保存当前页面索引
  Future<void> saveCurrentPageIndex(int pageIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_currentPageKey, pageIndex);
      print('当前页面索引已保存: $pageIndex');
    } catch (e) {
      print('保存当前页面索引失败: $e');
    }
  }

  /// 获取当前页面索引
  Future<int?> getCurrentPageIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pageIndex = prefs.getInt(_currentPageKey);
      if (pageIndex != null) {
        print('获取当前页面索引: $pageIndex');
      }
      return pageIndex;
    } catch (e) {
      print('获取当前页面索引失败: $e');
      return null;
    }
  }

  /// 保存分类数据状态
  Future<void> saveCategoryDataState(String category, List<String> articleIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'category_data_$category';
      await prefs.setStringList(key, articleIds);
      print('分类数据状态已保存: $category, 文章数量=${articleIds.length}');
    } catch (e) {
      print('保存分类数据状态失败: $e');
    }
  }

  /// 获取分类数据状态
  Future<List<String>?> getCategoryDataState(String category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'category_data_$category';
      final articleIds = prefs.getStringList(key);
      if (articleIds != null) {
        print('获取分类数据状态: $category, 文章数量=${articleIds.length}');
      }
      return articleIds;
    } catch (e) {
      print('获取分类数据状态失败: $e');
      return null;
    }
  }

  /// 清除所有页面状态缓存
  Future<void> clearAllPageState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_culturePageKey);
      await prefs.remove(_bottomTabKey);
      await prefs.remove(_pageTabKey);
      await prefs.remove(_currentPageKey);
      await prefs.remove(_categoryPagePositionsKey);
      
      // 清除所有分类数据状态
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('category_data_')) {
          await prefs.remove(key);
        }
      }
      
      print('所有页面状态缓存已清除');
    } catch (e) {
      print('清除页面状态缓存失败: $e');
    }
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int categoryDataCount = 0;
      for (final key in keys) {
        if (key.startsWith('category_data_')) {
          categoryDataCount++;
        }
      }
      
      return {
        'hasCulturePageState': prefs.containsKey(_culturePageKey),
        'hasBottomTabState': prefs.containsKey(_bottomTabKey),
        'hasPageTabState': prefs.containsKey(_pageTabKey),
        'hasCurrentPageState': prefs.containsKey(_currentPageKey),
        'categoryDataCount': categoryDataCount,
        'totalKeys': keys.length,
      };
    } catch (e) {
      print('获取页面状态缓存统计失败: $e');
      return {
        'error': e.toString(),
      };
    }
  }
}
