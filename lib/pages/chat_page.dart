import 'package:flutter/material.dart';
import 'package:legacy_pi/models/article.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_record_service.dart';
import '../services/markdown_parser_service.dart';

class ChatPage extends StatefulWidget {
  final Article article; // 接收文章数据
  final String? messageParam; // 新增：消息参数
  final String? conversationId; // 新增：对话ID，用于区分不同的对话场景

  const ChatPage({
    super.key,
    required this.article,
    this.messageParam, // 可选的消息参数
    this.conversationId, // 可选的对话ID
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isVoiceMode = false; // 新增：语音模式状态
  final List<File> _selectedImages = []; // 新增：选中的图片列表
  final ImagePicker _imagePicker = ImagePicker(); // 新增：图片选择器
  
  // AI对话API配置
  static const String _baseUrl = 'http://10.0.2.2:8000/api/ai-chat';
  static const String _systemPromptType = 'red_culture'; // 使用红色文化主题
  bool _isLoading = false; // 加载状态
  bool _showArticleCapsule = true; // 控制文章标题胶囊的显示状态
  
  // 聊天记录缓存相关
  late SharedPreferences _prefs;
  String get _chatKey {
    // 如果有对话ID，使用对话ID作为缓存键的一部分
    if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
      return 'chat_${widget.article.title.hashCode}_${widget.conversationId}';
    }
    // 否则使用默认的缓存键（基于文章标题）
    return 'chat_${widget.article.title.hashCode}';
  }

  @override
  void initState() {
    super.initState();
    // 初始化SharedPreferences并加载缓存的聊天记录
    _initializeChat();
    
    // 如果有消息参数，自动填充到输入框
    if (widget.messageParam != null && widget.messageParam!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _textController.text = widget.messageParam!;
        });
        // 自动聚焦到输入框
        _focusNode.requestFocus();
      });
    }
  }

  void _initializeChat() async {
    // 初始化SharedPreferences
    _prefs = await SharedPreferences.getInstance();
    
    // 加载缓存的聊天记录
    await _loadChatHistory();
  }
  
  // 加载缓存的聊天记录
  Future<void> _loadChatHistory() async {
    try {
      final chatData = _prefs.getString(_chatKey);
      if (chatData != null) {
        final List<dynamic> chatList = jsonDecode(chatData);
        setState(() {
          _messages.clear();
          for (var item in chatList) {
            _messages.add(ChatMessage(
              text: item['text'],
              sender: item['sender'],
            ));
          }
        });
        
        // 如果已有聊天记录，说明文章参数已经被使用过
        if (_messages.isNotEmpty) {
          setState(() {
            _showArticleCapsule = false;
          });
        }
        
        print('已加载缓存的聊天记录，共${_messages.length}条');
      }
    } catch (e) {
      print('加载聊天记录失败: $e');
    }
  }

  void _handleSendPressed(String text) async {
    if (text.trim().isEmpty) return;
    
    setState(() {
      // 添加用户消息
      _messages.insert(0, ChatMessage(text: text.trim(), sender: "user"));
      _textController.clear();
      _isLoading = true; // 开始加载
    });

    // 保存聊天记录到本地
    await _saveChatHistory();

    // 调用真实的AI对话API
    await _callAIChatAPI(text.trim());
  }

  Future<void> _callAIChatAPI(String userMessage) async {
    try {
      // 构建对话历史
      List<Map<String, String>> conversationHistory = [];
      
      // 根据胶囊显示状态决定是否包含文章内容
      if (_showArticleCapsule) {
        // 文章内容仍然显示时，将其作为系统上下文
        final articleContext = "我已经了解了这篇文章：${widget.article.title}\n\n${widget.article.content}";
        conversationHistory.add({
          "role": "assistant",
          "content": articleContext
        });
        
        print('文章内容已添加到对话历史开头:');
        print('标题: ${widget.article.title}');
        print('内容长度: ${widget.article.content.length}');
        
        // 第一次插入后自动移除文章参数
        setState(() {
          _showArticleCapsule = false;
        });
        print('文章参数已自动移除，不再显示胶囊');
      } else {
        // 文章内容已清除，不添加到对话历史
        print('文章内容已清除，不再添加到对话历史中');
      }
      
      // 添加最近的对话历史（最多10轮）
      int startIndex = _messages.length > 10 ? _messages.length - 10 : 0;
      for (int i = startIndex; i < _messages.length; i++) {
        ChatMessage msg = _messages[i];
        if (msg.sender == "user") {
          conversationHistory.add({
            "role": "user",
            "content": msg.text
          });
        } else if (msg.sender == "assistant") {
          conversationHistory.add({
            "role": "assistant",
            "content": msg.text
          });
        }
      }
      
      print('对话历史总长度: ${conversationHistory.length}');
      
      // 构建请求数据
      final requestData = {
        "message": userMessage,
        "conversation_history": conversationHistory,
        "system_prompt_type": _systemPromptType,
        "max_tokens": 2000,
        "temperature": 0.7
      };
      
      // 验证对话历史构建是否正确
      _validateConversationHistory(conversationHistory);
      
      // 调试信息：打印请求数据（开发阶段使用）
      print('API请求数据:');
      print('用户消息: $userMessage');
      print('对话历史长度: ${conversationHistory.length}');
      print('文章标题: ${widget.article.title}');
      print('文章内容长度: ${widget.article.content.length}');
      
      // 发送API请求
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      );
      
      if (mounted) {
        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          if (responseData['success'] == true) {
            setState(() {
              _messages.insert(0, ChatMessage(
                text: responseData['data']['response'],
                sender: "assistant",
              ));
              _isLoading = false;
            });
            
            // 保存AI回复到本地
            await _saveChatHistory();
          } else {
            // API返回错误
            setState(() {
              _messages.insert(0, ChatMessage(
                text: "抱歉，AI服务暂时不可用，请稍后再试。",
                sender: "assistant",
              ));
              _isLoading = false;
            });
            
            // 保存错误消息到本地
            await _saveChatHistory();
          }
        } else {
          // HTTP错误
          setState(() {
            _messages.insert(0, ChatMessage(
              text: "网络连接失败，请检查网络设置。",
              sender: "assistant",
            ));
            _isLoading = false;
          });
          
          // 保存错误消息到本地
          await _saveChatHistory();
        }
        
        // 滚动到底部
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.insert(0, ChatMessage(
            text: "发生错误：$e",
            sender: "assistant",
          ));
          _isLoading = false;
        });
        
        // 保存错误消息到本地
        await _saveChatHistory();
        _scrollToBottom();
      }
    }
  }



  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  // 验证对话历史构建是否正确
  void _validateConversationHistory(List<Map<String, String>> history) {
    print('=== 对话历史验证 ===');
    print('总长度: ${history.length}');
    
    for (int i = 0; i < history.length; i++) {
      final item = history[i];
      print('[$i] ${item['role']}: ${item['content']?.substring(0, item['content']!.length > 50 ? 50 : item['content']!.length)}...');
    }
    print('==================');
  }
  
  // 保存聊天记录到本地
  Future<void> _saveChatHistory() async {
    try {
      final List<Map<String, String>> chatData = _messages.map((msg) => {
        'text': msg.text,
        'sender': msg.sender,
      }).toList();
      
      // 保存到本地存储
      await _prefs.setString(_chatKey, jsonEncode(chatData));
      
      // 使用聊天记录服务保存记录
      await ChatRecordService.saveChatRecord(widget.article, chatData);
      
      print('聊天记录已保存到本地');
    } catch (e) {
      print('保存聊天记录失败: $e');
    }
  }
  


  // 切换语音/文本输入模式
  void _toggleInputMode() {
    setState(() {
      _isVoiceMode = !_isVoiceMode;
      if (_isVoiceMode) {
        // 切换到语音模式时，清空输入框并失去焦点
        _textController.clear();
        _focusNode.unfocus();
      } else {
        // 切换到文本模式时，聚焦到输入框
        _focusNode.requestFocus();
      }
    });
  }

  // 处理语音录制开始
  void _startVoiceRecording() {
    // TODO: 实现语音录制逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('开始语音录制...')),
    );
  }

  // 处理语音录制结束
  void _stopVoiceRecording() {
    // TODO: 实现语音录制结束逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('语音录制结束，正在识别...')),
    );
  }

  // 选择图片
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (images.isNotEmpty) {
        setState(() {
          // 限制最多3张图片
          int remainingSlots = 3 - _selectedImages.length;
          int imagesToAdd = images.length > remainingSlots ? remainingSlots : images.length;
          
          for (int i = 0; i < imagesToAdd; i++) {
            _selectedImages.add(File(images[i].path));
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片时出错: $e')),
      );
    }
  }

  // 移除图片
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "AI 对话助手",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.red[700],
        elevation: 2,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // 聊天消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true, // 消息列表反转，最新的消息在最下面
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (_, int index) {
                if (_isLoading && index == 0) {
                  // 显示加载指示器
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      children: [
                        const SizedBox(width: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(20.0),
                              bottomLeft: Radius.circular(20.0),
                              bottomRight: Radius.circular(20.0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'AI正在思考中...',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // 显示实际消息
                int messageIndex = _isLoading ? index - 1 : index;
                return _messages[messageIndex];
              },
            ),
          ),
          const Divider(height: 1.0),
          // 底部输入区域
          _buildInputArea(),
        ],
      ),
    );
  }

  // 构建底部输入区域的 Widget
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: Colors.white,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上方选项按钮栏
            _buildOptionsBar(),
            const SizedBox(height: 12),
            // 消息输入框和发送按钮
            _buildMessageInputRow(),
          ],
        ),
      ),
    );
  }

  // 构建上方选项按钮栏
  Widget _buildOptionsBar() {
    return Row(
      children: [
        // 已选择的图片
        ..._selectedImages.asMap().entries.map((entry) {
          int index = entry.key;
          File image = entry.value;
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                // 图片
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      image,
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                    ),
                  ),
                ),
                // 删除按钮
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: () => _removeImage(index),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.red[600],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        
        // 图片选择按钮（当图片少于3张时显示）
        if (_selectedImages.length < 3)
          IconButton(
            icon: Icon(Icons.image_outlined, color: Colors.grey[600], size: 20),
            onPressed: _pickImages,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        
        // 文章标题胶囊容器（条件显示）
        if (_showArticleCapsule) ...[
          const SizedBox(width: 16), // 增加间距
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white, // 改为白色背景
              borderRadius: BorderRadius.circular(8), // 改为有点圆角的矩形
              // 移除边框
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '@', // 添加@符号
                  style: TextStyle(
                    color: Colors.black, // 改为黑色
                    fontSize: 14, // 从12调大到14
                    fontWeight: FontWeight.w900, // 改为加粗
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _getArticleTitlePreview(),
                  style: TextStyle(
                    color: Colors.black, // 黑色文字
                    fontSize: 14, // 从12调大到14
                    fontWeight: FontWeight.w900, // 改为加粗
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showArticleCapsule = false; // 隐藏胶囊
                    });
                    // 显示提示信息
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('文章参数已清除，AI将不再基于该文章内容进行回复'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.close,
                    size: 18, // 从16调大到18
                    color: Colors.black, // 改为黑色
                    weight: 900, // 改为加粗
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 获取文章标题前7个字的预览
  String _getArticleTitlePreview() {
    String title = widget.article.title;
    // 使用字符而不是字节来计数，确保中文字符正确计算
    if (title.length <= 7) {
      return title;
    } else {
      return '${title.substring(0, 7)}...';
    }
  }

  // 构建消息输入行
  Widget _buildMessageInputRow() {
    return Row(
      children: [
        // 语音输入/键盘切换按钮
        IconButton(
          icon: Icon(
            _isVoiceMode ? Icons.keyboard : Icons.mic_none,
            color: _isVoiceMode ? Colors.grey[600] : Colors.black,
            size: 20,
            weight: _isVoiceMode ? null : 900,
          ),
          onPressed: _toggleInputMode,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        const SizedBox(width: 8),
        // 输入框或语音录制按钮
        Expanded(
          child: _isVoiceMode
              ? _buildVoiceRecordingButton()
              : _buildTextInputField(),
        ),
      ],
    );
  }

  // 构建语音录制按钮
  Widget _buildVoiceRecordingButton() {
    return GestureDetector(
      onTapDown: (_) => _startVoiceRecording(),
      onTapUp: (_) => _stopVoiceRecording(),
      onTapCancel: () => _stopVoiceRecording(),
      child: Container(
        height: 48, // 与输入框高度一致
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '按住说话',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // 构建文本输入框
  Widget _buildTextInputField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        minLines: 1,
        maxLines: 4,
        textInputAction: TextInputAction.send,
        decoration: const InputDecoration(
          hintText: "输入消息...",
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        onSubmitted: _handleSendPressed,
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
}

// 单条聊天消息的 Widget
class ChatMessage extends StatelessWidget {
  final String text;
  final String sender;
  final bool isArticle; // 标记是否是文章内容

  const ChatMessage({
    super.key, 
    required this.text, 
    required this.sender,
    this.isArticle = false,
  });

  @override
  Widget build(BuildContext context) {
    bool isUser = sender == 'user';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          // 消息气泡
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isArticle 
                    ? Colors.blue[50] 
                    : (isUser ? Colors.red[700] : Colors.white),
                borderRadius: isUser
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(20.0),
                        bottomLeft: Radius.circular(20.0),
                        bottomRight: Radius.circular(20.0),
                      )
                    : const BorderRadius.only(
                        topRight: Radius.circular(20.0),
                        bottomLeft: Radius.circular(20.0),
                        bottomRight: Radius.circular(20.0),
                      ),
                border: isArticle 
                    ? Border.all(color: Colors.blue[200]!, width: 1)
                    : null,
                boxShadow: isArticle 
                    ? null 
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isArticle) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.article,
                          size: 16,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '文章内容',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  // 根据发送者类型决定是否使用markdown解析
                  if (isUser || isArticle) ...[
                    // 用户消息和文章内容使用普通文本
                    Text(
                      text,
                      style: TextStyle(
                        color: isArticle 
                            ? Colors.black87 
                            : (isUser ? Colors.white : Colors.black87),
                        fontSize: isArticle ? 14 : 16,
                        height: 1.4,
                      ),
                    ),
                  ] else ...[
                    // AI回复使用markdown解析
                    ...MarkdownParserService().parseMarkdown(text),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
