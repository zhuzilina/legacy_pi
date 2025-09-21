import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../models/content_item.dart';
import '../widgets/rich_content_widget.dart';
import '../services/unified_cache_service.dart';
import '../services/tts_service.dart';
import '../l10n/app_localizations.dart';

/// 全文内容显示对话框
/// 通用的全文显示组件，支持富文本内容、图片和自定义样式
class FullContentDialog extends StatefulWidget {
  final Article article;
  final UnifiedCacheService cacheService;
  final VoidCallback? onClose;
  final double? dialogWidth;
  final double? dialogHeight;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? barrierColor;
  final bool showTitle;
  final String? customTitle;
  final EdgeInsetsGeometry? contentPadding;
  final bool enableContentSelection;
  final double? borderRadius;
  final bool enableTts; // 新增：是否启用TTS功能
  final bool autoPlay; // 新增：是否自动播放TTS

  // 持久化自动播放设置
  static const String _autoPlayKey = 'tts_auto_play_enabled';
  static const String _selectedVoiceKey = 'tts_selected_voice';

  const FullContentDialog({
    super.key,
    required this.article,
    required this.cacheService,
    this.onClose,
    this.dialogWidth,
    this.dialogHeight,
    this.backgroundColor,
    this.textColor,
    this.barrierColor,
    this.showTitle = true,
    this.customTitle,
    this.contentPadding,
    this.enableContentSelection = true,
    this.borderRadius,
    this.enableTts = true, // 默认启用TTS
    this.autoPlay = false, // 默认不自动播放
  });

  @override
  State<FullContentDialog> createState() => _FullContentDialogState();

