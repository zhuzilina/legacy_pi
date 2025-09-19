import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pages/chat_page.dart';
import '../models/article.dart';

class BookReaderPage extends StatefulWidget {
  final Map<String, dynamic> book;
  final Article? article; // 添加文章对象支持，用于问AI功能

  const BookReaderPage({
    super.key,
    required this.book,
    this.article,
  });

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  final PageController _pageController = PageController();
  List<String> _pages = [];
  final List<String> _loadedPages = [];
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isAppBarVisible = true;
  bool _isBottomBarVisible = true;
  int _charsPerPage = 400; // 动态计算的每页字符数

  @override
  void initState() {
    super.initState();
    _loadAndSplitBook();
  }

  
  
  Future<void> _loadAndSplitBook() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final String content = await rootBundle.loadString(widget.book['file']);

      // 使用LayoutBuilder来计算准确的字符数
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateCharsPerPageWithLayoutBuilder(content);
      });

    } catch (e) {
      setState(() {
        _errorMessage = '加载书籍内容失败: $e';
        _isLoading = false;
      });
    }
  }

  // 使用LayoutBuilder和TextPainter精确计算每页字符数
  void _calculateCharsPerPageWithLayoutBuilder(String content) {
    final fontSize = 20.0;
    final lineHeight = 1.8;
    final textStyle = TextStyle(fontSize: fontSize, height: lineHeight, color: Colors.black87);

    // 使用TextPainter来测量文本尺寸
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: '测', style: textStyle),
    );

    // 计算单个字符的宽度和行高
    textPainter.layout();
    final charWidth = textPainter.width;
    final lineHeightPx = textPainter.height;

    // 计算可用空间
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    final bottomBarHeight = 80;
    final verticalPadding = 64; // 上40px，下24px padding
    final horizontalPadding = 48; // 左右各24px padding

    final availableHeight = screenHeight - appBarHeight - bottomBarHeight - verticalPadding;
    final availableWidth = screenWidth - horizontalPadding;

    // 计算每页可显示的行数
    final linesPerPage = (availableHeight / lineHeightPx).floor();

    // 计算每行可显示的字符数
    final charsPerLine = (availableWidth / charWidth).floor();

    // 计算每页字符数，留出一些余量给段落间距和标点符号
    _charsPerPage = (linesPerPage * charsPerLine * 0.85).floor(); // 85%的余量

    // 确保合理的字符数范围
    if (_charsPerPage < 100) {
      _charsPerPage = 100;
    } else if (_charsPerPage > 500) {
      _charsPerPage = 500;
    }

    print('精确计算结果: 字符宽度=${charWidth.toStringAsFixed(2)}, 行高=${lineHeightPx.toStringAsFixed(2)}');
    print('可用高度=$availableHeight, 每页行数=$linesPerPage');
    print('可用宽度=$availableWidth, 每行字符数=$charsPerLine');
    print('最终每页字符数=$_charsPerPage');

    // 现在进行分页
    final List<String> splitPages = _splitContentIntoPages(content);

    setState(() {
      _pages = splitPages;
      _totalPages = splitPages.length;
      _isLoading = false;
      _preloadPages();
    });
  }

  List<String> _splitContentIntoPages(String content) {
    List<String> pages = [];
    int startIndex = 0;

    while (startIndex < content.length) {
      int endIndex = startIndex + _charsPerPage;

      if (endIndex >= content.length) {
        endIndex = content.length;
      } else {
        // 尝试在句子边界分割
        int lastPeriod = content.lastIndexOf('。', endIndex);
        int lastExclamation = content.lastIndexOf('！', endIndex);
        int lastQuestion = content.lastIndexOf('？', endIndex);
        int lastLineBreak = content.lastIndexOf('\n', endIndex);
        int lastComma = content.lastIndexOf('，', endIndex);
        int lastSemicolon = content.lastIndexOf('；', endIndex);

        int bestBreak = math.max(lastPeriod, math.max(lastExclamation, lastQuestion));
        bestBreak = math.max(bestBreak, lastLineBreak);
        bestBreak = math.max(bestBreak, lastComma);
        bestBreak = math.max(bestBreak, lastSemicolon);

        // 如果找到合适的分割点，并且不会让页面内容过少
        if (bestBreak > startIndex + _charsPerPage / 3) {
          endIndex = bestBreak + 1;
        }
      }

      String pageContent = content.substring(startIndex, endIndex).trim();
      if (pageContent.isNotEmpty) {
        pages.add(pageContent);
      }
      startIndex = endIndex;
    }

    return pages.isNotEmpty ? pages : ['暂无内容'];
  }

  void _preloadPages() {
    // 预加载当前页和前后各一页
    for (int i = math.max(0, _currentPage - 1);
         i <= math.min(_totalPages - 1, _currentPage + 1);
         i++) {
      if (!_loadedPages.contains(i.toString())) {
        _loadedPages.add(i.toString());
      }
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      _preloadPages();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          setState(() {
            _isAppBarVisible = !_isAppBarVisible;
            _isBottomBarVisible = !_isBottomBarVisible;
          });
        },
        child: Container(
          color: Colors.white,
          child: Stack(
            children: [
              // 主要内容
              Positioned.fill(
                top: _isAppBarVisible ? kToolbarHeight + MediaQuery.of(context).padding.top : 0,
                bottom: _isBottomBarVisible ? 80 : 0,
                child: _buildContent(),
              ),
              // 顶部AppBar
              if (_isAppBarVisible)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildAppBar(),
                ),
              // 底部工具栏
              if (_isBottomBarVisible)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomBar(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
  return Container(
    height: kToolbarHeight + MediaQuery.of(context).padding.top,
    decoration: BoxDecoration(
      color: Colors.red[600],
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          height: MediaQuery.of(context).padding.top,
          color: Colors.red[600],
        ),
        Container(
          height: kToolbarHeight,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  widget.book['title'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadAndSplitBook,
                tooltip: '重新加载',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载书籍内容...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAndSplitBook,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: _totalPages,
      itemBuilder: (context, index) {
        return _buildPage(_pages[index], index);
      },
    );
  }

  Widget _buildPage(String content, int pageIndex) {
    return Container(
      padding: const EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        bottom: 24.0,
        top: 40.0, // 增加上边距
      ),
      child: _buildSelectableTextWithAiOption(content),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 进度信息
          Text(
            '${_currentPage + 1} / $_totalPages',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: _totalPages > 0 ? (_currentPage + 1) / _totalPages : 0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red[600]!),
            ),
          ),
          const SizedBox(width: 8),
          // 导航按钮
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0
                ? () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : null,
            tooltip: '上一页',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages - 1
                ? () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : null,
            tooltip: '下一页',
          ),
        ],
      ),
    );
  }

  // 构建带有AI选项的可选择文本
  Widget _buildSelectableTextWithAiOption(String text) {
    return SelectableText(
      text,
      style: const TextStyle(
        fontSize: 20, // 调大字体
        height: 1.8,
        color: Colors.black87,
      ),
      enableInteractiveSelection: true,
      textAlign: TextAlign.start,
      maxLines: null, // 允许多行显示
      contextMenuBuilder: (context, editableTextState) {
        return AdaptiveTextSelectionToolbar(
          anchors: editableTextState.contextMenuAnchors,
          children: [
            // 默认的复制选项
            Material(
              child: InkWell(
                onTap: () {
                  editableTextState.copySelection(SelectionChangedCause.toolbar);
                  editableTextState.hideToolbar();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('复制'),
                ),
              ),
            ),
            Material(
              child: InkWell(
                onTap: () {
                  editableTextState.selectAll(SelectionChangedCause.toolbar);
                  editableTextState.hideToolbar();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('全选'),
                ),
              ),
            ),
            // 新增的"问AI"选项
            if (widget.article != null) // 只有在有文章对象时才显示"问AI"选项
              Material(
                child: InkWell(
                  onTap: () {
                    editableTextState.hideToolbar();
                    // 获取用户实际选择的文本
                    final selectedText = editableTextState.currentTextEditingValue.selection.textInside(
                      editableTextState.currentTextEditingValue.text,
                    );
                    _navigateToChatWithSelectedText(context, selectedText);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 16),
                        SizedBox(width: 8),
                        Text('问AI'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // 获取选中文本的预览（前7个字符）
  String _getSelectedTextPreview(String selectedText) {
    // 移除多余的空白字符
    String trimmedText = selectedText.trim();
    // 使用字符而不是字节来计数，确保中文字符正确计算
    if (trimmedText.length <= 7) {
      return trimmedText;
    } else {
      return '${trimmedText.substring(0, 7)}...';
    }
  }

  // 导航到聊天页面，传递选中的文本作为AI上下文
  void _navigateToChatWithSelectedText(BuildContext context, String selectedText) {
    if (widget.article == null) return;

    // 创建包含选中文本的Article对象作为AI上下文
    final articleWithContext = Article(
      id: widget.article!.id,
      title: _getSelectedTextPreview(selectedText), // 修改标题为选中文本的预览
      source: widget.article!.source,
      publishTime: widget.article!.publishTime,
      category: widget.article!.category,
      wordCount: widget.article!.wordCount,
      originalUrl: widget.article!.originalUrl,
      metaInfo: '选中文本', // 修改元信息
      content: '选中文本内容：\n\n$selectedText\n\n---\n\n${widget.article!.content}',
      collectTime: widget.article!.collectTime,
    );

    // 导航到聊天页面，传递包含选中文本的Article对象，但不自动填充输入框
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          article: articleWithContext,
          messageParam: '', // 不自动填充到输入框
        ),
      ),
    );
  }
}