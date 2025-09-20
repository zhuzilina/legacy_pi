import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../config/api_config.dart';

/// MD文档API服务类
class MdDocsApiService {
  static String? _baseUrl;
  
  /// 初始化baseUrl
  static Future<void> _initializeBaseUrl() async {
    if (_baseUrl == null) {
      _baseUrl = await ApiConfig.mdDocsBaseUrl;
    }
  }
  
  /// 获取文档ID列表
  Future<MdDocsListResponse?> getDocumentIdsByCategory({
    String? category,
  }) async {
    try {
      await _initializeBaseUrl();
      String url = '$_baseUrl/category/';
      final queryParams = <String, String>{};
      
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = _mapCategoryToApi(category);
      }
      
      if (queryParams.isNotEmpty) {
        url += '?${Uri(queryParameters: queryParams).query}';
      }
      
      print('请求MD文档ID列表: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));
      
      print('MD文档ID列表响应状态: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MdDocsListResponse.fromJson(data);
      } else {
        print('获取MD文档ID列表失败: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('获取MD文档ID列表异常: $e');
      return null;
    }
  }
  
  /// 获取文档内容
  Future<String?> getDocumentContent(String documentId) async {
    try {
      await _initializeBaseUrl();
      final url = '$_baseUrl/document/$documentId/';
      print('请求MD文档内容: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'text/plain',
        },
      ).timeout(const Duration(seconds: 30));
      
      print('MD文档内容响应状态: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return response.body;
      } else {
        print('获取MD文档内容失败: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('获取MD文档内容异常: $e');
      return null;
    }
  }
  
  /// 获取系统状态
  Future<MdDocsStatusResponse?> getSystemStatus() async {
    try {
      await _initializeBaseUrl();
      final url = '$_baseUrl/status/';
      print('请求MD文档系统状态: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      print('MD文档系统状态响应: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MdDocsStatusResponse.fromJson(data);
      } else {
        print('获取MD文档系统状态失败: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('获取MD文档系统状态异常: $e');
      return null;
    }
  }
  
  /// 将中文分类名映射为API分类代码
  String _mapCategoryToApi(String category) {
    switch (category) {
      case '精神':
        return 'spirit';
      case '人物':
        return 'person';
      case '党史':
        return 'party_history';
      case '景点':
        return 'scenic';
      default:
        return category;
    }
  }
  
  
  /// 将MD文档ID和内容转换为Article对象
  Article convertToArticle(String documentId, String markdownContent) {
    // 使用Article的fromMarkdown方法解析内容
    return Article.fromMarkdown(documentId, markdownContent);
  }
  
  /// 批量获取文档内容（并发）
  Future<List<Article>> getMultipleDocuments(
    List<String> documentIds, {
    int? maxCount,
    int concurrency = 6,
  }) async {
    final targetIds = (maxCount != null && maxCount > 0)
        ? documentIds.take(maxCount).toList()
        : List<String>.from(documentIds);

    print('正在批量获取 ${targetIds.length} 个文档（并发=$concurrency）...');

    final articles = <Article>[];
    int index = 0;

    Future<void> worker() async {
      while (true) {
        final currentIndex = index;
        if (currentIndex >= targetIds.length) break;
        index = currentIndex + 1;

        final id = targetIds[currentIndex];
        final content = await getDocumentContent(id);
        if (content != null) {
          final article = convertToArticle(id, content);
          articles.add(article);
          print('成功获取文档: ${article.title}');
        } else {
          print('获取文档失败: $id');
        }
      }
    }

    // 启动并发工作协程
    final workers = List.generate(concurrency, (_) => worker());
    await Future.wait(workers);

    print('批量获取完成，共获得 ${articles.length} 个文档');
    return articles;
  }

  /// 转换MD文档的图片URL为完整URL
  String convertImageUrl(String imageUrl) {
    // 如果已经是完整URL，直接返回
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }

    // 如果是MD文档的图片路径格式，转换为完整URL
    if (imageUrl.startsWith('/api/md-docs/image/')) {
      return '$_baseUrl$imageUrl';
    }

    return imageUrl;
  }
  
}

/// MD文档列表响应模型
class MdDocsListResponse {
  final String msg;
  final String crawlDate;
  final int totalArticles;
  final List<String> articleIds;
  final String status;
  final String? error;

  MdDocsListResponse({
    required this.msg,
    required this.crawlDate,
    required this.totalArticles,
    required this.articleIds,
    required this.status,
    this.error,
  });

  factory MdDocsListResponse.fromJson(Map<String, dynamic> json) {
    return MdDocsListResponse(
      msg: json['msg'] ?? '',
      crawlDate: json['crawl_date'] ?? '',
      totalArticles: json['total_articles'] ?? 0,
      articleIds: List<String>.from(json['article_ids'] ?? []),
      status: json['status'] ?? '',
      error: json['error'],
    );
  }
}


/// MD文档系统状态响应模型
class MdDocsStatusResponse {
  final String msg;
  final int totalDocuments;
  final Map<String, int> categoryStats;
  final String recentUpdate;
  final String systemStatus;

  MdDocsStatusResponse({
    required this.msg,
    required this.totalDocuments,
    required this.categoryStats,
    required this.recentUpdate,
    required this.systemStatus,
  });

  factory MdDocsStatusResponse.fromJson(Map<String, dynamic> json) {
    return MdDocsStatusResponse(
      msg: json['msg'] ?? '',
      totalDocuments: json['total_documents'] ?? 0,
      categoryStats: Map<String, int>.from(json['category_stats'] ?? {}),
      recentUpdate: json['recent_update'] ?? '',
      systemStatus: json['system_status'] ?? '',
    );
  }
}