  /// 获取自动播放设置
  static Future<bool> getAutoPlaySetting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoPlayKey) ?? false;
  }

  /// 获取选择的音色设置
  static Future<String> getSelectedVoiceSetting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedVoiceKey) ?? 'zh-CN-XiaoxiaoNeural';
  }

  /// 显示全文内容对话框的便捷方法
  static Future<T?> show<T>({
    required BuildContext context,
    required Article article,
    required UnifiedCacheService cacheService,
    VoidCallback? onClose,
    double? dialogWidth,
    double? dialogHeight,
    Color? backgroundColor,
    Color? textColor,
    Color? barrierColor,
    bool showTitle = true,
    String? customTitle,
    EdgeInsetsGeometry? contentPadding,
    bool enableContentSelection = true,
    double? borderRadius,
    bool enableTts = true,
    bool autoPlay = false,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierColor: barrierColor ?? Colors.black54,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: FullContentDialog(
                article: article,
                cacheService: cacheService,
                onClose: onClose,
                dialogWidth: dialogWidth,
                dialogHeight: dialogHeight,
                backgroundColor: backgroundColor,
                textColor: textColor,
                barrierColor: barrierColor,
                showTitle: showTitle,
                customTitle: customTitle,
                contentPadding: contentPadding,
                enableContentSelection: enableContentSelection,
                borderRadius: borderRadius,
                enableTts: enableTts,
                autoPlay: autoPlay,
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
}

class _FullContentDialogState extends State<FullContentDialog> with TickerProviderStateMixin {
  // TTS 相关状态
  bool _isAudioLoading = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  String _currentTime = '00:00';
  bool _autoPlay = false;
  String _selectedVoice = 'zh-CN-XiaoxiaoNeural';
  String? _errorMessage;
  bool _hasError = false;
  bool _isDisposed = false;

  // TTS 服务
  final TtsService _ttsService = TtsService();

  // 状态管理定时器
  Timer? _statusCheckTimer;

  // 保存自动播放设置
  Future<void> _saveAutoPlaySetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(FullContentDialog._autoPlayKey, value);
  }

  // 获取自动播放设置
  Future<bool> _getAutoPlaySetting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(FullContentDialog._autoPlayKey) ?? false;
  }

  // 保存音色设置
  Future<void> _saveSelectedVoiceSetting(String voice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(FullContentDialog._selectedVoiceKey, voice);
  }

  // 获取音色设置
  Future<String> _getSelectedVoiceSetting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(FullContentDialog._selectedVoiceKey) ?? 'zh-CN-XiaoxiaoNeural';
  }

  // 滚动检测相关状态
  final ScrollController _scrollController = ScrollController();
  bool _showAudioPlayer = true;
  double _lastScrollOffset = 0.0;
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    // 从持久化存储加载设置
    _loadSettings();

    // 如果启用TTS，初始化音频加载
    if (widget.enableTts) {
      _initializeTts();
      // 如果启用自动播放，延迟一段时间后开始播放
      if (widget.autoPlay) {
        _autoStartPlayback();
      }
    }

    // 添加滚动监听器
    _scrollController.addListener(_handleScroll);
  }

  // 加载所有设置
  Future<void> _loadSettings() async {
    final autoPlaySetting = await _getAutoPlaySetting();
    final voiceSetting = await _getSelectedVoiceSetting();
    if (!_isDisposed) {
      setState(() {
        _autoPlay = autoPlaySetting;
        _selectedVoice = voiceSetting;
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _statusCheckTimer?.cancel();
    _scrollTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  // 处理滚动事件
  void _handleScroll() {
    if (!_isDisposed) {
      final currentOffset = _scrollController.offset;
      final scrollDelta = currentOffset - _lastScrollOffset;

      // 取消之前的定时器
      _scrollTimer?.cancel();

      // 立即响应，减少延迟
      _scrollTimer = Timer(const Duration(milliseconds: 30), () {
        if (!_isDisposed) {
          setState(() {
            // 向下滚动，隐藏播放器 - 降低阈值，提高灵敏度
            if (scrollDelta > 1) {
              _showAudioPlayer = false;
            }
            // 向上滚动，显示播放器 - 降低阈值，提高灵敏度
            else if (scrollDelta < -1) {
              _showAudioPlayer = true;
            }
          });
        }
      });

      _lastScrollOffset = currentOffset;
    }
  }

  
  // 自动开始播放
  void _autoStartPlayback() {
    // 延迟1秒开始播放，确保对话框完全显示
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!_isDisposed && widget.enableTts && widget.autoPlay) {
        _startTtsPlayback();
      }
    });
  }

  // 初始化TTS
  Future<void> _initializeTts() async {
    if (_isDisposed) return;

    try {
      // 准备TTS文本
      final ttsText = '${widget.article.title}\n\n${widget.article.content}';
      final cleanedText = Article.cleanMarkdownForTts(ttsText);

      // 检查是否有缓存的音频数据
      final cachedAudioData = widget.cacheService.getAudioCache(cleanedText, _selectedVoice);
      if (cachedAudioData != null) {
        if (kDebugMode) {
          print('发现缓存的音频数据，大小: ${cachedAudioData.length} 字节');
        }
        // 缓存存在，不自动加载，等待用户手动播放
        return;
      }
    } catch (e) {
      if (!_isDisposed) {
        _showErrorSnackbar('初始化失败: ${e.toString()}');
      }
    }
  }

  // 开始TTS播放
  Future<void> _startTtsPlayback() async {
    if (!widget.enableTts || _isDisposed) return;

    _clearError();

    try {
      final ttsText = '${widget.article.title}\n\n${widget.article.content}';
      final cleanedText = Article.cleanMarkdownForTts(ttsText);

      // 检查是否有缓存的音频数据
      final cachedAudioData = widget.cacheService.getAudioCache(cleanedText, _selectedVoice);

      if (cachedAudioData != null) {
        if (kDebugMode) {
          print('使用缓存的音频数据，大小: ${cachedAudioData.length} 字节');
        }
        await _startTtsPlaybackWithCache(cachedAudioData);
        return;
      }

      // 没有缓存，开始TTS请求
      _setLoadingState(true);

      final result = await _ttsService.streamTtsAndPlay(
        text: cleanedText,
        voice: _selectedVoice,
        language: 'zh-CN',
        autoPlay: true,
        onTimeUpdate: (time) {
          if (!_isDisposed) {
            setState(() {
              try {
                _currentTime = time.trim();
              } catch (e) {
                _currentTime = '00:00';
              }
            });
          }
        },
        onComplete: () {
          if (!_isDisposed) {
            setState(() {
              _isPlaying = false;
              _isPaused = false;
              _isAudioLoading = false;
            });
          }
        },
        onError: (error) {
          if (!_isDisposed) {
            setState(() {
              _isAudioLoading = false;
              _isPlaying = false;
              _isPaused = false;
            });
            _showErrorSnackbar('播放失败: $error');
          }
        },
      );

      if (!_isDisposed) {
        if (result['success'] == true) {
          // 缓存音频数据
          if (result['audioData'] != null) {
            widget.cacheService.setAudioCache(cleanedText, _selectedVoice, result['audioData'] as Uint8List);
          }

          setState(() {
            _isAudioLoading = false;
            _isPlaying = true;
            _isPaused = false;
          });
        } else {
          setState(() {
            _isAudioLoading = false;
          });
          _showErrorSnackbar('音频生成失败');
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          _isAudioLoading = false;
        });
        _showErrorSnackbar('播放失败: ${e.toString()}');
      }
    }
  }

  // 使用缓存的音频数据开始播放
  Future<void> _startTtsPlaybackWithCache(Uint8List audioData) async {
    if (_isDisposed) return;

    try {
      setState(() {
        _isAudioLoading = false;
        _isPlaying = true;
        _isPaused = false;
        _currentTime = '00:00';
      });

      final result = await _ttsService.streamTtsAndPlay(
        text: '',
        voice: _selectedVoice,
        language: 'zh-CN',
        autoPlay: true,
        onTimeUpdate: (time) {
          if (!_isDisposed) {
            setState(() {
              try {
                _currentTime = time.trim();
              } catch (e) {
                _currentTime = '00:00';
              }
            });
          }
        },
        onComplete: () {
          if (!_isDisposed) {
            setState(() {
              _isPlaying = false;
              _isPaused = false;
              _isAudioLoading = false;
            });
          }
        },
        onError: (error) {
          if (!_isDisposed) {
            setState(() {
              _isAudioLoading = false;
              _isPlaying = false;
              _isPaused = false;
            });
            _showErrorSnackbar('缓存播放失败: $error');
          }
        },
        cachedAudioData: audioData,
      );

      if (!_isDisposed && result['success'] != true) {
        setState(() {
          _isPlaying = false;
          _isAudioLoading = false;
        });
        _showErrorSnackbar('缓存播放失败');
      }
    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          _isPlaying = false;
          _isAudioLoading = false;
        });
        _showErrorSnackbar('缓存播放失败: ${e.toString()}');
      }
    }
  }

  // 停止TTS播放
  Future<void> _stopTtsPlayback() async {
    if (_isDisposed) return;

    try {
      await _ttsService.pause();
      if (!_isDisposed) {
        setState(() {
          _isPlaying = false;
          _isPaused = true;
        });
      }
    } catch (e) {
      if (!_isDisposed) {
        _showErrorSnackbar('暂停失败: ${e.toString()}');
      }
    }
  }

  // 快进
  Future<void> _fastForward() async {
    if (_isDisposed) return;

    try {
      if (_isPlaying || _isPaused) {
        await _ttsService.seekToRelative(10);

        if (_isPaused) {
          await _ttsService.resume();
          if (!_isDisposed) {
            setState(() {
              _isPlaying = true;
              _isPaused = false;
            });
          }
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        _showErrorSnackbar('快进失败: ${e.toString()}');
      }
    }
  }

  // 快退
  Future<void> _fastRewind() async {
    if (_isDisposed) return;

    try {
      if (_isPlaying || _isPaused) {
        await _ttsService.seekToRelative(-10);

        if (_isPaused) {
          await _ttsService.resume();
          if (!_isDisposed) {
            setState(() {
              _isPlaying = true;
              _isPaused = false;
            });
          }
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        _showErrorSnackbar('快退失败: ${e.toString()}');
      }
    }
  }

  // 显示音频选项抽屉
  void _showAudioOptionsDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 自动播放开关
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    color: Colors.red[700],
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '自动播放',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '下次打开文章时自动播放',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoPlay,
                    onChanged: (bool value) async {
                      // 保存设置到持久化存储
                      await _saveAutoPlaySetting(value);

                      // 更新主widget状态
                      this.setState(() {
                        _autoPlay = value;
                      });
                      // 更新抽屉内状态
                      setState(() {
                        _autoPlay = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            // 音色选择
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.record_voice_over,
                    color: Colors.red[700],
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '音色选择',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '选择TTS语音的音色',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedVoice,
                      underline: Container(),
                      items: [
                        DropdownMenuItem(
                          value: 'zh-CN-XiaoxiaoNeural',
                          child: Text('晓晓 (女声)', style: TextStyle(fontSize: 14)),
                        ),
                        DropdownMenuItem(
                          value: 'zh-CN-YunxiNeural',
                          child: Text('云希 (男声)', style: TextStyle(fontSize: 14)),
                        ),
                        DropdownMenuItem(
                          value: 'zh-CN-YunyangNeural',
                          child: Text('云扬 (男声)', style: TextStyle(fontSize: 14)),
                        ),
                        DropdownMenuItem(
                          value: 'zh-CN-XiaoyiNeural',
                          child: Text('晓伊 (女声)', style: TextStyle(fontSize: 14)),
                        ),
                        DropdownMenuItem(
                          value: 'zh-CN-YunjianNeural',
                          child: Text('云健 (男声)', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                      onChanged: (String? newValue) async {
                        if (newValue != null && newValue != _selectedVoice) {
                          // 保存音色设置到持久化存储
                          await _saveSelectedVoiceSetting(newValue);

                          // 更新主widget状态
                          this.setState(() {
                            _selectedVoice = newValue;
                          });
                          // 更新抽屉内状态
                          setState(() {
                            _selectedVoice = newValue;
                          });

                          // 如果当前正在播放或暂停，停止播放并清除缓存
                          if (_isPlaying || _isPaused) {
                            _ttsService.stop();
                            this.setState(() {
                              _isPlaying = false;
                              _isPaused = false;
                              _currentTime = '00:00';
                            });

                            // 清除文本缓存，确保使用新音色
                            final ttsText = '${widget.article.title}\n\n${widget.article.content}';
                            final cleanedText = Article.cleanMarkdownForTts(ttsText);
                            widget.cacheService.clearTextCache(cleanedText);
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = widget.backgroundColor ?? Colors.white;
    final effectiveTextColor = widget.textColor ?? Colors.black87;
    final effectiveBarrierColor = widget.barrierColor ?? Colors.black54;
    final effectiveBorderRadius = widget.borderRadius ?? 16.0;
    final effectiveContentPadding = widget.contentPadding ?? const EdgeInsets.all(20);

    return Material(
      type: MaterialType.transparency,
      child: DeferredPointerHandler(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: effectiveBarrierColor,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 主对话框容器
                Container(
                  width: widget.dialogWidth ?? MediaQuery.of(context).size.width * 0.9,
                  height: widget.dialogHeight ?? MediaQuery.of(context).size.height * 0.72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(effectiveBorderRadius),
                    color: effectiveBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(effectiveBorderRadius),
                    child: Column(
                      children: [
                        // 内容区域
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: effectiveContentPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 文章标题
                                if (widget.showTitle) ...[
                                  Text(
                                    widget.customTitle ?? widget.article.title,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: effectiveTextColor,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // 内容标题
                                Text(
                                  AppLocalizations.of(context)!.articleContent,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: effectiveTextColor,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // 使用RichContentWidget显示内容
                                FutureBuilder<List<ContentItem>>(
                                  future: widget.article.parseContentItems(cacheService: widget.cacheService),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return RichContentWidget(
                                        contentItems: snapshot.data!,
                                        textStyle: TextStyle(
                                          fontSize: 16,
                                          height: 1.6,
                                          color: effectiveTextColor,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        textColor: effectiveTextColor,
                                        enableScrolling: false,
                                        article: widget.article,
                                        contextText: widget.article.content,
                                        cacheService: widget.cacheService,
                                      );
                                    } else if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          '加载内容失败',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: effectiveTextColor.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      );
                                    } else {
                                      return Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            effectiveTextColor.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                SizedBox(height: widget.enableTts ? (_hasError ? 140 : (_showAudioPlayer ? 100 : 20)) : 20),
                              ],
                            ),
                          ),
                        ),

                        // TTS音频播放器 - 带动画效果
                        if (widget.enableTts) ...[
                          _buildAnimatedAudioPlayer(),
                          if (_hasError) _buildErrorMessage(),
                        ],
                      ],
                    ),
                  ),
                ),

                // 底部悬浮关闭按钮
                Positioned(
                  bottom: -67,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: DeferPointer(
                      child: GestureDetector(
                        onTap: () {
                          // 先调用回调函数
                          widget.onClose?.call();
                          // 然后关闭对话框
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: effectiveBackgroundColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close,
                            color: effectiveTextColor.withValues(alpha: 0.6),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建音频播放器覆盖层
  Widget _buildAudioPlayerOverlay() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 中心主体：播放控制按钮
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 快退按钮
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isAudioLoading ? null : () {
                      _fastRewind();
                    },
                    icon: Icon(
                      Icons.fast_rewind,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // 播放按钮（中心）
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isAudioLoading ? Colors.grey[400] : Colors.red[700],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isAudioLoading ? null : () {
                      if (_isPlaying) {
                        _stopTtsPlayback();
                      } else if (_isPaused) {
                        _ttsService.resume();
                        setState(() {
                          _isPlaying = true;
                          _isPaused = false;
                        });
                      } else {
                        _startTtsPlayback();
                      }
                    },
                    icon: _isAudioLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            _isPlaying
                                ? Icons.pause
                                : _isPaused
                                    ? Icons.play_arrow
                                    : Icons.play_arrow,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 20),
                // 快进按钮
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isAudioLoading ? null : () {
                      _fastForward();
                    },
                    icon: Icon(
                      Icons.fast_forward,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 左上角：播放时间
          Positioned(
            left: 20,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _currentTime,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // 右上角：更多按钮
          if (widget.enableTts)
            Positioned(
              right: 20,
              top: 12,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    _showAudioOptionsDrawer(context);
                  },
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.grey[600],
                    size: 16,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 构建错误消息
  Widget _buildErrorMessage() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[700],
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? '发生错误',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _clearError,
            child: Icon(
              Icons.close,
              color: Colors.red[700],
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  // 设置加载状态
  void _setLoadingState(bool loading) {
    if (!_isDisposed) {
      setState(() {
        _isAudioLoading = loading;
        _isPlaying = false;
        _isPaused = false;
        _currentTime = '00:00';
      });
    }
  }

  // 显示错误消息
  void _showErrorSnackbar(String message) {
    if (_isDisposed) return;

    setState(() {
      _hasError = true;
      _errorMessage = message;
    });

    // 3秒后自动清除错误
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isDisposed) {
        _clearError();
      }
    });
  }

  // 清除错误状态
  void _clearError() {
    if (!_isDisposed) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
    }
  }

  // 构建带动画效果的音频播放器
  Widget _buildAnimatedAudioPlayer() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150), // 加快动画速度
      curve: Curves.easeOut, // 使用更快的曲线
      height: _showAudioPlayer ? 90 : 0,
      child: _showAudioPlayer
          ? _buildAudioPlayerOverlay()
          : const SizedBox.shrink(),
    );
  }
}

/// 全文内容显示器的配置类
class FullContentDialogConfig {
  final double? dialogWidth;
  final double? dialogHeight;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? barrierColor;
  final bool showTitle;
  final String? customTitle;
  final EdgeInsetsGeometry? contentPadding;
  final bool enableContentSelection;
  final double? borderRadius;
  final bool enableTts;
  final bool autoPlay;

  const FullContentDialogConfig({
    this.dialogWidth,
    this.dialogHeight,
    this.backgroundColor,
    this.textColor,
    this.barrierColor,
    this.showTitle = true,
    this.customTitle,
    this.contentPadding,
    this.enableContentSelection = true,
    this.borderRadius,
    this.enableTts = true,
    this.autoPlay = false,
  });

  /// 创建默认配置
  factory FullContentDialogConfig.defaultConfig() {
    return const FullContentDialogConfig();
  }

  /// 创建移动端优化的配置
  factory FullContentDialogConfig.mobileConfig() {
    return const FullContentDialogConfig(
      dialogWidth: double.infinity,
      dialogHeight: double.infinity,
      borderRadius: 0,
      contentPadding: EdgeInsets.all(16),
      enableTts: true,
    );
  }

  /// 创建平板端优化的配置
  factory FullContentDialogConfig.tabletConfig() {
    return const FullContentDialogConfig(
      dialogWidth: 600,
      dialogHeight: 500,
      borderRadius: 12,
      enableTts: true,
    );
  }
}

/// 全文内容显示器的便捷工具类
class FullContentDialogHelper {
  /// 使用默认配置显示全文对话框
  static Future<T?> showWithDefaultConfig<T>({
    required BuildContext context,
    required Article article,
    required UnifiedCacheService cacheService,
    VoidCallback? onClose,
    FullContentDialogConfig? config,
  }) {
    final effectiveConfig = config ?? FullContentDialogConfig.defaultConfig();

    return FullContentDialog.show(
      context: context,
      article: article,
      cacheService: cacheService,
      onClose: onClose,
      dialogWidth: effectiveConfig.dialogWidth,
      dialogHeight: effectiveConfig.dialogHeight,
      backgroundColor: effectiveConfig.backgroundColor,
      textColor: effectiveConfig.textColor,
      barrierColor: effectiveConfig.barrierColor,
      showTitle: effectiveConfig.showTitle,
      customTitle: effectiveConfig.customTitle,
      contentPadding: effectiveConfig.contentPadding,
      enableContentSelection: effectiveConfig.enableContentSelection,
      borderRadius: effectiveConfig.borderRadius,
      enableTts: effectiveConfig.enableTts,
      autoPlay: effectiveConfig.autoPlay,
    );
  }

  /// 显示移动端优化的全文对话框
  static Future<T?> showMobileOptimized<T>({
    required BuildContext context,
    required Article article,
    required UnifiedCacheService cacheService,
    VoidCallback? onClose,
  }) {
    return showWithDefaultConfig(
      context: context,
      article: article,
      cacheService: cacheService,
      onClose: onClose,
      config: FullContentDialogConfig.mobileConfig(),
    );
  }

  /// 显示平板端优化的全文对话框
  static Future<T?> showTabletOptimized<T>({
    required BuildContext context,
    required Article article,
    required UnifiedCacheService cacheService,
    VoidCallback? onClose,
  }) {
    return showWithDefaultConfig(
      context: context,
      article: article,
      cacheService: cacheService,
      onClose: onClose,
      config: FullContentDialogConfig.tabletConfig(),
    );
  }
}