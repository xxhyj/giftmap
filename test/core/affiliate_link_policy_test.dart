import 'package:flutter_test/flutter_test.dart';
import 'package:giftmap/core/affiliate/affiliate_link_policy.dart';

void main() {
  const AffiliateLinkPolicy policy = AffiliateLinkPolicy();
  final Uri allowed = Uri.https('mock.giftmap.app', '/go');

  test('고지가 표시되지 않으면 이동을 거부한다', () {
    final AffiliateLinkDecision decision = policy.evaluate(
      url: allowed,
      disclosureShown: false,
    );
    expect(decision, isA<AffiliateLinkRejected>());
    expect(
      (decision as AffiliateLinkRejected).reason,
      AffiliateRejectionReason.disclosureNotShown,
    );
  });

  test('https가 아니면 거부한다', () {
    final AffiliateLinkDecision decision = policy.evaluate(
      url: Uri.parse('http://mock.giftmap.app/go'),
      disclosureShown: true,
    );
    expect(
      (decision as AffiliateLinkRejected).reason,
      AffiliateRejectionReason.insecureScheme,
    );
  });

  test('allowlist 밖의 host는 거부한다', () {
    final AffiliateLinkDecision decision = policy.evaluate(
      url: Uri.https('unknown.example', '/go'),
      disclosureShown: true,
    );
    expect(
      (decision as AffiliateLinkRejected).reason,
      AffiliateRejectionReason.hostNotAllowed,
    );
  });

  test('URL이 없으면 거부한다', () {
    final AffiliateLinkDecision decision = policy.evaluate(
      url: null,
      disclosureShown: true,
    );
    expect(
      (decision as AffiliateLinkRejected).reason,
      AffiliateRejectionReason.missingUrl,
    );
  });

  test('정책을 통과해도 외부 브라우저 연결은 NotSupported로 명시된다', () {
    final LinkOpenResult result = policy.open(
      url: allowed,
      disclosureShown: true,
    );
    expect(result, isA<LinkOpenNotSupported>());
  });

  test('정책 위반은 Blocked 결과로 돌려준다', () {
    final LinkOpenResult result = policy.open(
      url: allowed,
      disclosureShown: false,
    );
    expect(result, isA<LinkOpenBlocked>());
  });
}
