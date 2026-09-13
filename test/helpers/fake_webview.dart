import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// 테스트에서 쓰는 가짜 웹뷰 플랫폼.
///
/// `webview_flutter`는 실제 기기의 웹뷰를 붙이는 패키지라 위젯 테스트에서는
/// 플랫폼 구현이 없어 그리지 못한다. 화면(앱바·뒤로·닫기·오류 처리)을 검증하려면
/// 웹뷰 자리를 채워 줄 대역이 필요하다. 페이지를 실제로 받지는 않는다.
class FakeWebViewPlatform extends WebViewPlatform {
  /// 테스트 시작 전에 한 번 불러 대역을 꽂는다.
  static void install() => WebViewPlatform.instance = FakeWebViewPlatform();

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => FakeWebViewController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => FakeWebViewWidget(params);

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) => FakeCookieManager(params);
}

class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params) : super.implementation();

  /// 이 컨트롤러가 받은 주소. 무엇을 열려고 했는지 확인할 때 쓴다.
  final List<String> requested = <String>[];

  /// 페이지 안에서 뒤로 갈 곳이 있는지. 테스트가 정한다.
  bool canGoBackResult = false;
  int goBackCount = 0;

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    requested.add(params.uri.toString());
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<bool> canGoBack() async => canGoBackResult;

  @override
  Future<void> goBack() async {
    goBackCount += 1;
  }
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? request;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onRequest,
  ) async {
    request = onRequest;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
}

class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFFEEEEEE), child: SizedBox.expand());
}

class FakeCookieManager extends PlatformWebViewCookieManager {
  FakeCookieManager(super.params) : super.implementation();
}
