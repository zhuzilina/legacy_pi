import 'package:flutter/material.dart';

class KnowledgeDetailPage extends StatelessWidget {
  final Map<String, dynamic> knowledge;

  const KnowledgeDetailPage({
    super.key,
    required this.knowledge,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          knowledge['title'] ?? '知识详情',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            SelectableText(
              knowledge['title'] ?? '无标题',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            
            // 来源信息
            if (knowledge['source'] != null) ...[
              SelectableText(
                '来源：${knowledge['source']}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // 内容
            if (knowledge['content'] != null) ...[
              SelectableText(
                knowledge['content'],
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.6,
                  color: Colors.black,
                ),
              ),
            ] else ...[
              const SelectableText(
                '暂无内容',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

}
