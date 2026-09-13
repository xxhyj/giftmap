import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/core/config/supabase_config.dart';

void main() {
  test('값이 없으면 설정되지 않은 것으로 본다', () {
    const SupabaseConfig config = SupabaseConfig(url: '', publishableKey: '');
    expect(config.isConfigured, isFalse);
  });

  test('한쪽만 있으면 설정되지 않은 것으로 본다', () {
    const SupabaseConfig onlyUrl = SupabaseConfig(
      url: 'https://demo.supabase.co',
      publishableKey: '',
    );
    const SupabaseConfig onlyKey = SupabaseConfig(
      url: '',
      publishableKey: 'sb_publishable_abc',
    );
    expect(onlyUrl.isConfigured, isFalse);
    expect(onlyKey.isConfigured, isFalse);
  });

  test('URL 형태가 아니면 설정되지 않은 것으로 본다', () {
    const SupabaseConfig config = SupabaseConfig(
      url: 'not-a-url',
      publishableKey: 'sb_publishable_abc',
    );
    expect(config.isConfigured, isFalse);
  });

  test('둘 다 있으면 설정된 것으로 본다', () {
    const SupabaseConfig config = SupabaseConfig(
      url: 'https://demo.supabase.co',
      publishableKey: 'sb_publishable_abc',
    );
    expect(config.isConfigured, isTrue);
    expect(config.looksLikeServiceRoleKey, isFalse);
  });

  test('service_role 키로 보이면 표시한다', () {
    const SupabaseConfig jwtStyle = SupabaseConfig(
      url: 'https://demo.supabase.co',
      publishableKey: 'header.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.service_role',
    );
    const SupabaseConfig secretStyle = SupabaseConfig(
      url: 'https://demo.supabase.co',
      publishableKey: 'sb_secret_abc',
    );
    expect(jwtStyle.looksLikeServiceRoleKey, isTrue);
    expect(secretStyle.looksLikeServiceRoleKey, isTrue);
  });

  test('--dart-define 이 없는 테스트 환경에서는 미설정 상태다', () {
    expect(SupabaseConfig.fromEnvironment().isConfigured, isFalse);
  });
}
