import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/unified_cache_service.dart';
import 'full_content_dialog.dart';

/// FullContentDialog 使用示例
///
/// 这个文件展示了如何使用 FullContentDialog 组件
class FullContentDialogExample extends StatelessWidget {
  const FullContentDialogExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FullContentDialog 示例'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FullContentDialog 使用示例',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // 基本使用示例
            ElevatedButton(
              onPressed: () {
                final article = Article(
                  id: '1',
                  title: '示例文章标题',
                  content: '这是文章内容示例...',
                  source: '示例来源',
                  publishTime: '2024-01-01',
                  category: '新闻',
                  wordCount: 100,
                  originalUrl: 'https://example.com/article1',
                  metaInfo: '示例文章的元信息',
                  collectTime: '2024-01-01',
                );

                FullContentDialog.show(
                  context: context,
                  article: article,
                  cacheService: UnifiedCacheService(),
                );
              },
              child: const Text('显示基本全文对话框'),
            ),

            const SizedBox(height: 10),

            // 自定义样式示例
            ElevatedButton(
              onPressed: () {
                final article = Article(
                  id: '2',
                  title: '自定义样式示例',
                  content: '这是自定义样式的文章内容...',
                  source: '自定义来源',
                  publishTime: '2024-01-01',
                  category: '精神',
                  wordCount: 200,
                  originalUrl: 'https://example.com/article2',
                  metaInfo: '自定义文章的元信息',
                  collectTime: '2024-01-01',
                );

                FullContentDialog.show(
                  context: context,
                  article: article,
                  cacheService: UnifiedCacheService(),
                  backgroundColor: Colors.blue.shade50,
                  textColor: Colors.blue.shade900,
                  barrierColor: Colors.blue.shade200.withValues(alpha: 0.5),
                  dialogWidth: 400,
                  dialogHeight: 600,
                  borderRadius: 20,
                );
              },
              child: const Text('显示自定义样式对话框'),
            ),

            const SizedBox(height: 10),

            // 使用配置类示例
            ElevatedButton(
              onPressed: () {
                final article = Article(
                  id: '3',
                  title: '移动端优化示例',
                  content: '这是移动端优化的文章内容...',
                  source: '移动端来源',
                  publishTime: '2024-01-01',
                  category: '人物',
                  wordCount: 300,
                  originalUrl: 'https://example.com/article3',
                  metaInfo: '移动端文章的元信息',
                  collectTime: '2024-01-01',
                );

                FullContentDialogHelper.showMobileOptimized(
                  context: context,
                  article: article,
                  cacheService: UnifiedCacheService(),
                );
              },
              child: const Text('显示移动端优化对话框'),
            ),

            const SizedBox(height: 10),

            // 使用自定义配置示例
            ElevatedButton(
              onPressed: () {
                final article = Article(
                  id: '4',
                  title: '平板端优化示例',
                  content: '这是平板端优化的文章内容...',
                  source: '平板端来源',
                  publishTime: '2024-01-01',
                  category: '党史',
                  wordCount: 400,
                  originalUrl: 'https://example.com/article4',
                  metaInfo: '平板端文章的元信息',
                  collectTime: '2024-01-01',
                );

                FullContentDialogHelper.showWithDefaultConfig(
                  context: context,
                  article: article,
                  cacheService: UnifiedCacheService(),
                  config: FullContentDialogConfig.tabletConfig(),
                );
              },
              child: const Text('显示平板端优化对话框'),
            ),

            const SizedBox(height: 30),

            const Text(
              '使用方法：',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              '1. 基本使用：\n'
              '   ```dart\n'
              '   FullContentDialog.show(\n'
              '     context: context,\n'
              '     article: article,\n'
              '     cacheService: cacheService,\n'
              '   );\n'
              '   ```\n\n'
              '2. 自定义样式：\n'
              '   ```dart\n'
              '   FullContentDialog.show(\n'
              '     context: context,\n'
              '     article: article,\n'
              '     cacheService: cacheService,\n'
              '     backgroundColor: Colors.blue.shade50,\n'
              '     textColor: Colors.blue.shade900,\n'
              '     dialogWidth: 400,\n'
              '     dialogHeight: 600,\n'
              '   );\n'
              '   ```\n\n'
              '3. 使用帮助类：\n'
              '   ```dart\n'
              '   FullContentDialogHelper.showMobileOptimized(\n'
              '     context: context,\n'
              '     article: article,\n'
              '     cacheService: cacheService,\n'
              '   );\n'
              '   ```\n\n'
              '4. 使用配置类：\n'
              '   ```dart\n'
              '   FullContentDialogHelper.showWithDefaultConfig(\n'
              '     context: context,\n'
              '     article: article,\n'
              '     cacheService: cacheService,\n'
              '     config: FullContentDialogConfig.tabletConfig(),\n'
              '   );\n'
              '   ```\n\n'
              '5. 控制TTS功能：\n'
              '   ```dart\n'
              '   // 启用TTS（默认）\n'
              '   FullContentDialog.show(\n'
              '     context: context,\n'
              '     article: article,\n'
              '     cacheService: cacheService,\n'
              '     enableTts: true,\n'
              '   );\n'
              '   \n'
              '   // 禁用TTS\n'
              '   FullContentDialog.show(\n'
              '     context: context,\n'
              '     article: article,\n'
              '     cacheService: cacheService,\n'
              '     enableTts: false,\n'
              '   );\n'
              '   ```',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 预设配置示例
class FullContentDialogPresets {
  /// 获取深色主题配置
  static FullContentDialogConfig get darkTheme {
    return FullContentDialogConfig(
      backgroundColor: Colors.grey.shade900,
      textColor: Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      borderRadius: 8,
      enableTts: true,
    );
  }

  /// 获取浅色主题配置
  static FullContentDialogConfig get lightTheme {
    return FullContentDialogConfig(
      backgroundColor: Colors.white,
      textColor: Colors.black87,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      borderRadius: 16,
      enableTts: true,
    );
  }

  /// 获取蓝色主题配置
  static FullContentDialogConfig get blueTheme {
    return FullContentDialogConfig(
      backgroundColor: Colors.blue.shade50,
      textColor: Colors.blue.shade900,
      barrierColor: Colors.blue.shade200.withValues(alpha: 0.5),
      borderRadius: 20,
      enableTts: true,
    );
  }

  /// 获取绿色主题配置
  static FullContentDialogConfig get greenTheme {
    return FullContentDialogConfig(
      backgroundColor: Colors.green.shade50,
      textColor: Colors.green.shade900,
      barrierColor: Colors.green.shade200.withValues(alpha: 0.5),
      borderRadius: 20,
      enableTts: true,
    );
  }

  /// 获取无TTS配置（用于纯阅读场景）
  static FullContentDialogConfig get noTts {
    return FullContentDialogConfig(
      backgroundColor: Colors.white,
      textColor: Colors.black87,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      borderRadius: 16,
      enableTts: false,
    );
  }

  /// 获取TTS优先配置（音频播放优化）
  static FullContentDialogConfig get ttsOptimized {
    return FullContentDialogConfig(
      backgroundColor: Colors.white,
      textColor: Colors.black87,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      borderRadius: 16,
      enableTts: true,
      dialogHeight: 500, // 为TTS播放器留出更多空间
    );
  }
}