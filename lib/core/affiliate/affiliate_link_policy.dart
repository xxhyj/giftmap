/// 제휴 링크 이동 판정 결과.
sealed class AffiliateLinkDecision {
  const AffiliateLinkDecision();
}

/// 정책을 통과해 외부 이동이 허용된 상태.
final class AffiliateLinkAllowed extends AffiliateLinkDecision {
  const AffiliateLinkAllowed(this.destination);

  final Uri destination;
}

/// 정책 위반으로 이동을 거부한 상태.
final class AffiliateLinkRejected extends AffiliateLinkDecision {
  const AffiliateLinkRejected(this.reason, this.message);

  final AffiliateRejectionReason reason;
  final String message;
}

enum AffiliateRejectionReason {
  missingUrl,
  insecureScheme,
  hostNotAllowed,
  disclosureNotShown,
}

/// 외부 이동 시도 결과.
sealed class LinkOpenResult {
  const LinkOpenResult();
}

final class LinkOpened extends LinkOpenResult {
  const LinkOpened(this.destination);

  final Uri destination;
}

final class LinkOpenBlocked extends LinkOpenResult {
  const LinkOpenBlocked(this.decision);

  final AffiliateLinkRejected decision;
}

/// 현재 프로젝트에는 외부 브라우저를 여는 패키지가 없다.
/// TODO 주석 대신 명시적 결과로 표현해 UI가 정확한 안내를 하도록 한다.
final class LinkOpenNotSupported extends LinkOpenResult {
  const LinkOpenNotSupported(this.destination);

  final Uri destination;

  String get message => '이 빌드에서는 외부 브라우저 연결이 아직 준비되지 않았어요. 검색 문구를 복사해 사용해 주세요.';
}

/// 제휴 링크 이동 정책.
///
/// - https 링크만 허용한다.
/// - 목적지 host allowlist를 검증한다.
/// - 대가성 고지가 화면에 렌더링되지 않았으면 이동과 클릭 기록을 모두 거부한다.
class AffiliateLinkPolicy {
  const AffiliateLinkPolicy({this.allowedHosts = defaultAllowedHosts});

  /// MVP는 실제 제휴사 대신 mock host만 허용한다.
  static const Set<String> defaultAllowedHosts = <String>{'mock.giftmap.app'};

  static const String disclosureText =
      '제휴 링크를 통한 구매 시 판매 수수료를 받을 수 있어요. 가격과 재고는 판매처 기준입니다.';

  final Set<String> allowedHosts;

  AffiliateLinkDecision evaluate({
    required Uri? url,
    required bool disclosureShown,
  }) {
    if (url == null) {
      return const AffiliateLinkRejected(
        AffiliateRejectionReason.missingUrl,
        '연결할 수 있는 판매 페이지 정보가 없어요.',
      );
    }
    if (url.scheme != 'https') {
      return const AffiliateLinkRejected(
        AffiliateRejectionReason.insecureScheme,
        '안전하지 않은 링크라 열 수 없어요.',
      );
    }
    if (!allowedHosts.contains(url.host)) {
      return const AffiliateLinkRejected(
        AffiliateRejectionReason.hostNotAllowed,
        '허용되지 않은 판매처 주소예요.',
      );
    }
    if (!disclosureShown) {
      return const AffiliateLinkRejected(
        AffiliateRejectionReason.disclosureNotShown,
        '광고 고지가 표시되지 않아 이동할 수 없어요.',
      );
    }
    return AffiliateLinkAllowed(url);
  }

  /// 정책 통과 여부와 실제 이동 가능 여부를 분리해 돌려준다.
  LinkOpenResult open({required Uri? url, required bool disclosureShown}) {
    final AffiliateLinkDecision decision = evaluate(
      url: url,
      disclosureShown: disclosureShown,
    );
    return switch (decision) {
      AffiliateLinkRejected() => LinkOpenBlocked(decision),
      AffiliateLinkAllowed() => LinkOpenNotSupported(decision.destination),
    };
  }
}
