import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:legacy_pi/models/article.dart';
import 'package:legacy_pi/services/ai_service.dart';

import 'package:legacy_pi/services/tts_service.dart';
import 'package:legacy_pi/services/unified_cache_service.dart';
import '../pages/chat_page.dart';

/// AI解读对话框Widget
class AiInterpretationDialog extends StatefulWidget {
  final Article article;
  final AiService aiService;
  final UnifiedCacheService cacheService;
  final String promptType; // 新增：提示词类型

  const AiInterpretationDialog({
    required this.article,
    required this.aiService,
    required this.cacheService,
    this.promptType = 'summary', // 默认为summary
  });

  @override
  State<AiInterpretationDialog> createState() => _AiInterpretationDialogState();
}

class _AiInterpretationDialogState extends State<AiInterpretationDialog> with TickerProviderStateMixin {
  bool _isLoading = true;
  String _aiInterpretation = '';
  String? _errorMessage;
  bool _autoPlay = false; // 自动播放开关状态
  String _selectedVoice = 'zh-CN-XiaoxiaoNeural'; // 当前选择的音色
  bool _isAudioLoading = false; // 音频加载状态
  bool _isPlaying = false; // 音频播放状态
  bool _isPaused = false; // 新增：是否处于暂停状态
  String _currentTime = '00:00'; // 当前播放时间
  final TtsService _ttsService = TtsService();
  


  @override
  void initState() {
    super.initState();
    _loadAiInterpretation();
  }

