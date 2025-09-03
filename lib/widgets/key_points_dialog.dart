import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:legacy_pi/models/article.dart';
import 'package:legacy_pi/services/ai_service.dart';
import 'package:legacy_pi/services/markdown_parser_service.dart';
import 'package:legacy_pi/services/tts_service.dart';
import 'package:legacy_pi/services/unified_cache_service.dart';

/// 总结要点对话框Widget（内容撑开高度）
class KeyPointsDialog extends StatefulWidget {
  final Article article;
  final AiService aiService;
  final UnifiedCacheService cacheService;
  final String promptType; // 提示词类型

  const KeyPointsDialog({
    required this.article,
    required this.aiService,
    required this.cacheService,
    this.promptType = 'key_points', // 默认为key_points
  });

  @override
  State<KeyPointsDialog> createState() => _KeyPointsDialogState();
}

class _KeyPointsDialogState extends State<KeyPointsDialog> with TickerProviderStateMixin {
  bool _isLoading = true;
  String _aiInterpretation = '';
  String? _errorMessage;
  bool _autoPlay = false; // 自动播放开关状态
  String _selectedVoice = 'zh-CN-XiaoxiaoNeural'; // 当前选择的音色
  bool _isAudioLoading = false; // 音频加载状态
  bool _isPlaying = false; // 音频播放状态
  bool _isPaused = false; // 是否处于暂停状态
  String _currentTime = '00:00'; // 当前播放时间
  final TtsService _ttsService = TtsService();
  final MarkdownParserService _markdownParser = MarkdownParserService();

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
      
