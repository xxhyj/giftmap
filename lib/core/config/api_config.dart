/// Vercel API 접속 설정.
///
/// 값은 코드에 넣지 않고 빌드할 때 `--dart-define`으로 전달한다.
///
/// ```bash
/// flutter build apk --release \
///   --dart-define=USE_MOCK=false \
///   --dart-define=API_BASE_URL=https://<배포주소>.vercel.app
/// ```
///
/// 앱에 들어가는 값은 이 주소 하나뿐이다. Supabase 키도 OpenAI 키도 앱에
/// 넣지 않는다. 그 값들은 서버(Vercel) 환경변수에만 있다.
class ApiConfig {
  const ApiConfig({required this.baseUrl, required this.useMock});

  /// 빌드할 때 전달된 값으로 만든 설정.
  ///
  /// `USE_MOCK`의 기본값은 true다. 아무것도 주지 않고 실행하면 예전처럼
  /// 번들 Mock 데이터로 동작하고, 테스트도 그 경로를 쓴다.
  factory ApiConfig.fromEnvironment() => const ApiConfig(
    baseUrl: String.fromEnvironment('API_BASE_URL'),
    useMock: bool.fromEnvironment('USE_MOCK', defaultValue: true),
  );

  final String baseUrl;

  /// true면 서버를 부르지 않는다.
  final bool useMock;

  /// 주소가 https 로 된 제대로 된 값인지.
  ///
  /// 평문(http)은 받지 않는다. Android 9부터 평문 통신이 막혀 있고,
  /// 주소가 새는 것도 막아야 한다.
  bool get isConfigured {
    final String trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return false;
    final Uri? uri = Uri.tryParse(trimmed);
    return uri != null && uri.isScheme('https') && uri.host.isNotEmpty;
  }

  /// 서버를 실제로 쓸 수 있는 상태인지.
  bool get isRemoteMode => !useMock && isConfigured;

  /// 끝의 `/`를 떼고 경로를 붙인 주소.
  Uri resolve(String path, [Map<String, String>? query]) {
    final String base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final String suffix = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$base$suffix',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
  }
}
