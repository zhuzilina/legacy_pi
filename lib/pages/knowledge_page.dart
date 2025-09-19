import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:legacy_pi/pages/pk.dart';
import 'dart:convert';
import 'daily_question_page.dart';
import 'recent_learning_page.dart';
import 'book_reader_page.dart';
import '../models/article.dart';

class KnowledgePage extends StatefulWidget {
  const KnowledgePage({super.key});

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  // 书籍数据
  List<Map<String, dynamic>> _books = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadBooksData();
  }

  // 加载书籍数据
  Future<void> _loadBooksData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final String response = await rootBundle.loadString('assets/config/book.json');
      final List<dynamic> data = await json.decode(response);
      setState(() {
        _books = data.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载书籍数据失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildFunctionBlocks(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildBookGrid(),
        ],
      ),
    );
  }

  // 功能区块
  Widget _buildFunctionBlocks() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.3,
      child: Column(
        children: [
          // 第一行：知识挑战和每日一答
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildFunctionCard(
                    title: '答题pk',
                    icon: Icons.emoji_events,
                    color: Colors.amber[600]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PKPage())
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFunctionCard(
                    title: '每日一答',
                    icon: Icons.quiz,
                    color: Colors.blue[600]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DailyQuestionPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 第二行：最近学习和党史题库
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildFunctionCard(
                    title: '最近学习',
                    icon: Icons.history,
                    color: Colors.green[600]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RecentLearningPage()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFunctionCard(
                    title: '党史题库',
                    icon: Icons.menu_book,
                    color: Colors.red[600]!,
                    onTap: () {
                      // 党史题库功能暂时跳转到每日一答页面
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DailyQuestionPage()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 书籍网格
  Widget _buildBookGrid() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBooksData,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_books.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                '暂无书籍内容',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.7,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildBookCard(_books[index]),
          childCount: _books.length,
        ),
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // 处理书籍点击事件，跳转到阅读页面
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookReaderPage(
                book: book,
                // 创建一个Article对象来支持问AI功能
                article: Article(
                  id: book['id'].toString(),
                  title: book['title'],
                  source: '书籍',
                  publishTime: DateTime.now().toIso8601String(),
                  category: 'book',
                  wordCount: 0,
                  originalUrl: '',
                  metaInfo: '书籍内容',
                  content: '书籍内容来自：${book['file']}',
                  collectTime: DateTime.now().toIso8601String(),
                ),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 书籍封面
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.asset(
                  book['cover'],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(
                          Icons.book,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // 书籍信息
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
