import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/unified_cache_service.dart';
import '../services/ai_explanation_service.dart';
import '../services/quiz_history_service.dart';
import '../database/database_helper.dart';
import '../models/content_item.dart';
import 'rich_content_widget.dart';

class AIExplanationWidget extends StatefulWidget {
  final Map<String, dynamic> question;
  final List<String> userAnswer;
  final bool isCorrect;
  final bool hasAnswered;
  final VoidCallback? onRetry;
  final int? quizRecordId; // 新增：答题记录ID，用于保存AI解答

  const AIExplanationWidget({
    super.key,
    required this.question,
    required this.userAnswer,
    required this.isCorrect,
    required this.hasAnswered,
    this.onRetry,
    this.quizRecordId,
  });

  @override
  State<AIExplanationWidget> createState() => _AIExplanationWidgetState();
}

class _AIExplanationWidgetState extends State<AIExplanationWidget> {
  bool _loadingExplanation = false;
  String _explanation = '';
  bool _showExplanation = false;
  bool _allowRetry = false;
  final AiService _aiService = AiService();
  final UnifiedCacheService _cacheService = UnifiedCacheService();

  @override
  void initState() {
    super.initState();
    if (widget.hasAnswered && !widget.isCorrect) {
      _checkCachedExplanation();
    }
  }

