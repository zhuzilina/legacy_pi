import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

class ARWebviewPage extends StatefulWidget {
  const ARWebviewPage({super.key});

  @override
  State<ARWebviewPage> createState() => _ARWebviewPageState();
}

class _ARWebviewPageState extends State<ARWebviewPage> {
  late final InAppWebViewController _controller;
  bool _isLoading = true;
  PullToRefreshController? pullToRefreshController;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initWebView();
  }

  void _initWebView() {
    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: Colors.blue,
      ),
      onRefresh: () async {
        if (await _controller.getUrl() != null) {
          await _controller.reload();
        }
      },
    );
  }

  // 请求权限
  Future<void> _requestPermissions() async {
    try {
      // 检查并请求麦克风和摄像头权限
      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
      }

      var camStatus = await Permission.camera.status;
      if (!camStatus.isGranted) {
        camStatus = await Permission.camera.request();
      }

      if (micStatus.isGranted && camStatus.isGranted) {
        debugPrint('权限已授予');
      } else if (micStatus.isDenied || camStatus.isDenied) {
        debugPrint('权限被拒绝');
      } else if (micStatus.isPermanentlyDenied || camStatus.isPermanentlyDenied) {
        debugPrint('权限被永久拒绝，需要用户手动开启');
        await openAppSettings();
      }
    } catch (e) {
      debugPrint('请求权限时发生错误: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('小红同学'),
        backgroundColor: Colors.red[700],
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri('https://172.21.4.5:3000')),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              useShouldOverrideUrlLoading: true,
              useHybridComposition: true,
              allowContentAccess: true,
              allowFileAccess: true,
              domStorageEnabled: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
              allowsInlineMediaPlayback: true,
              allowsAirPlayForMediaPlayback: true,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
              });
              debugPrint('Page started loading: $url');
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
              });
              debugPrint('Page finished loading: $url');
            },
            onReceivedError: (controller, request, error) {
              debugPrint('''
Page resource error:
  code: ${error.type}
  description: ${error.description}
  url: ${request.url}
          ''');
            },
            onReceivedServerTrustAuthRequest: (controller, challenge) async {
              debugPrint('服务器信任验证请求: ${challenge.protectionSpace?.host}');
              // 信任自签名证书
              return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
            },
            androidOnPermissionRequest: (controller, origin, resources) async {
              debugPrint('WebView 权限请求: $resources');
              // 授予所有请求的权限，包括麦克风
              return PermissionRequestResponse(
                resources: resources,
                action: PermissionRequestResponseAction.GRANT,
              );
            },
            pullToRefreshController: pullToRefreshController,
          ),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在加载页面...'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}