      // 使用缓存的音频数据播放
      final result = await _ttsService.streamTtsAndPlay(
        text: cleanedText,
        voice: _selectedVoice,
        language: 'zh-CN',
        autoPlay: true, // 缓存播放时总是播放
        onTimeUpdate: (time) {
          setState(() {
            try {
              _currentTime = time.trim();
              if (kDebugMode) {
                print('缓存音频时间更新: $_currentTime');
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
        cachedAudioData: cachedAudioData,
      );
      
      if (result['success'] == true) {
        if (kDebugMode) {
          print('缓存音频播放成功');
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
          print('缓存音频播放失败: ${result['error']}');
        }
        // 缓存播放失败，清除缓存并重新获取
        widget.cacheService.clearTextCache(cleanedText);
        
        _startTtsPlayback(); // 递归调用重新获取
      }
      return;
    } catch (e) {
      if (kDebugMode) {
        print('缓存音频播放异常: $e');
      }
      // 清除缓存并重新获取
      widget.cacheService.clearTextCache(cleanedText);
    }
    
    // 没有缓存或缓存失效，重新获取音频
    setState(() {
      _isAudioLoading = true;
      _isPlaying = false;
      _isPaused = false;
      _currentTime = '00:00';
    });
    
    try {
      // 清理Markdown格式，准备TTS播放
      final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
      
      // 使用缓存的音频数据播放
      final result = await _ttsService.streamTtsAndPlay(
        text: cleanedText,
        voice: _selectedVoice,
        language: 'zh-CN',
        autoPlay: true, // 手动播放时总是播放
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
          _isPlaying = true;
          _isPaused = false;
        });
      } else {
        setState(() {
          _isAudioLoading = false;
        });
        if (kDebugMode) {
          print('TTS播放失败: ${result['error']}');
        }
      }
    } catch (e) {
      setState(() {
        _isAudioLoading = false;
      });
      if (kDebugMode) {
        print('TTS播放异常: $e');
      }
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

  // 停止TTS播放
  Future<void> _stopTtsPlayback() async {
    try {
      await _ttsService.pause();
      setState(() {
        _isPlaying = false;
        _isPaused = true;
      });
      if (kDebugMode) {
        print('TTS播放已暂停');
      }
    } catch (e) {
      if (kDebugMode) {
        print('TTS暂停失败: $e');
      }
    }
  }

  // 快进
  Future<void> _fastForward() async {
    try {
      if (_isPlaying || _isPaused) {
        await _ttsService.seekToRelative(10); // 快进10秒
        if (kDebugMode) {
          print('TTS快进10秒');
        }
        
        // 如果之前是暂停状态，快进后恢复播放
        if (_isPaused) {
          await _ttsService.resume();
          setState(() {
            _isPlaying = true;
            _isPaused = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('TTS快进失败: $e');
      }
    }
  }

  // 快退
  Future<void> _fastRewind() async {
    try {
      if (_isPlaying || _isPaused) {
        await _ttsService.seekToRelative(-10); // 快退10秒
        if (kDebugMode) {
          print('TTS快退10秒');
        }
        
        // 如果之前是暂停状态，快退后恢复播放
        if (_isPaused) {
          await _ttsService.resume();
          setState(() {
            _isPlaying = true;
            _isPaused = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('TTS快退失败: $e');
      }
    }
  }

  // 显示音频选项抽屉
  void _showAudioOptionsDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                          value: 'zh-CN-YunjianNeural',
                          child: Text('云健 (男声)', style: TextStyle(fontSize: 14)),
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
                          
                          // 如果当前正在播放或暂停，停止播放并清除缓存
                          if (_isPlaying || _isPaused) {
                            _ttsService.stop();
                            setState(() {
                              _isPlaying = false;
                              _isPaused = false;
                              _currentTime = '00:00';
                            });
                            
                            // 清除文本缓存，确保使用新音色
                            final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
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
    );
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        // 关键修改：移除固定高度，让内容撑开
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9, // 最大高度限制
          minHeight: MediaQuery.of(context).size.height * 0.3,  // 最小高度限制
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 关键：让列根据内容调整大小
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
            // 对话框内容 - 关键修改：移除Expanded，让内容自然撑开
            _isLoading
                ? _buildLoadingContent()
                : _buildAiContent(),
            // 音频播放器覆盖层
            if (!_isLoading && _aiInterpretation.isNotEmpty)
              _buildAudioPlayerOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.2, // 加载时使用固定高度
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
                size: 48,
                color: Colors.red[300],
            ),
            const SizedBox(height: 16),
              Text(
                'AI解读失败',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
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
          const SizedBox(height: 20),
          // 使用优化的内容显示
          _buildOptimizedContent(_aiInterpretation),
        ],
      ),
    );
  }

  // 优化的内容显示方法 - 整合到一个组件中
  Widget _buildOptimizedContent(String content) {
    if (content.isEmpty) return const SizedBox.shrink();
    
    final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    // 如果内容很少（少于5行），使用整合的文本组件
    if (lines.length <= 5) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: _buildUnifiedTextContent(lines),
      );
    }
    
    // 如果内容较多，使用原有的Markdown解析
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _markdownParser.parseMarkdown(content),
    );
  }

  // 构建统一的文本内容组件
  Widget _buildUnifiedTextContent(List<String> lines) {
    final List<InlineSpan> spans = [];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // 检查是否是编号列表项
      final numberedMatch = RegExp(r'^(\d+)[\.、）\)]\s*(.+)$').firstMatch(line);
      if (numberedMatch != null) {
        final number = numberedMatch.group(1)!;
        final text = numberedMatch.group(2)!;
        
        // 添加编号样式
        spans.add(WidgetSpan(
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.red[600]!, Colors.red[700]!],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red[200]!,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ));
        
        // 添加文本内容
        spans.add(TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 19,
            height: 1.2,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ));
        
        // 添加换行
        if (i < lines.length - 1) {
          spans.add(const TextSpan(text: '\n\n'));
        }
        continue;
      }
      
      // 检查是否是项目符号列表项
      if (line.startsWith('- ') || line.startsWith('• ') || line.startsWith('* ')) {
        final text = line.substring(2).trim();
        
        // 添加项目符号
        spans.add(WidgetSpan(
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 12, top: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.red[500]!, Colors.red[600]!],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red[200]!,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ));
        
        // 添加文本内容
        spans.add(TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 19,
            height: 1.2,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ));
        
        // 添加换行
        if (i < lines.length - 1) {
          spans.add(const TextSpan(text: '\n\n'));
        }
        continue;
      }
      
      // 普通文本行
      final hasKeywords = line.contains('要点') || 
                         line.contains('总结') || 
                         line.contains('关键') ||
                         line.contains('重要');
      
      spans.add(TextSpan(
        text: line,
        style: TextStyle(
          fontSize: hasKeywords ? 20 : 19,
          height: 1.2,
          color: hasKeywords ? Colors.blue[800] : Colors.black87,
          fontWeight: hasKeywords ? FontWeight.w600 : FontWeight.w500,
        ),
      ));
      
      // 添加换行
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n\n'));
      }
    }
    
    return SelectableText.rich(
      TextSpan(
        children: spans,
        style: const TextStyle(
          fontSize: 19,
          height: 1.2,
          color: Colors.black87,
        ),
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
}