  @override
  void didUpdateWidget(AIExplanationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasAnswered && !widget.isCorrect && !oldWidget.hasAnswered) {
      _checkCachedExplanation();
    }
  }

  Future<void> _getAIExplanation() async {
    setState(() {
      _loadingExplanation = true;
    });

    try {
      // 组织题目、选项和用户答案为文本
      String questionText = widget.question['question_text'] ?? '';
      String questionTextContent = '题目：$questionText\n\n';

      // 添加选项
      if (widget.question['question_type'] == 'choice' || widget.question['question_type'] == 'multiple_choice') {
        questionTextContent += '选项：\n';
        final options = widget.question['options'] as List? ?? [];
        for (int i = 0; i < options.length; i++) {
          final option = options[i];
          final optionText = option['text'] ?? '';
          final isCorrect = option['is_correct'] == true;
          final userSelected = widget.userAnswer.contains(optionText);
          // 只在用户答对时显示正确答案标记，答错时不显示
          questionTextContent += '${String.fromCharCode(65 + i)}. $optionText ${widget.isCorrect && isCorrect ? '(正确答案)' : ''} ${userSelected ? '(用户选择)' : ''}\n';
        }
        questionTextContent += '\n';
      }

      // 添加用户答案
      questionTextContent += '用户答案：${widget.userAnswer.join(', ')}\n';
      questionTextContent += '答题结果：${widget.isCorrect ? '正确' : '错误'}\n';

      // 添加自定义提示词
      final customPrompt = '''
请对以下题目进行详细解答：
1. 分析题目的考点和知识点
2. 解释正确答案的原因
3. 如果用户答错了，分析错误原因
4. 给出相关的知识点延伸和记忆方法
5. 解答要详细、易懂，适合学习使用

题目内容：
''';

      // 生成缓存键
      final questionId = widget.question['id']?.toString() ?? questionText;
      final cacheKey = 'question_explanation_${questionId}_${widget.userAnswer.join('_')}';

      print('发送给AI的文本长度: ${questionTextContent.length}');
      print('缓存键: $cacheKey');

      // 首先检查缓存
      final cachedResponse = _cacheService.getAiCache(
        questionTextContent,
        'question_explanation',
        customPrompt
      );

      if (cachedResponse != null && cachedResponse.data != null) {
        print('从缓存获取AI解答成功');
        setState(() {
          _explanation = cachedResponse.data!.interpretation;
          _loadingExplanation = false;
          _showExplanation = true;
          _allowRetry = true;
        });
        return;
      }

      // 没有缓存，调用API
      final response = await _aiService.interpretText(
        text: questionTextContent,
        promptType: 'question_explanation',
        customPrompt: customPrompt,
        maxTokens: 2000,
      );

      if (response != null && response.success && response.data != null) {
        print('AI解答成功 - 结果长度: ${response.data!.interpretation.length}');
        final explanationText = response.data!.interpretation;

        setState(() {
          _explanation = explanationText;
          _loadingExplanation = false;
          _showExplanation = true;
          _allowRetry = true;
        });

        // 保存AI解答到数据库
        if (widget.quizRecordId != null) {
          await _saveAIExplanationToDatabase(explanationText);
        }

        // 结果已由AiService自动缓存
      } else {
        print('AI解答失败 - 错误: ${response?.error}');
        setState(() {
          _explanation = '获取AI解答失败: ${response?.error ?? '未知错误'}';
          _loadingExplanation = false;
          _showExplanation = true;
          _allowRetry = true;
        });
      }
    } catch (e) {
      setState(() {
        _explanation = '请求异常: $e';
        _loadingExplanation = false;
        _showExplanation = true;
        _allowRetry = true;
      });
    }
  }

  // 保存AI解答到数据库
  Future<void> _saveAIExplanationToDatabase(String explanation) async {
    if (widget.quizRecordId == null) {
      print('无法保存AI解答：quizRecordId为空');
      return;
    }

    try {
      final id = await AIExplanationService.saveAIExplanation(
        quizRecordId: widget.quizRecordId!,
        explanation: explanation,
      );

      if (id != null) {
        print('AI解答已保存到数据库，ID: $id');
      } else {
        print('AI解答保存失败');
      }
    } catch (e) {
      print('保存AI解答到数据库时发生异常: $e');
    }
  }

  // 检查是否有缓存的AI解答
  Future<void> _checkCachedExplanation() async {
    if (widget.userAnswer.isEmpty) return;

    try {
      // 组织题目、选项和用户答案为文本（与_getAIExplanation保持一致）
      String questionText = widget.question['question_text'] ?? '';
      String questionTextContent = '题目：$questionText\n\n';

      // 添加选项
      if (widget.question['question_type'] == 'choice' || widget.question['question_type'] == 'multiple_choice') {
        questionTextContent += '选项：\n';
        final options = widget.question['options'] as List? ?? [];
        for (int i = 0; i < options.length; i++) {
          final option = options[i];
          final optionText = option['text'] ?? '';
          final isCorrect = option['is_correct'] == true;
          final userSelected = widget.userAnswer.contains(optionText);
          questionTextContent += '${String.fromCharCode(65 + i)}. $optionText ${widget.isCorrect && isCorrect ? '(正确答案)' : ''} ${userSelected ? '(用户选择)' : ''}\n';
        }
        questionTextContent += '\n';
      }

      // 添加用户答案
      questionTextContent += '用户答案：${widget.userAnswer.join(', ')}\n';
      questionTextContent += '答题结果：${widget.isCorrect ? '正确' : '错误'}\n';

      // 添加自定义提示词
      final customPrompt = '''
请对以下题目进行详细解答：
1. 分析题目的考点和知识点
2. 解释正确答案的原因
3. 如果用户答错了，分析错误原因
4. 给出相关的知识点延伸和记忆方法
5. 解答要详细、易懂，适合学习使用

题目内容：
''';

      // 检查缓存
      final cachedResponse = _cacheService.getAiCache(
        questionTextContent,
        'question_explanation',
        customPrompt
      );

      if (cachedResponse != null && cachedResponse.data != null) {
        print('发现缓存的AI解答');
        setState(() {
          _explanation = cachedResponse.data!.interpretation;
          _allowRetry = true;
          // 如果用户已答错，直接显示AI解答区域
          if (widget.hasAnswered && !widget.isCorrect) {
            _showExplanation = true;
          }
        });
      }
    } catch (e) {
      print('检查缓存失败: $e');
    }
  }

  // 将AI解答文本转换为ContentItem列表
  List<ContentItem> _parseExplanationToContentItems(String explanation) {
    final List<ContentItem> items = [];
    final lines = explanation.split('\n');
    List<String> tableRows = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // 检测标题（# 标题）
      if (line.startsWith('# ')) {
        _flushTableRows(tableRows, items);
        items.add(ContentItem(
          type: ContentItemType.text,
          text: '${line.substring(2)}\n\n',
        ));
      }
      // 检测二级标题（## 标题）
      else if (line.startsWith('## ')) {
        _flushTableRows(tableRows, items);
        items.add(ContentItem(
          type: ContentItemType.text,
          text: '${line.substring(3)}\n\n',
        ));
      }
      // 检测三级标题（### 标题）
      else if (line.startsWith('### ')) {
        _flushTableRows(tableRows, items);
        items.add(ContentItem(
          type: ContentItemType.text,
          text: '${line.substring(4)}\n\n',
        ));
      }
      // 检测四级标题（#### 标题）
      else if (line.startsWith('#### ')) {
        _flushTableRows(tableRows, items);
        items.add(ContentItem(
          type: ContentItemType.text,
          text: '${line.substring(5)}\n\n',
        ));
      }
      // 检测有序列表项（1. 、2. 等）
      else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        _flushTableRows(tableRows, items);
        final itemContent = line.substring(line.indexOf('.') + 1).trim();
        items.add(ContentItem(
          type: ContentItemType.text,
          text: '• $itemContent\n',
        ));
      }
      // 检测无序列表项（- 或 *）
      else if (line.startsWith('- ') || line.startsWith('* ')) {
        _flushTableRows(tableRows, items);
        final itemContent = line.substring(2).trim();
        items.add(ContentItem(
          type: ContentItemType.text,
          text: '• $itemContent\n',
        ));
      }
      // 检测表格（包含 | 分隔符的行）
      else if (line.contains('|') && line.split('|').length > 2) {
        tableRows.add(line);
      }
      // 检测分隔线
      else if (line.startsWith('---') || line.startsWith('***')) {
        _flushTableRows(tableRows, items);
        items.add(ContentItem(
          type: ContentItemType.text,
          text: '---\n',
        ));
      }
      // 检测引用块（> 开头）
      else if (line.startsWith('> ')) {
        _flushTableRows(tableRows, items);
        items.add(ContentItem(
          type: ContentItemType.text,
          text: '${line.substring(2)}\n',
        ));
      }
      // 检测代码块（``` 开头）
      else if (line.startsWith('```')) {
        _flushTableRows(tableRows, items);
        items.add(ContentItem(
          type: ContentItemType.text,
          text: '代码块\n',
        ));
      }
      // 普通段落（可能包含加粗、斜体等）
      else {
        _flushTableRows(tableRows, items);
        // 处理加粗文本 **text** -> *text*
        String processedLine = line;
        processedLine = processedLine.replaceAllMapped(
          RegExp(r'\*\*(.*?)\*\*'),
          (match) => '*${match.group(1)}*',
        );
        items.add(ContentItem(
          type: ContentItemType.text,
          text: '$processedLine\n',
        ));
      }
    }

    // 处理剩余的表格行
    _flushTableRows(tableRows, items);

    return items;
  }

  // 处理表格行
  void _flushTableRows(List<String> tableRows, List<ContentItem> items) {
    if (tableRows.isNotEmpty) {
      // 过滤掉分隔线（如 |---|---|---）
      final filteredRows = tableRows.where((row) =>
        !row.trim().startsWith('|---') && !row.trim().startsWith('| :---')
      ).toList();

      if (filteredRows.isNotEmpty) {
        // 将表格合并为一个内容项
        final tableContent = filteredRows.join('\n');
        items.add(ContentItem(
          type: ContentItemType.text,
          text: '$tableContent\n',
        ));
      }
      tableRows.clear();
    }
  }

  // 重置答题状态，允许用户重新答题
  void _resetAnswer() {
    if (widget.onRetry != null) {
      widget.onRetry!();
    }
    setState(() {
      _showExplanation = false;
      _allowRetry = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 只在用户答错时显示AI解答区域
    if (!widget.hasAnswered || widget.isCorrect) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue[50],
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI解答标题栏
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI智能解答',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        '学习加50积分',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (!_showExplanation) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // 获取AI解答按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loadingExplanation ? null : _getAIExplanation,
                      icon: _loadingExplanation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.smart_toy),
                      label: _loadingExplanation
                          ? const Text('获取中...', style: TextStyle(fontSize: 16))
                          : const Text('获取AI解答', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // AI解答内容
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: Colors.blue[300],
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'AI解析内容',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                            const Spacer(),
                            if (_explanation.isNotEmpty)
                              Text(
                                'AI生成内容，仅供参考',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_loadingExplanation)
                          Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'AI正在为您生成详细解答...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_explanation.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 使用RichContentWidget解析Markdown内容
                              RichContentWidget(
                                contentItems: _parseExplanationToContentItems(_explanation),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: Colors.black87,
                                ),
                                textColor: Colors.black87,
                                enableScrolling: false,
                                cacheService: _cacheService,
                              ),
                              const SizedBox(height: 16),
                              // 重新答题按钮
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _resetAnswer,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('重新答题', style: TextStyle(fontSize: 16)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}