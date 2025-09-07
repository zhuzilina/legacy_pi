import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 图片缓存服务，提供图片的本地缓存功能
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  // 自定义缓存管理器，设置更大的缓存空间和更长的缓存时间
  static final CacheManager _cacheManager = CacheManager(
    Config(
      'image_cache',
      stalePeriod: const Duration(days: 30), // 缓存30天
      maxNrOfCacheObjects: 200, // 最多缓存200张图片
      repo: JsonCacheInfoRepository(databaseName: 'image_cache'),
      fileService: HttpFileService(),
    ),
  );

  /// 获取缓存的图片文件
  /// 如果图片已缓存，直接返回缓存文件
  /// 如果未缓存，会先下载并缓存，然后返回文件
  Future<FileInfo?> getCachedImage(String imageUrl) async {
    try {
      return await _cacheManager.getFileFromCache(imageUrl);
    } catch (e) {
      print('获取缓存图片失败: $imageUrl, 错误: $e');
      return null;
    }
  }

  /// 下载并缓存图片
  Future<FileInfo?> downloadAndCacheImage(String imageUrl) async {
    try {
      return await _cacheManager.downloadFile(imageUrl);
    } catch (e) {
      print('下载并缓存图片失败: $imageUrl, 错误: $e');
      return null;
    }
  }

  /// 预加载图片到缓存
  /// 在后台下载图片，不阻塞UI
  Future<void> preloadImage(String imageUrl) async {
    try {
      // 检查是否已缓存
      final cachedFile = await getCachedImage(imageUrl);
      if (cachedFile == null) {
        // 如果未缓存，则下载
        await downloadAndCacheImage(imageUrl);
      }
    } catch (e) {
      print('预加载图片失败: $imageUrl, 错误: $e');
    }
  }

  /// 批量预加载图片
  Future<void> preloadImages(List<String> imageUrls) async {
    final futures = imageUrls.map((url) => preloadImage(url));
    await Future.wait(futures);
  }

  /// 检查图片是否已缓存
  Future<bool> isImageCached(String imageUrl) async {
    try {
      final cachedFile = await getCachedImage(imageUrl);
      return cachedFile != null;
    } catch (e) {
      return false;
    }
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      // 使用默认的缓存目录
      final cacheDir = Directory.systemTemp;
      final imageCacheDir = Directory('${cacheDir.path}/image_cache');
      
      if (!imageCacheDir.existsSync()) {
        return {
          'cacheSize': 0,
          'cacheCount': 0,
          'cacheDirectory': imageCacheDir.path,
          'cacheSizeMB': '0.00',
        };
      }

      final files = imageCacheDir.listSync();
      int totalSize = 0;
      int imageCount = 0;

      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
          imageCount++;
        }
      }

      return {
        'cacheSize': totalSize,
        'cacheCount': imageCount,
        'cacheDirectory': imageCacheDir.path,
        'cacheSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      print('获取缓存统计信息失败: $e');
      return {
        'cacheSize': 0,
        'cacheCount': 0,
        'cacheDirectory': null,
        'cacheSizeMB': '0.00',
        'error': e.toString(),
      };
    }
  }

  /// 清除所有图片缓存
  Future<void> clearAllCache() async {
    try {
      await _cacheManager.emptyCache();
      print('图片缓存已清空');
    } catch (e) {
      print('清空图片缓存失败: $e');
    }
  }

  /// 清除特定图片的缓存
  Future<void> removeImageFromCache(String imageUrl) async {
    try {
      await _cacheManager.removeFile(imageUrl);
      print('已移除图片缓存: $imageUrl');
    } catch (e) {
      print('移除图片缓存失败: $imageUrl, 错误: $e');
    }
  }

  /// 获取缓存管理器实例（用于CachedNetworkImage）
  CacheManager get cacheManager => _cacheManager;
}
