import 'package:flutter/material.dart';
import 'package:legacy_pi/models/article.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_record_service.dart';
import '../services/markdown_parser_service.dart';
import '../config/api_config.dart';

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
  
  // 历史消息加载相关
  bool _isLoadingHistory = false; // 是否正在加载历史消息
  bool _hasMoreHistory = true; // 是否还有更多历史消息
  static const int _messagesPerPage = 20; // 定义每页加载的消息数量
  
  // AI对话API配置
  static String? _baseUrl;
  static const String _systemPromptType = 'default'; // 使用默认的专业AI知识助手
  bool _isLoading = false; // 加载状态
  bool _showArticleCapsule = true; // 控制文章标题胶囊的显示状态
  
  /// 初始化baseUrl
  static Future<void> _initializeBaseUrl() async {
    if (_baseUrl == null) {
      _baseUrl = await ApiConfig.aiChatBaseUrl;
    }
  }
  
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
    
    // 添加滚动监听器，用于加载历史消息
    _scrollController.addListener(_onScroll);
    
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
  
  // [修复] 加载缓存的聊天记录
  Future<void> _loadChatHistory() async {
    try {
      final chatData = _prefs.getString(_chatKey);
      if (chatData != null) {
        final List<dynamic> chatList = jsonDecode(chatData);
        if (chatList.isEmpty) {
          setState(() {
            _hasMoreHistory = false;
          });
          return;
        }

        // 计算初始加载的消息范围 (从chatList的末尾开始)
        final startIndex = chatList.length > _messagesPerPage ? chatList.length - _messagesPerPage : 0;
        final initialMessagesData = chatList.sublist(startIndex);

        setState(() {
          _messages.clear();
          // 将最新的消息反转后添加到_messages列表
          // chatList: [旧 -> 新], initialMessagesData.reversed: [新 -> 旧]
          _messages.addAll(initialMessagesData.reversed.map((item) => ChatMessage(
            text: item['text'],
            sender: item['sender'],
            // 注意：加载历史消息时，图片信息已丢失，只显示文本
            images: null,
          )));

          // 如果总消息数大于已加载的消息数，说明还有更多历史
          _hasMoreHistory = chatList.length > _messages.length;

          if (_messages.isNotEmpty) {
            _showArticleCapsule = false;
          }
        });

        // [优化] 初始加载后滚动到底部
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
        
        print('已加载初始聊天记录，共${_messages.length}条');
      } else {
        setState(() {
          _hasMoreHistory = false;
        });
      }
    } catch (e) {
      print('加载聊天记录失败: $e');
    }
  }

  void _handleSendPressed(String text) async {
    if (text.trim().isEmpty && _selectedImages.isEmpty) return;
    
    final userMessageText = text.trim();
    final hasImages = _selectedImages.isNotEmpty;

    setState(() {
      // 构建用户消息文本
      String messageText = userMessageText;
      if (hasImages) {
        messageText += " [包含${_selectedImages.length}张图片]";
      }
      
      // 在reverse: true的ListView中，新消息应该插入到列表开头，这样会显示在底部
      _messages.insert(0, ChatMessage(
        text: messageText, 
        sender: "user",
        messageId: "user_${DateTime.now().millisecondsSinceEpoch}",
        images: hasImages ? List.from(_selectedImages) : null, // 保存图片引用
      ));
      _isLoading = true; // 开始加载
    });
    
    // [优化] 发送后立即滚动到底部，提供即时反馈
    _scrollToBottom();

    _textController.clear();
    _focusNode.requestFocus(); // 保持焦点

    // 保存聊天记录到本地 (注意：这里保存的是包含新消息的列表)
    await _saveChatHistory();

    // 根据是否有图片选择不同的API调用
    if (hasImages) {
      // 先上传图片，然后调用图片理解API
      final imageIds = await _uploadImages();
      if (imageIds.isNotEmpty) {
        await _callImageUnderstandingAPI(userMessageText, imageIds);
      } else {
        // 图片上传失败，显示错误消息
        setState(() {
          _messages.insert(0, ChatMessage(
            text: "图片上传失败，请重试。",
            sender: "assistant",
            messageId: "upload_error_${DateTime.now().millisecondsSinceEpoch}",
          ));
          _isLoading = false;
        });
        await _saveChatHistory();
        _scrollToBottom();
      }
    } else {
      // 调用普通的AI对话API
      await _callAIChatAPI(userMessageText);
    }
    
    // 清空选中的图片
    setState(() {
      _selectedImages.clear();
    });
  }

  Future<void> _callAIChatAPI(String userMessage) async {
    try {
      await _initializeBaseUrl();
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
      // 注意：因为_messages是反转的，所以要从头开始取
      int count = 0;
      for (int i = 0; i < _messages.length && count < 20; i++) { // 10轮对话=20条消息
        ChatMessage msg = _messages[i];
         conversationHistory.add({
            "role": msg.sender == "user" ? "user" : "assistant",
            "content": msg.text
        });
        count++;
      }
      // API需要正序历史，所以我们反转一下
      conversationHistory = conversationHistory.reversed.toList();
      
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
      print('API端点: $_baseUrl/chat/');
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
          final responseData = jsonDecode(utf8.decode(response.bodyBytes)); // Use utf8.decode for Chinese characters
          if (responseData['success'] == true) {
            setState(() {
              _messages.insert(0, ChatMessage(
                text: responseData['data']['response'],
                sender: "assistant",
                messageId: "assistant_${DateTime.now().millisecondsSinceEpoch}",
              ));
              _isLoading = false;
            });
            await _saveChatHistory();
          } else {
            setState(() {
              _messages.insert(0, ChatMessage(
                text: "抱歉，AI服务暂时不可用，请稍后再试。",
                sender: "assistant",
                messageId: "error_${DateTime.now().millisecondsSinceEpoch}",
              ));
              _isLoading = false;
            });
            await _saveChatHistory();
          }
        } else {
          print('HTTP错误: 状态码 ${response.statusCode}');
          print('响应内容: ${response.body}');
          setState(() {
            _messages.insert(0, ChatMessage(
              text: "网络连接失败，请检查网络设置。\n错误代码: ${response.statusCode}",
              sender: "assistant",
              messageId: "network_error_${DateTime.now().millisecondsSinceEpoch}",
            ));
            _isLoading = false;
          });
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
            messageId: "exception_${DateTime.now().millisecondsSinceEpoch}",
          ));
          _isLoading = false;
        });
        await _saveChatHistory();
        _scrollToBottom();
      }
    }
  }

  // 调用带图片的AI对话API
  Future<void> _callImageUnderstandingAPI(String userMessage, List<String> imageIds) async {
    try {
      await _initializeBaseUrl();
      
      // 构建对话历史
      List<Map<String, String>> conversationHistory = [];
      
      // 根据胶囊显示状态决定是否包含文章内容
      if (_showArticleCapsule) {
        final articleContext = "我已经了解了这篇文章：${widget.article.title}\n\n${widget.article.content}";
        conversationHistory.add({
          "role": "assistant",
          "content": articleContext
        });
        
        setState(() {
          _showArticleCapsule = false;
        });
      }
      
      // 添加最近的对话历史（最多10轮）
      int count = 0;
      for (int i = 0; i < _messages.length && count < 20; i++) {
        ChatMessage msg = _messages[i];
        conversationHistory.add({
          "role": msg.sender == "user" ? "user" : "assistant",
          "content": msg.text
        });
        count++;
      }
      conversationHistory = conversationHistory.reversed.toList();
      
      // 构建请求数据
      final requestData = {
        "message": userMessage,
        "image_ids": imageIds,
        "conversation_history": conversationHistory,
        "image_prompt_type": "default",
        "max_tokens": 2000,
        "temperature": 0.7
      };
      
      print('图片理解API请求数据:');
      print('API端点: $_baseUrl/chat-with-images/');
      print('用户消息: $userMessage');
      print('图片ID数量: ${imageIds.length}');
      print('对话历史长度: ${conversationHistory.length}');
      
      // 发送API请求
      final response = await http.post(
        Uri.parse('$_baseUrl/chat-with-images/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      );
      
      if (mounted) {
        if (response.statusCode == 200) {
          final responseData = jsonDecode(utf8.decode(response.bodyBytes));
          if (responseData['success'] == true) {
            setState(() {
              _messages.insert(0, ChatMessage(
                text: responseData['data']['response'],
                sender: "assistant",
                messageId: "assistant_${DateTime.now().millisecondsSinceEpoch}",
              ));
              _isLoading = false;
            });
            await _saveChatHistory();
          } else {
            setState(() {
              _messages.insert(0, ChatMessage(
                text: "抱歉，图片理解服务暂时不可用，请稍后再试。",
                sender: "assistant",
                messageId: "error_${DateTime.now().millisecondsSinceEpoch}",
              ));
              _isLoading = false;
            });
            await _saveChatHistory();
          }
        } else {
          print('图片理解API HTTP错误: 状态码 ${response.statusCode}');
          print('响应内容: ${response.body}');
          setState(() {
            _messages.insert(0, ChatMessage(
              text: "图片理解失败，请检查网络设置。\n错误代码: ${response.statusCode}",
              sender: "assistant",
              messageId: "network_error_${DateTime.now().millisecondsSinceEpoch}",
            ));
            _isLoading = false;
          });
          await _saveChatHistory();
        }
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.insert(0, ChatMessage(
            text: "图片理解发生错误：$e",
            sender: "assistant",
            messageId: "exception_${DateTime.now().millisecondsSinceEpoch}",
          ));
          _isLoading = false;
        });
        await _saveChatHistory();
        _scrollToBottom();
      }
    }
  }

  // [优化] 滚动到底部的方法，对于reverse:true的列表，滚动到0即可
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  void _onScroll() {
    // 滚动时自动收起键盘
    _focusNode.unfocus();
    
    // 当滚动到列表顶部（在reverse: true的情况下，这是视觉上的顶部）
    // 并且没有在加载历史消息，且还有更多历史消息时，触发加载
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingHistory && 
        _hasMoreHistory) {
      _loadHistoryMessages();
    }
  }
  
  // [修复] 加载历史消息的正确逻辑
  Future<void> _loadHistoryMessages() async {
    if (_isLoadingHistory || !_hasMoreHistory) return;
    
    setState(() {
      _isLoadingHistory = true;
    });
    
    try {
      // 模拟网络延迟
      await Future.delayed(const Duration(milliseconds: 500));
      
      final chatData = _prefs.getString(_chatKey);
      if (chatData != null) {
        final List<dynamic> chatList = jsonDecode(chatData);

        // 当前已加载的消息数量
        final currentLoadedCount = _messages.length;
        
        // 如果还有更多历史消息可以加载
        if (currentLoadedCount < chatList.length) {
          // 计算要加载的更早消息的范围
          final endIndex = chatList.length - currentLoadedCount;
          final startIndex = endIndex - _messagesPerPage > 0 ? endIndex - _messagesPerPage : 0;
          
          // 获取新加载的消息（从chatList中截取一段更早的消息）
          final newMessagesData = chatList.sublist(startIndex, endIndex);

          setState(() {
            // 将更早的消息反转后添加到_messages列表的末尾
            // 这样在reverse: true的ListView中，它们会显示在视觉上的顶部
            _messages.addAll(newMessagesData.reversed.map((item) => ChatMessage(
              text: item['text'],
              sender: item['sender'],
              messageId: "history_${item.hashCode}",
              // 注意：加载历史消息时，图片信息已丢失，只显示文本
              images: null,
            )));
            _isLoadingHistory = false;

            // 如果已经加载了所有消息，设置没有更多历史消息
            if (_messages.length >= chatList.length) {
              _hasMoreHistory = false;
            }
          });
        } else {
          setState(() {
            _hasMoreHistory = false;
            _isLoadingHistory = false;
          });
        }
      } else {
        setState(() {
          _hasMoreHistory = false;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      print('加载历史消息失败: $e');
      setState(() {
        _isLoadingHistory = false;
      });
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
  
  // [修复] 保存聊天记录到本地
  Future<void> _saveChatHistory() async {
    try {
      // 因为_messages是反向的 (新->旧)，我们需要将其反转为正向 (旧->新) 再保存
      final List<Map<String, dynamic>> chatData = _messages.map((msg) => {
        'text': msg.text,
        'sender': msg.sender,
        'hasImages': msg.images != null && msg.images!.isNotEmpty,
        'imageCount': msg.images?.length ?? 0,
      }).toList().reversed.toList();
      
      // 保存到本地存储
      await _prefs.setString(_chatKey, jsonEncode(chatData));
      
      // 使用聊天记录服务保存记录（转换为字符串格式以兼容现有服务）
      final List<Map<String, String>> stringChatData = _messages.map((msg) => {
        'text': msg.text,
        'sender': msg.sender,
      }).toList().reversed.toList();
      await ChatRecordService.saveChatRecord(widget.article, stringChatData);
      
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

  // 上传图片到服务器
  Future<List<String>> _uploadImages() async {
    List<String> imageIds = [];
    
    for (File imageFile in _selectedImages) {
      try {
        await _initializeBaseUrl();
        
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/upload-image/'),
        );
        
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
        
        var response = await request.send();
        var responseData = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseData);
        
        if (jsonResponse['success'] == true) {
          imageIds.add(jsonResponse['data']['image_id']);
          print('图片上传成功: ${jsonResponse['data']['image_id']}');
        } else {
          print('图片上传失败: ${jsonResponse['error']}');
        }
      } catch (e) {
        print('图片上传异常: $e');
      }
    }
    
    return imageIds;
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
            child: GestureDetector(
              onTap: () {
                // 点击空白区域时收起键盘
                _focusNode.unfocus();
              },
              child: ListView.builder(
                controller: _scrollController,
                reverse: true, // 消息列表反转，最新的消息在最下面
                padding: const EdgeInsets.all(16.0),
                itemCount: _messages.length + (_isLoading ? 1 : 0) + (_isLoadingHistory ? 1 : 0),
                itemBuilder: (_, int index) {
                // 历史消息加载指示器（在列表顶部）
                if (_isLoadingHistory && index == _messages.length + (_isLoading ? 1 : 0)) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Center(
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '加载历史消息...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                // 当前消息加载指示器
                if (_isLoading && index == 0) {
                  // 显示加载指示器
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      children: [
                        const SizedBox(width: 8.0),
                        Flexible(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width > 600 
                                  ? MediaQuery.of(context).size.width * 0.7  // 大屏幕使用70%
                                  : MediaQuery.of(context).size.width * 0.85, // 小屏幕使用85%
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
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
                        ),
                      ],
                    ),
                  );
                }
                // 显示实际消息
                int messageIndex = index - (_isLoading ? 1 : 0);
                return _messages[messageIndex];
              },
            ),
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

// 单条聊天消息的 Widget
class ChatMessage extends StatelessWidget {
  final String text;
  final String sender;
  final bool isArticle; // 标记是否是文章内容
  final String? messageId; // 消息唯一标识
  final List<File>? images; // 消息包含的图片

  const ChatMessage({
    super.key, 
    required this.text, 
    required this.sender,
    this.isArticle = false,
    this.messageId,
    this.images,
  });

  @override
  Widget build(BuildContext context) {
    bool isUser = sender == 'user';
    
    return Container(
      key: messageId != null ? ValueKey(messageId) : null,
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          // 消息气泡
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width > 600 
                    ? MediaQuery.of(context).size.width * 0.7  // 大屏幕使用70%
                    : MediaQuery.of(context).size.width * 0.85, // 小屏幕使用85%
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
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
                  // 显示图片（如果有）
                  if (images != null && images!.isNotEmpty) ...[
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: images!.map((image) {
                        return Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              image,
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (text.isNotEmpty) const SizedBox(height: 8),
                  ],
                  
                  // 根据发送者类型决定是否使用markdown解析
                  if (text.isNotEmpty) ...[
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
