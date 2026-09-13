/// Supabase 접속 설정.
///
/// 값은 코드에 넣지 않고 실행할 때 `--dart-define`으로 전달한다.
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable(anon) key>
/// ```
///
/// 전달하지 않으면 [isConfigured]가 false가 되고, 앱은 번들 Mock 데이터로
/// 그대로 동작한다.
///
/// service_role 키는 서버 전용이므로 **앱에 절대 넣지 않는다.**
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  /// 실행 시 전달된 값으로 만든 설정.
  factory SupabaseConfig.fromEnvironment() => const SupabaseConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  final String url;
  final String publishableKey;

  /// 두 값이 모두 있고 형태가 그럴듯한지.
  bool get isConfigured =>
      url.trim().isNotEmpty &&
      publishableKey.trim().isNotEmpty &&
      Uri.tryParse(url.trim())?.hasScheme == true;

  /// 실수로 service_role 키를 넣었는지 가볍게 확인한다.
  ///
  /// service_role 키는 JWT payload에 `service_role`이 들어가므로 문자열로도
  /// 알아볼 수 있다. 발견되면 연결을 중단하고 Mock 데이터로 동작한다.
  bool get looksLikeServiceRoleKey =>
      publishableKey.contains('service_role') ||
      publishableKey.startsWith('sb_secret_');
}
