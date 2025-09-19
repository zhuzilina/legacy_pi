import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class StrategyCard extends StatelessWidget {
  final Map<String, dynamic> strategy;

  const StrategyCard({super.key, required this.strategy});

  // 处理URL跳转
  Future<void> _launchURL(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('无法打开链接: $url'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打开链接时发生错误: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (strategy['url'] != null && strategy['url'].toString().isNotEmpty) {
          _launchURL(context, strategy['url'].toString());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('该攻略暂无相关链接'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.zero,
        child: Stack(
          children: [
            // 攻略图片 - 完全填充
            Image.network(
              strategy['image'].toString(),
              height: double.infinity,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 32,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            ),
            // 黑色渐变遮罩
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // 文字信息覆盖层
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题 - 左对齐
                    Text(
                      strategy['title'].toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 8),
                    // 描述信息 - 三行，左对齐
                    Text(
                      strategy['description'].toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: Colors.white70,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
