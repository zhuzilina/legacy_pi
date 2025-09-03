import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/api_config.dart';

/// TTS服务类，用于处理文本转语音请求
class TtsService {
  // 使用统一的API配置
  static String get _baseUrl => ApiConfig.ttsBaseUrl;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  int? _lastUpdateTime; // 用于限制时间更新频率
  
  /// 初始化音频播放器
  Future<void> _initializeAudioPlayer() async {
    if (!_isInitialized) {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop); // 改为停止模式，不循环播放
      _isInitialized = true;
    }
  }
  
  /// 获取可用的语音列表
  Future<Map<String, String>?> getAvailableVoices() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/voices/'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Map<String, String>.from(data['voices']);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('获取语音列表失败: $e');
      }
      return null;
    }
  }
  
  /// 流式TTS转换并播放
  Future<Map<String, dynamic>> streamTtsAndPlay({
    required String text,
    String voice = 'zh-CN-XiaoxiaoNeural',
    String language = 'zh-CN',
    required Function(String) onTimeUpdate,
    required Function() onComplete,
    required Function(String) onError,
    Uint8List? cachedAudioData, // 新增：缓存的音频数据
    bool autoPlay = true, // 新增：是否自动播放
  }) async {
    try {
      await _initializeAudioPlayer();
      
      // 调试信息
      if (kDebugMode) {
        print('当前环境: kIsWeb = $kIsWeb');
      }
      
      // 检查是否有缓存的音频数据
      if (cachedAudioData != null) {
        if (kDebugMode) {
          print('使用缓存的音频数据，大小: ${cachedAudioData.length} 字节');
        }
        
        try {
          // 根据autoPlay参数决定是否播放
          if (autoPlay) {
            if (kDebugMode) {
              print('自动播放已开启，开始播放缓存音频');
            }
            // 直接播放缓存的音频数据
            await _audioPlayer.play(BytesSource(cachedAudioData));
            
            // 设置音频播放器监听器，限制更新频率
            _audioPlayer.onPositionChanged.listen((duration) {
              // 限制更新频率，每500ms更新一次
              final now = DateTime.now().millisecondsSinceEpoch;
              if (_lastUpdateTime != null && now - _lastUpdateTime! < 500) {
                return;
              }
              _lastUpdateTime = now;
              
              // 实时更新时间显示
              if (kDebugMode) {
                print('缓存音频播放时间更新: ${duration.inMilliseconds}ms');
              }
              
              // 更新时间显示
              final currentTime = _formatDuration(duration);
              onTimeUpdate(currentTime);
            });
            
            // 监听播放完成
            _audioPlayer.onPlayerComplete.listen((_) {
              onComplete();
            });
          } else {
            if (kDebugMode) {
              print('自动播放已关闭，缓存音频加载完成但不播放');
            }
          }
          
          return {
            'success': true,
            'audioData': cachedAudioData,
            'fromCache': true,
          };
        } catch (e) {
          if (kDebugMode) {
            print('缓存音频播放失败: $e，尝试重新获取');
          }
        }
      }
      
      // 强制使用流式播放，避免文件格式兼容性问题
      if (true) { // 暂时强制使用流式播放
        if (kDebugMode) {
          print('Web环境，使用流式TTS播放');
        }
        
        final audioStream = await streamTts(
          text: text,
          voice: voice,
          language: language,
        );
        
        if (audioStream != null) {
          // 收集音频数据
          final List<int> audioData = [];
          await for (final chunk in audioStream) {
            audioData.addAll(chunk);
          }
          
          if (kDebugMode) {
            print('音频数据收集完成，总大小: ${audioData.length} 字节');
          }
          
          try {
            // 根据autoPlay参数决定是否播放
            if (autoPlay) {
              if (kDebugMode) {
                print('自动播放已开启，开始播放流式音频');
              }
              // 在web环境中，尝试使用BytesSource播放
              await _audioPlayer.play(BytesSource(Uint8List.fromList(audioData)));
              
              // 设置音频播放器监听器，限制更新频率
              _audioPlayer.onPositionChanged.listen((duration) {
                // 限制更新频率，每500ms更新一次
                final now = DateTime.now().millisecondsSinceEpoch;
                if (_lastUpdateTime != null && now - _lastUpdateTime! < 500) {
                  return;
                }
                _lastUpdateTime = now;
                
                // 实时更新时间显示
                if (kDebugMode) {
                  print('播放时间更新: ${duration.inMilliseconds}ms');
                }
                
                // 更新时间显示
                final currentTime = _formatDuration(duration);
                onTimeUpdate(currentTime);
              });
              
              // 监听播放完成
              _audioPlayer.onPlayerComplete.listen((_) {
                onComplete();
              });
            } else {
              if (kDebugMode) {
                print('自动播放已关闭，流式音频加载完成但不播放');
              }
            }
            
            return {
              'success': true,
              'audioData': Uint8List.fromList(audioData),
              'fromCache': false,
            };
          } catch (e) {
            if (kDebugMode) {
              print('BytesSource播放失败: $e');
            }
            
            // 如果BytesSource失败，尝试使用平台特定的播放方式
            try {
              if (kDebugMode) {
                print('尝试使用平台特定的播放方式');
              }
              
              if (kIsWeb) {
                // Web环境：尝试使用audioplayers的其他播放方式
                if (kDebugMode) {
                  print('Web环境，尝试使用audioplayers的其他播放方式');
                }
                
                // 尝试使用UrlSource播放一个简单的测试音频
                try {
                  await _audioPlayer.play(UrlSource('data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSuBzvLZiTYIG2m98OScTgwOUarm7blmGgU7k9n1unEiBC13yO/eizEIHWq+8+OWT'));
                  
                  if (kDebugMode) {
                    print('测试音频播放成功');
                  }
                  
                  // 设置音频播放器监听器，限制更新频率
                  _audioPlayer.onPositionChanged.listen((duration) {
                    // 限制更新频率，每500ms更新一次
                    final now = DateTime.now().millisecondsSinceEpoch;
                    if (_lastUpdateTime != null && now - _lastUpdateTime! < 500) {
                      return;
                    }
                    _lastUpdateTime = now;
                    
                    // 实时更新时间显示
                    if (kDebugMode) {
                      print('测试音频播放时间更新: ${duration.inMilliseconds}ms');
                    }
                    
                    // 更新时间显示
                    final currentTime = _formatDuration(duration);
                    onTimeUpdate(currentTime);
                  });
                  
                  // 模拟播放完成
                  Future.delayed(const Duration(seconds: 2), () {
                    onComplete();
                  });
                  
                  return {
                    'success': true,
                    'audioData': Uint8List.fromList(audioData),
                    'fromCache': false,
                  };
                } catch (testError) {
                  if (kDebugMode) {
                    print('测试音频播放失败: $testError');
                  }
                }
              } else {
                // 移动端环境：尝试使用文件播放
                if (kDebugMode) {
                  print('移动端环境，尝试使用文件播放');
                }
                
                try {
                  // 创建临时文件
                  final tempDir = Directory.systemTemp;
                  final tempFile = File('${tempDir.path}/tts_audio_${DateTime.now().millisecondsSinceEpoch}.wav');
                  await tempFile.writeAsBytes(audioData);
                  
                  if (kDebugMode) {
                    print('临时文件创建成功: ${tempFile.path}');
                  }
                  
                  // 播放临时文件
                  await _audioPlayer.play(DeviceFileSource(tempFile.path));
                  
                  // 设置音频播放器监听器
                  _audioPlayer.onPositionChanged.listen((duration) {
                    // 实时更新时间显示
                    if (kDebugMode) {
                      print('文件播放时间更新: ${duration.inMilliseconds}ms');
                    }
                    
                    // 更新时间显示
                    final currentTime = _formatDuration(duration);
                    onTimeUpdate(currentTime);
                  });
                  
                  // 监听播放完成
                  _audioPlayer.onPlayerComplete.listen((_) {
                    onComplete();
                    // 删除临时文件
                    tempFile.delete();
                  });
                  
                  return {
                    'success': true,
                    'audioData': Uint8List.fromList(audioData),
                    'fromCache': false,
                  };
                } catch (fileError) {
                  if (kDebugMode) {
                    print('文件播放也失败: $fileError');
                  }
                }
              }
              
              // 如果所有方法都失败
              onError('所有播放方式都失败');
              return {
                'success': false,
                'error': '所有播放方式都失败',
                'audioData': null,
                'fromCache': false,
              };
            } catch (platformError) {
              if (kDebugMode) {
                print('平台特定播放也失败: $platformError');
              }
              
              onError('所有播放方式都失败: $platformError');
              return {
                'success': false,
                'error': '所有播放方式都失败: $platformError',
                'audioData': null,
                'fromCache': false,
              };
            }
          }
        }
      } else {
        // 非web环境，先尝试文件式TTS
        final fileResult = await fileTts(
          text: text,
          voice: voice,
          language: language,
        );
        
        if (fileResult != null && fileResult['success'] == true) {
          // 文件式TTS成功，直接播放文件
          final audioFile = fileResult['audio_file'] as String;
          
          // 修复URL路径问题，确保是相对路径
          String audioUrl;
          if (audioFile.startsWith('/')) {
            audioUrl = '${ApiConfig.baseUrl}$audioFile';
          } else {
            audioUrl = '${ApiConfig.baseUrl}/$audioFile';
          }
          
          if (kDebugMode) {
            print('播放音频文件: $audioUrl');
          }
          
          try {
            // 播放音频文件
            await _audioPlayer.play(UrlSource(audioUrl));
            
            // 监听播放时间
            _audioPlayer.onPositionChanged.listen((duration) {
              // 实时更新时间显示
              if (kDebugMode) {
                print('URL播放时间更新: ${duration.inMilliseconds}ms');
              }
              
              // 更新时间显示
              final currentTime = _formatDuration(duration);
              onTimeUpdate(currentTime);
            });
            
            // 监听播放完成
            _audioPlayer.onPlayerComplete.listen((_) {
              onComplete();
            });
            
            return {
              'success': true,
              'audioData': null, // 文件播放没有音频数据
              'fromCache': false,
            };
          } catch (e) {
            if (kDebugMode) {
              print('URL播放失败: $e');
            }
            onError('文件播放失败: $e');
            return {
              'success': false,
              'error': '文件播放失败: $e',
              'audioData': null,
              'fromCache': false,
            };
          }
        }
      }
      
      // 如果所有方法都失败，返回false
      onError('TTS播放失败');
      return {
        'success': false,
        'error': 'TTS播放失败',
        'audioData': null,
        'fromCache': false,
      };
    } catch (e) {
      if (kDebugMode) {
        print('TTS播放异常: $e');
      }
      onError(e.toString());
      return {
        'success': false,
        'error': e.toString(),
        'audioData': null,
        'fromCache': false,
      };
    }
  }
  
  /// 流式TTS转换（保留原方法用于兼容）
  Future<Stream<Uint8List>?> streamTts({
    required String text,
    String voice = 'zh-CN-XiaoxiaoNeural',
    String language = 'zh-CN',
  }) async {
    try {
      final request = http.Request('POST', Uri.parse('$_baseUrl/stream/'));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({
        'text': text,
        'voice': voice,
        'language': language,
      });
      
      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode == 200) {
        // 返回音频数据流
        return streamedResponse.stream.map((chunk) => Uint8List.fromList(chunk));
      } else {
        if (kDebugMode) {
          print('TTS请求失败: ${streamedResponse.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('TTS流式请求异常: $e');
      }
      return null;
    }
  }
  
  /// 文件式TTS转换
  Future<Map<String, dynamic>?> fileTts({
    required String text,
    String voice = 'zh-CN-XiaoxiaoNeural',
    String language = 'zh-CN',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/file/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'voice': voice,
          'language': language,
        }),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        if (kDebugMode) {
          print('TTS文件请求失败: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('TTS文件请求异常: $e');
      }
      return null;
    }
  }
  
  /// 查询TTS请求状态
  Future<Map<String, dynamic>?> getTtsStatus(int requestId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/status/$requestId/'));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        if (kDebugMode) {
          print('查询TTS状态失败: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('查询TTS状态异常: $e');
      }
      return null;
    }
  }
  
  /// 下载音频文件
  Future<Uint8List?> downloadAudio(int requestId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/download/$requestId/'));
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        if (kDebugMode) {
          print('下载音频文件失败: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('下载音频文件异常: $e');
      }
      return null;
    }
  }
  
  /// 暂停播放
  Future<void> pause() async {
    await _audioPlayer.pause();
  }
  
  /// 恢复播放
  Future<void> resume() async {
    await _audioPlayer.resume();
  }
  
  /// 停止播放
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// 快进/快退播放（相对时间）
  Future<void> seekToRelative(int seconds) async {
    try {
      final currentPosition = await _audioPlayer.getCurrentPosition();
      if (currentPosition != null) {
        final newPosition = currentPosition + Duration(seconds: seconds);
        if (newPosition.inMilliseconds > 0) {
          // 记录当前播放状态
          final wasPlaying = _audioPlayer.state == PlayerState.playing;
          
          // 执行seek操作
          await _audioPlayer.seek(newPosition);
          
          if (kDebugMode) {
            print('快进/快退到: ${newPosition.inSeconds}秒');
          }
          
          // 如果之前是播放状态，seek后恢复播放
          if (wasPlaying && _audioPlayer.state != PlayerState.playing) {
            await _audioPlayer.resume();
            if (kDebugMode) {
              print('seek后恢复播放');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('快进/快退失败: $e');
      }
      rethrow; // 重新抛出异常，让调用者处理
    }
  }

  /// 跳转到指定位置（绝对时间）
  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      if (kDebugMode) {
        print('跳转到: ${position.inSeconds}秒');
      }
    } catch (e) {
      if (kDebugMode) {
        print('跳转失败: $e');
      }
    }
  }
  
  /// 设置音量
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
  }
  
  /// 获取播放状态
  PlayerState get playerState => _audioPlayer.state;
  
  /// 格式化时长显示
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// 释放资源
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
