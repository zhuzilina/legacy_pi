import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class NewsApiService {
  // 使用统一的API配置
  static String get baseUrl => ApiConfig.crawlerBaseUrl;
  
  // 单例模式
  static final NewsApiService _instance = NewsApiService._internal();
  factory NewsApiService() => _instance;
  NewsApiService._internal();

  // 获取每日文章列表
  Future<ArticleListResponse?> getDailyArticles() async {
    try {
      print('正在获取每日文章列表...');
      final response = await http.get(
        Uri.parse('$baseUrl/daily/'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('API响应状态码: ${response.statusCode}');
      print('API响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ArticleListResponse.fromJson(jsonData);
      } else {
        print('获取文章列表失败: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('获取文章列表时发生错误: $e');
      return null;
    }
  }

  // 获取文章内容
  Future<Article?> getArticleContent(String articleId) async {
    try {
      print('正在获取文章内容: $articleId');
      final response = await http.get(
        Uri.parse('$baseUrl/article/$articleId/'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('文章API响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final markdown = response.body;
        print('文章内容长度: ${markdown.length}');
        return Article.fromMarkdown(articleId, markdown);
      } else {
        print('获取文章内容失败: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('获取文章内容时发生错误: $e');
      return null;
    }
  }

  // 批量获取文章内容（并发，默认获取全部）
  Future<List<Article>> getMultipleArticles(
    List<String> articleIds, {
    int? maxCount, // 为空表示获取全部
    int concurrency = 6, // 并发数限制，避免同时发起过多请求
  }) async {
    final targetIds = (maxCount != null && maxCount > 0)
        ? articleIds.take(maxCount).toList()
        : List<String>.from(articleIds);

    print('正在批量获取 ${targetIds.length} 篇文章（并发=$concurrency）...');

    final articles = <Article>[];
    int index = 0;

    Future<void> worker() async {
      while (true) {
        final currentIndex = index;
        if (currentIndex >= targetIds.length) break;
        index = currentIndex + 1;

        final id = targetIds[currentIndex];
        final article = await getArticleContent(id);
        if (article != null) {
          articles.add(article);
          print('成功获取文章: ${article.title}');
        } else {
          print('获取文章失败: $id');
        }
      }
    }

    // 启动并发工作协程
    final workers = List.generate(concurrency, (_) => worker());
    await Future.wait(workers);

    print('批量获取完成，共获得 ${articles.length} 篇文章');
    return articles;
  }

  // 获取爬取状态
  Future<Map<String, dynamic>?> getCrawlStatus() async {
    try {
      print('正在获取爬取状态...');
      final response = await http.get(
        Uri.parse('$baseUrl/status/'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('获取爬取状态失败: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('获取爬取状态时发生错误: $e');
      return null;
    }
  }

  // 获取图片URL
  String getImageUrl(String imageId) {
    return '$baseUrl/image/$imageId/';
  }
}

