import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/product.dart';

/// 인앱 브라우저가 주소를 어떻게 다룰지.
enum StoreUrlAction {
  /// 앱 안에서 그대로 연다.
  open,

  /// 평문(http)이라 https 로 바꿔 다시 연다.
  /// Android 9부터 평문 통신이 막혀 그대로 두면 페이지가 죽는다.
  upgradeToHttps,

  /// 앱 스킴이다. 사용자가 "앱으로 보기"를 고른 것이므로 판매처 앱에 넘긴다.
  handOffToApp,

  /// 읽을 수 없는 주소. 아무것도 하지 않는다.
  ignore,
}

/// 주소 하나를 어떻게 다룰지 정한다. 화면과 떼어 두어 따로 검증한다.
StoreUrlAction storeUrlAction(String raw) {
  final Uri? url = Uri.tryParse(raw);
  if (url == null || !url.hasScheme) return StoreUrlAction.ignore;
  if (url.isScheme('https')) return StoreUrlAction.open;
  if (url.isScheme('http')) return StoreUrlAction.upgradeToHttps;
  return StoreUrlAction.handOffToApp;
}

/// 판매처 상품 페이지를 Giftmap 안에서 여는 브라우저.
///
/// 왜 앱 안에서 여는가
/// - 판매처 앱으로 곧장 넘기면 로그인부터 요구하는 경우가 많다. 그냥 상품을
///   보려던 사람에게는 막다른 길이다. 웹 페이지는 로그인 없이 볼 수 있다.
/// - 구매까지 가려는 사람은 페이지 안에서 스스로 앱으로 넘어갈 수 있다.
///   그때만 판매처 앱을 연다(아래 [_handleNavigation] 참고).
/// - 구매하지 않기로 하면 상단의 뒤로/닫기로 곧장 상품 상세로 돌아온다.
class StoreBrowserScreen extends StatefulWidget {
  const StoreBrowserScreen({required this.product, super.key});

  final Product product;

  @override
  State<StoreBrowserScreen> createState() => _StoreBrowserScreenState();
}

class _StoreBrowserScreenState extends State<StoreBrowserScreen> {
  late final WebViewController _controller;

  /// 페이지를 받는 중인지. 0~1.
  double _progress = 0;
  bool _loading = true;

  /// 페이지 안에서 뒤로 갈 곳이 있는지. 상단 버튼의 동작이 달라진다.
  bool _canGoBack = false;

  /// 페이지를 못 연 이유. null이면 정상이다.
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigation,
          onProgress: (int percent) {
            if (mounted) setState(() => _progress = percent / 100);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) async {
            final bool back = await _controller.canGoBack();
            if (mounted) {
              setState(() {
                _loading = false;
                _canGoBack = back;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            // 페이지 안의 이미지 하나가 실패한 경우까지 오류 화면을 띄우지 않는다.
            if (!error.isForMainFrame!) return;
            if (mounted) setState(() => _error = error.description);
          },
        ),
      );

    final Uri? url = Uri.tryParse(widget.product.productUrl ?? '');
    if (url == null || !url.isScheme('https') && !url.isScheme('http')) {
      _error = '주소를 열 수 없습니다.';
      _loading = false;
    } else {
      _controller.loadRequest(url);
    }
  }

  /// 페이지가 어디로 가려는지 판단한다.
  ///
  /// - https: 그대로 앱 안에서 연다.
  /// - http: Android 9부터 평문 통신이 막혀 있어 그대로 두면 페이지가 죽는다
  ///   (`ERR_CLEARTEXT_NOT_PERMITTED`). 판매처가 모바일 페이지로 보낼 때 http로
  ///   내려보내는 경우가 있어(예: 알라딘), 같은 주소를 https로 올려 다시 연다.
  /// - 그 외(`intent://`, `market://`, 판매처 앱 스킴): 앱 안에서는 열 수 없다.
  ///   사용자가 페이지에서 "앱으로 보기"를 눌렀을 때 일어나는 일이므로,
  ///   그 뜻을 존중해 판매처 앱(또는 스토어)으로 넘긴다.
  Future<NavigationDecision> _handleNavigation(
    NavigationRequest request,
  ) async {
    final Uri? url = Uri.tryParse(request.url);
    switch (storeUrlAction(request.url)) {
      case StoreUrlAction.open:
        return NavigationDecision.navigate;
      case StoreUrlAction.ignore:
        return NavigationDecision.prevent;
      case StoreUrlAction.upgradeToHttps:
        await _controller.loadRequest(url!.replace(scheme: 'https'));
        return NavigationDecision.prevent;
      case StoreUrlAction.handOffToApp:
        try {
          await launchUrl(url!, mode: LaunchMode.externalApplication);
        } on Object {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('판매처 앱을 열 수 없어요.')));
          }
        }
        return NavigationDecision.prevent;
    }
  }

  /// 상단 뒤로. 페이지 안에서 뒤로 갈 곳이 있으면 그쪽이 먼저다.
  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// 판매처 페이지를 기기 기본 브라우저로 넘긴다.
  /// 앱 안에서 잘 보이지 않을 때를 위한 탈출구다.
  Future<void> _openOutside() async {
    final Uri? url = Uri.tryParse(widget.product.productUrl ?? '');
    if (url == null) return;
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('브라우저를 열 수 없어요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String where = widget.product.sourceLabel ?? '판매처';

    return PopScope(
      // 기기 뒤로가기도 페이지 안에서 먼저 뒤로 간다.
      canPop: !_canGoBack,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '뒤로',
            onPressed: _goBack,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(where, style: text.titleMedium),
              Text(
                widget.product.productName,
                style: text.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: '브라우저로 열기',
              onPressed: _openOutside,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '닫고 상품으로 돌아가기',
              // 페이지를 얼마나 넘어갔든 상품 상세로 곧장 돌아온다.
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          bottom: _loading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress,
                    minHeight: 2,
                  ),
                )
              : null,
        ),
        body: _error == null
            ? WebViewWidget(controller: _controller)
            : _LoadFailed(
                message: _error!,
                onRetry: () {
                  final Uri? url = Uri.tryParse(
                    widget.product.productUrl ?? '',
                  );
                  if (url == null) return;
                  setState(() {
                    _error = null;
                    _loading = true;
                  });
                  _controller.loadRequest(url);
                },
                onOpenOutside: _openOutside,
              ),
      ),
    );
  }
}

/// 페이지를 열지 못했을 때. 막다른 길로 두지 않는다.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({
    required this.message,
    required this.onRetry,
    required this.onOpenOutside,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenOutside;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppColors.ink,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '판매처 페이지를 열지 못했어요',
              style: text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: text.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onOpenOutside, child: const Text('브라우저로 열기')),
          ],
        ),
      ),
    );
  }
}