  Future<void> _loadAiInterpretation() async {
    try {
      // 合并标题和正文内容
      final combinedText = '${widget.article.title}\n\n${widget.article.content}';
      
      // 检查文本长度，如果太长则截断
      final maxTextLength = 8000; // 设置合理的最大长度
      final truncatedText = combinedText.length > maxTextLength 
          ? '${combinedText.substring(0, maxTextLength)}...'
          : combinedText;
      
      print('发送给AI的文本长度: ${truncatedText.length}');
      
      // 检查是否有完整的缓存（AI解读 + 音频）
      if (widget.cacheService.hasCompleteCache(truncatedText, widget.promptType, _selectedVoice, null)) {
        print('发现完整缓存，直接加载');
        final cachedData = widget.cacheService.getCompleteCache(truncatedText, widget.promptType, _selectedVoice, null);
        if (cachedData != null) {
          setState(() {
            _aiInterpretation = cachedData['aiResponse'].data.interpretation;
            _isLoading = false;
          });
          
          // 直接开始TTS播放，使用缓存数据
          _startTtsPlaybackWithCache(cachedData['audioData']);
          return;
        }
      }
      
      // 显示缓存状态
      final cacheStats = widget.cacheService.getCacheStats();
      print('当前缓存状态: ${cacheStats['aiCacheSize']}/${cacheStats['maxAiCacheSize']}');
      
      final response = await widget.aiService.interpretText(
        text: truncatedText,
        promptType: widget.promptType, // 使用传入的提示词类型
        maxTokens: 2000, // 增加token数量
      );

      if (response != null && response.success && response.data != null) {
        print('AI解读成功 - 结果长度: ${response.data!.interpretation.length}');
        setState(() {
          _aiInterpretation = response.data!.interpretation;
          _isLoading = false;
        });
        
        // AI解读完成后，自动开始TTS加载
        _startTtsLoading();
      } else {
        print('AI解读失败 - 错误: ${response?.error}');
        setState(() {
          _errorMessage = response?.error ?? 'AI解读失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '请求异常: $e';
        _isLoading = false;
      });
    }
  }
  
  // 使用缓存的音频数据开始播放
  Future<void> _startTtsPlaybackWithCache(Uint8List audioData) async {
    try {
      // 确保播放状态正确设置
      setState(() {
        _isAudioLoading = false;
        _isPlaying = true;
        _isPaused = false;
        _currentTime = '00:00';
      });
      
      if (kDebugMode) {
        print('开始播放缓存音频，播放状态: $_isPlaying');
      }
      
      // 直接使用缓存的音频数据播放
      final result = await _ttsService.streamTtsAndPlay(
        text: '', // 不需要文本，直接使用音频数据
        voice: _selectedVoice,
        language: 'zh-CN',
        autoPlay: true, // 缓存播放时总是播放
        onTimeUpdate: (time) {
          setState(() {
            try {
              _currentTime = time.trim();
              if (kDebugMode) {
                print('TTS时间更新: $_currentTime');
              }
            } catch (e) {
              if (kDebugMode) {
                print('时间解析错误: $e');
              }
              _currentTime = '00:00';
            }
          });
        },
        onComplete: () {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('缓存音频播放完成');
          }
        },
        onError: (error) {
          setState(() {
            _isAudioLoading = false;
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('缓存音频播放错误: $error');
          }
        },
        cachedAudioData: audioData,
      );
      
      if (result['success'] == true) {
        if (kDebugMode) {
          print('使用缓存音频播放成功');
        }
        // 确保播放状态保持为true
        if (_autoPlay) {
          setState(() {
            _isPlaying = true;
          });
          if (kDebugMode) {
            print('自动播放模式，确保播放状态为true: $_isPlaying');
          }
        }
      } else {
        if (kDebugMode) {
          print('使用缓存音频播放失败: ${result['error']}');
        }
        setState(() {
          _isPlaying = false;
          _isAudioLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('使用缓存音频播放异常: $e');
      }
      setState(() {
        _isPlaying = false;
        _isAudioLoading = false;
      });
    }
  }

  // 加载缓存音频但不播放（用于自动播放关闭时）
  Future<void> _loadCachedAudioWithoutPlayback(Uint8List audioData) async {
    try {
      if (kDebugMode) {
        print('加载缓存音频但不播放，音频大小: ${audioData.length} 字节');
      }
      
      setState(() {
        _isAudioLoading = false;
        _isPlaying = false;
        _isPaused = false;
        _currentTime = '00:00';
      });
      
      if (kDebugMode) {
        print('缓存音频加载完成，等待用户手动播放');
      }
    } catch (e) {
      if (kDebugMode) {
        print('加载缓存音频异常: $e');
      }
      setState(() {
        _isAudioLoading = false;
      });
    }
  }

  // 开始TTS加载（根据自动播放设置决定是否播放）
  Future<void> _startTtsLoading() async {
    if (_aiInterpretation.isEmpty) return;
    
    try {
      // 清理Markdown格式，准备TTS
      final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
      
      // 首先检查是否有缓存的音频数据
      final cachedAudioData = widget.cacheService.getAudioCache(cleanedText, _selectedVoice);
      if (cachedAudioData != null) {
        if (kDebugMode) {
          print('发现缓存的音频数据，大小: ${cachedAudioData.length} 字节');
        }
        
        setState(() {
          _isAudioLoading = false;
        });
        
        // 根据自动播放设置决定是否播放
        if (_autoPlay) {
          if (kDebugMode) {
            print('自动播放已开启，使用缓存音频开始播放');
          }
          
          // 使用缓存的音频数据播放
          await _startTtsPlaybackWithCache(cachedAudioData);
        } else {
          if (kDebugMode) {
            print('自动播放已关闭，缓存音频加载完成但不播放');
          }
          
          // 加载缓存音频但不播放
          await _loadCachedAudioWithoutPlayback(cachedAudioData);
        }
        return; // 有缓存，直接返回
      }
      
      // 没有缓存，开始TTS请求
      if (kDebugMode) {
        print('没有缓存音频数据，开始TTS请求');
      }
      
      setState(() {
        _isAudioLoading = true;
        _isPlaying = false;
        _isPaused = false;
        _currentTime = '00:00';
      });
      
      // 获取TTS音频数据
      final result = await _ttsService.streamTtsAndPlay(
        text: cleanedText,
        voice: _selectedVoice,
        language: 'zh-CN',
        autoPlay: _autoPlay, // 传递自动播放设置
        onTimeUpdate: (time) {
          setState(() {
            try {
              _currentTime = time.trim();
              if (kDebugMode) {
                print('TTS时间更新: $_currentTime');
              }
            } catch (e) {
              if (kDebugMode) {
                print('时间解析错误: $e');
              }
              _currentTime = '00:00';
            }
          });
        },
        onComplete: () {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('TTS播放完成');
          }
        },
        onError: (error) {
          setState(() {
            _isAudioLoading = false;
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('TTS播放错误: $error');
          }
        },
      );
      
      if (result['success'] == true) {
        // 缓存音频数据
        if (result['audioData'] != null) {
          widget.cacheService.setAudioCache(cleanedText, _selectedVoice, result['audioData'] as Uint8List);
          if (kDebugMode) {
            print('音频数据已缓存，大小: ${(result['audioData'] as Uint8List).length} 字节');
          }
        }
        
        setState(() {
          _isAudioLoading = false;
        });
        
        // 根据自动播放设置决定是否播放
        if (_autoPlay) {
          setState(() {
            _isPlaying = true;
          });
          if (kDebugMode) {
            print('自动播放已开启，开始播放音频');
          }
        } else {
          if (kDebugMode) {
            print('自动播放已关闭，音频加载完成但不播放');
          }
        }
      } else {
        setState(() {
          _isAudioLoading = false;
        });
        if (kDebugMode) {
          print('TTS加载失败: ${result['error']}');
        }
      }
    } catch (e) {
      setState(() {
        _isAudioLoading = false;
      });
      if (kDebugMode) {
        print('TTS加载异常: $e');
      }
    }
  }
  
  // 开始TTS音频播放
  Future<void> _startTtsPlayback() async {
    if (_aiInterpretation.isEmpty) return;
    
    // 检查是否有缓存的音频数据
    final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
    final cachedAudioData = widget.cacheService.getAudioCache(cleanedText, _selectedVoice);
    
    if (cachedAudioData != null) {
      if (kDebugMode) {
        print('使用缓存的音频数据，大小: ${cachedAudioData.length} 字节');
      }
      
      // 使用缓存的音频数据播放
      await _startTtsPlaybackWithCache(cachedAudioData);
      return;
    }
    
    // 没有缓存，开始TTS请求
    setState(() {
      _isAudioLoading = true;
      _isPlaying = false;
      _isPaused = false;
      _currentTime = '00:00';
    });
    

    
    try {
      // 清理Markdown格式，准备TTS播放
      final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
      
      // 使用新的TTS播放方法
      final result = await _ttsService.streamTtsAndPlay(
        text: cleanedText,
        voice: _selectedVoice,
        language: 'zh-CN',
        onTimeUpdate: (time) {
          setState(() {
            try {
              _currentTime = time.trim();
              if (kDebugMode) {
                print('时间更新: $_currentTime');
              }
            } catch (e) {
              if (kDebugMode) {
                print('时间解析错误: $e');
              }
              _currentTime = '00:00';
            }
          });
        },
        onComplete: () {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('TTS音频播放完成');
          }
        },
        onError: (error) {
          setState(() {
            _isAudioLoading = false;
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('TTS播放错误: $error');
          }
        },
      );
      
      if (result['success'] == true) {
        // 缓存音频数据
        if (result['audioData'] != null) {
          widget.cacheService.setAudioCache(cleanedText, _selectedVoice, result['audioData'] as Uint8List);
          if (kDebugMode) {
            print('音频数据已缓存，大小: ${(result['audioData'] as Uint8List).length} 字节');
          }
        }
        
        setState(() {
          _isAudioLoading = false;
          _isPlaying = true;
        });
        
        if (kDebugMode) {
          print('TTS播放开始成功');
        }
      } else {
        setState(() {
          _isAudioLoading = false;
          _isPlaying = false;
        });
        
        if (kDebugMode) {
          print('TTS播放开始失败: ${result['error']}');
        }
      }
    } catch (e) {
      setState(() {
        _isAudioLoading = false;
        _isPlaying = false;
      });
      
      if (kDebugMode) {
        print('TTS播放异常: $e');
      }
    }
  }
  
  // 暂停音频播放
  void _stopTtsPlayback() {
    if (_isPlaying) {
      _ttsService.pause(); // 暂停而不是停止
      setState(() {
        _isPlaying = false;
        _isPaused = true; // 标记为暂停状态
      });
      if (kDebugMode) {
        print('音频已暂停');
      }
    }
  }

  // 快退播放
  void _fastRewind() async {
    try {
      if (_isPlaying || _isPaused) {
        await _ttsService.seekToRelative(-10); // 快退10秒
        if (kDebugMode) {
          print('快退10秒');
        }
        
        // 如果当前是暂停状态，快退后保持暂停
        // 如果当前是播放状态，快退后继续播放
        if (_isPaused) {
          // 快退后恢复播放
          await _ttsService.resume();
          setState(() {
            _isPlaying = true;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('快退后恢复播放');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('快退失败: $e');
      }
      // 快退失败时，尝试恢复播放状态
      if (_isPaused) {
        try {
          await _ttsService.resume();
          setState(() {
            _isPlaying = true;
            _isPaused = false;
          });
        } catch (resumeError) {
          if (kDebugMode) {
            print('快退失败后恢复播放也失败: $resumeError');
          }
        }
      }
    }
  }

  // 快进播放
  void _fastForward() async {
    try {
      if (_isPlaying || _isPaused) {
        await _ttsService.seekToRelative(10); // 快进10秒
        if (kDebugMode) {
          print('快进10秒');
        }
        
        // 如果当前是暂停状态，快进后保持暂停
        // 如果当前是播放状态，快进后继续播放
        if (_isPaused) {
          // 快进后恢复播放
          await _ttsService.resume();
          setState(() {
            _isPlaying = true;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('快进后恢复播放');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('快进失败: $e');
      }
      // 快进失败时，尝试恢复播放状态
      if (_isPaused) {
        try {
          await _ttsService.resume();
          setState(() {
            _isPlaying = true;
            _isPaused = false;
          });
        } catch (resumeError) {
          if (kDebugMode) {
            print('快进失败后恢复播放也失败: $resumeError');
          }
        }
      }
    }
  }
  

  
  // 显示音频选项抽屉
  void _showAudioOptionsDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
              // 拖拽指示器
                Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                  decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                Text(
                      '音频设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
              ),
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
                            'AI解读完成后自动播放音频',
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
                      onChanged: (bool value) {
                        setState(() {
                          _autoPlay = value;
                        });
                        
                        if (kDebugMode) {
                          print('自动播放开关状态: $_autoPlay');
                        }
                        
                        // 如果开启自动播放且当前有AI解读结果，立即开始播放
                        if (_autoPlay && _aiInterpretation.isNotEmpty && !_isPlaying && !_isPaused) {
                          if (kDebugMode) {
                            print('开启自动播放，开始播放音频');
                          }
                          setState(() {
                            _isPlaying = true;
                          });
                        }
                        // 如果关闭自动播放且当前正在播放，暂停播放
                        else if (!_autoPlay && _isPlaying) {
                          if (kDebugMode) {
                            print('关闭自动播放，暂停播放');
                          }
                          _ttsService.pause();
                          setState(() {
                            _isPlaying = false;
                            _isPaused = true;
                          });
                        }
                      },
                      activeColor: Colors.red[700],
                      activeThumbColor: Colors.white,
                      activeTrackColor: Colors.red[700],
                      inactiveThumbColor: Colors.grey[400],
                      inactiveTrackColor: Colors.grey[300],
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
                        underline: Container(), // 移除默认下划线
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
                            value: 'zh-CN-YunfengNeural',
                            child: Text('云枫 (男声)', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'zh-CN-XiaohanNeural',
                            child: Text('晓涵 (女声)', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'zh-CN-XiaomoNeural',
                            child: Text('晓墨 (女声)', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'zh-CN-XiaoxuanNeural',
                            child: Text('晓萱 (女声)', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'zh-CN-XiaoyanNeural',
                            child: Text('晓颜 (女声)', style: TextStyle(fontSize: 14)),
                          ),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue != null && newValue != _selectedVoice) {
                            setState(() {
                              _selectedVoice = newValue;
                            });
                            
                            if (kDebugMode) {
                              print('音色已更改为: $_selectedVoice');
                            }
                            
                            // 如果当前正在播放，停止播放并清除缓存
                            if (_isPlaying || _isPaused) {
                              _ttsService.stop();
                              setState(() {
                                _isPlaying = false;
                                _isPaused = false;
                                _currentTime = '00:00';
                              });
                              
                              // 清除缓存，因为音色改变了
                              final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
                              widget.cacheService.clearTextCache(cleanedText);
                              
                              if (kDebugMode) {
                                print('音色改变，已停止播放并清除缓存');
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black54,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: _isLoading 
                ? MediaQuery.of(context).size.height * 0.3  // 加载时使用更小高度
                : MediaQuery.of(context).size.height * 0.85, // 加载完成后使用正常高度
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // 对话框头部
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                        child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isLoading ? 'AI解读中' : widget.article.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
                ),
                const Divider(height: 1),
                // 对话框内容
                _isLoading
                    ? _buildLoadingContent()
                    : Expanded(
                        child: _buildAiContent(),
                      ),
                // 音频播放器覆盖层
                if (!_isLoading && _aiInterpretation.isNotEmpty)
                  _buildAudioPlayerOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.2, // 调整为屏幕高度的五分之一
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiContent() {
    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 20),
              Text(
                'AI解读失败',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loadAiInterpretation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Text(
              'AI生成内容，请谨慎对待',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
          // 使用自定义Markdown解析渲染内容，支持"问AI"选项
          ..._parseMarkdownWithAiOption(_aiInterpretation),
        ],
      ),
    );
  }
  
  // 构建音频播放器覆盖层
  Widget _buildAudioPlayerOverlay() {
    return Container(
      height: 90, // 减少高度，使用浮动布局
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                        // 如果当前是暂停状态，直接恢复播放
                        _ttsService.resume();
                        setState(() {
                          _isPlaying = true;
                          _isPaused = false;
                        });
                        if (kDebugMode) {
                          print('音频已恢复播放');
                        }
                      } else {
                        // 如果既不是播放也不是暂停，则开始新播放
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

  /// 解析包含行内加粗格式的文本，并返回一个 TextSpan。
  /// 这是实现富文本效果的核心方法。
  TextSpan _buildTextSpan(String text, {TextStyle? style}) {
    final List<TextSpan> children = [];
    // 使用 '**' 作为分隔符来切分字符串
    final List<String> parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      String part = parts[i];
      if (part.isEmpty) continue; // 忽略因连续分隔符产生的空字符串

      // 根据部分在数组中的索引奇偶性来判断是否为加粗
      // 索引为奇数的部分是被 '**' 包裹的
      final bool isBold = i % 2 != 0;

      children.add(
        TextSpan(
          text: part,
          // 在基础样式上，如果是加粗部分则覆盖 fontWeight
          style: style?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }

    // 返回一个包含所有子部分的父 TextSpan
    return TextSpan(style: style, children: children);
  }

  /// 解析整个 Markdown 字符串，并返回一个 Widget 列表，支持"问AI"选项和跨行选择
  List<Widget> _parseMarkdownWithAiOption(String markdownContent) {
    final List<String> lines = markdownContent.split('\n');

    print('开始解析Markdown，共${lines.length}行'); // 调试输出

    // 构建跨行选择的富文本内容
    final List<TextSpan> textSpans = [];
    
    for (final line in lines) {
      print('解析行: "$line"'); // 调试输出
      
      // 解析四级标题
      if (line.startsWith('#### ')) {
        print('发现四级标题: ${line.substring(5)}'); // 调试输出
        textSpans.add(
          _buildTextSpan(
            line.substring(5), // 移除 '#### ' 标记
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        );
        textSpans.add(const TextSpan(text: '\n\n'));
      }
      // 解析三级标题
      else if (line.startsWith('### ')) {
        print('发现三级标题: ${line.substring(4)}'); // 调试输出
        textSpans.add(
          _buildTextSpan(
            line.substring(4), // 移除 '### ' 标记
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        );
        textSpans.add(const TextSpan(text: '\n\n'));
      }
      // 解析二级标题
      else if (line.startsWith('## ')) {
        print('发现二级标题: ${line.substring(3)}'); // 调试输出
        textSpans.add(
          _buildTextSpan(
            line.substring(3), // 移除 '## ' 标记
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        );
        textSpans.add(const TextSpan(text: '\n\n'));
      }
      // 解析一级标题
      else if (line.startsWith('# ')) {
        print('发现一级标题: ${line.substring(2)}'); // 调试输出
        textSpans.add(
          _buildTextSpan(
            line.substring(2), // 移除 '# ' 标记
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
        );
        textSpans.add(const TextSpan(text: '\n\n'));
      }
      // 解析有序列表（支持嵌套，包括没有空格的情况如"1.文本"）
      else if (RegExp(r'^\s*\d+\.\s*').hasMatch(line) && line.trim().contains('.')) {
        final match = RegExp(r'^\s*\d+\.\s*').firstMatch(line)!;
        final listMarker = line.substring(match.start, match.end); // 提取 "1." 或 "1. " 或 "    1. "
        final content = line.substring(match.end); // 提取列表内容
        
        // 计算缩进级别（通过计算原始行前面的空格数）
        final leadingSpaces = line.length - line.trimLeft().length;
        final indentLevel = (leadingSpaces / 4).floor(); // 每4个空格为一级缩进
        
        print('发现有序列表项: $listMarker -> $content (缩进级别: $indentLevel)'); // 调试输出

        // 添加缩进空格
        if (indentLevel > 0) {
          textSpans.add(TextSpan(text: ' ' * (indentLevel * 4)));
        }
        
        // 添加列表标记
        textSpans.add(
          TextSpan(
            text: listMarker.trim(),
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        );
        
        // 添加内容
        textSpans.add(
          _buildTextSpan(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        );
        textSpans.add(const TextSpan(text: '\n'));
      }
      // 解析项目符号列表（支持前面有空格的情况，包括嵌套列表）
      else if (line.trim().startsWith('- ') || line.trim().startsWith('• ') || line.trim().startsWith('* ')) {
        final trimmedLine = line.trim();
        final originalMarker = trimmedLine.substring(0, 2); // 提取原始标记 "- " 或 "• " 或 "* "
        final content = trimmedLine.substring(2); // 提取列表内容
        
        // 将项目符号转换为统一的黑色实心圆点
        final displayMarker = '• '; // 统一显示为黑色实心圆点
        
        // 计算缩进级别（通过计算原始行前面的空格数）
        final leadingSpaces = line.length - line.trimLeft().length;
        final indentLevel = (leadingSpaces / 4).floor(); // 每4个空格为一级缩进
        
        print('发现项目符号列表项: $originalMarker -> $content (缩进级别: $indentLevel, 显示为: $displayMarker)'); // 调试输出

        // 添加缩进空格
        if (indentLevel > 0) {
          textSpans.add(TextSpan(text: ' ' * (indentLevel * 4)));
        }
        
        // 添加项目符号
        textSpans.add(
          TextSpan(
            text: displayMarker,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        );
        
        // 添加内容
        textSpans.add(
          _buildTextSpan(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        );
        textSpans.add(const TextSpan(text: '\n'));
      }
      // 解析普通段落
      else if (line.trim().isNotEmpty) {
        print('发现普通段落: $line'); // 调试输出
        textSpans.add(
          _buildTextSpan(
            line,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        );
        textSpans.add(const TextSpan(text: '\n\n'));
      } else {
        // 空行
        textSpans.add(const TextSpan(text: '\n'));
      }
    }
    
    // 返回一个统一的跨行可选择文本组件
    return [
      _buildSelectableTextWithAiOption(
        TextSpan(
          children: textSpans,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Colors.black87,
          ),
        ),
      ),
    ];
  }

  /// 构建带有AI选项的可选择文本
  Widget _buildSelectableTextWithAiOption(TextSpan textSpan) {
    return Builder(
      builder: (context) => SelectableText.rich(
        textSpan,
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
              // 新增的"问AI"选项
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
      ),
    );
  }

  /// 导航到聊天页面，传递选中的文本
  void _navigateToChatWithSelectedText(BuildContext context, String selectedText) {
    // 构建消息参数：选中的文本 + "为我解答"
    final messageParam = '$selectedText为我解答';
    
    // 导航到聊天页面，使用特殊的对话ID来区分"问AI"场景
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          article: widget.article,
          messageParam: messageParam,
          conversationId: 'ai_interpretation_${DateTime.now().millisecondsSinceEpoch}', // 使用时间戳确保唯一性
        ),
      ),
    );
  }
}
