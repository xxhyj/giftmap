# Giftmap

"누구에게 무엇을 선물해야 할지 모르겠다"는 순간에 조건을 몇 번 고르면
어울리는 선물 상품을 골라주는 모바일 앱.

현재 단계는 **API 연동 전 로컬 MVP**다. 네트워크 요청, 외부 AI, 서버, 실제 상품·제휴 연동은
포함하지 않으며 모든 추천은 기기 안에서 결정적으로 계산된다.

## 실행

```bash
flutter pub get
flutter run          # Android API 24+
```

## 검증

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## 구조

```
lib/
├── app/            # MaterialApp, AppScope(의존성), AppShell(바텀 탭), AppRouter
├── core/           # theme, 공통 위젯, 제휴 정책, 분석 이벤트, 실패 타입, 포맷 유틸
├── data/           # 번들 JSON: 카테고리 / 위험 규칙 / 검색어 템플릿 / 상품 카탈로그
└── features/       # feature-first: home, search, products, library,
                    #                gift_finder, history, anniversary, settings, splash
```

`gift_finder`는 `domain` → `data` → `application` → `presentation` 순서로 나뉜다.
점수 계산은 `LocalRecommendationEngine`에만 있고 화면은 계산하지 않는다.

## 추천 엔진

사용자에게 보이는 결과는 **상품**이다. 카테고리 방향을 먼저 정하고, 그 방향을 보너스로 반영해
상품을 점수화한다(`ProductRecommendationEngine`). 동점은 상품 id 오름차순이라
같은 입력은 항상 같은 상품·같은 순서를 만든다.

카테고리 방향(`LocalRecommendationEngine`)은 기본 40점에서 시작해 상황(0~20), 관계(0~15), 예산(0~15), 실용↔감성 거리(0~10)를 더하고
위험 규칙 패널티(0~50)를 뺀 뒤 0~100으로 제한한다.

- `avoidTags`와 겹치는 카테고리, 위험도 `avoid` 카테고리는 제외
- 상위 그룹당 1개만 골라 결과 다양성 확보
- 동점은 `categoryId` 오름차순 → 같은 입력은 항상 같은 순서
- 3개가 안 되면 `safeDefault` 카테고리로 보충
- 결과는 항상 서로 다른 카테고리 정확히 3개

## 데이터와 경계

- 카테고리 가격은 **데모 시세**이며 실시간 판매가가 아니다. UI 전반에 이 고지가 붙는다.
- 시세 근거가 없는 카테고리는 가격 필드가 `null`이고 화면에는 "가격 확인 필요"로 표시된다.
  `null`을 0원으로 표시하지 않는다.
- 상품 46종은 전부 데모 데이터이며 실제 브랜드·상품이 아니다. 화면에 DEMO 배지와 고지를 표시한다.
- 상품 이미지는 외부 URL을 쓰지 않는다. asset이 없으면 카테고리별 로컬 비주얼을 그린다.
- 찜과 최근 본 상품은 기기 로컬에 저장되어 앱을 다시 켜도 유지된다.
- 추천 기록과 기념일은 인메모리로 보관한다. 앱을 다시 켜면 비워진다.
- 상품 상세의 "상품 보러가기"는 데모 상태로 비활성화되어 있고, 이유를 버튼 위에 설명한다.
- 자연어 검색은 외부 AI 없이 로컬 키워드 파서만 사용하며, 신뢰도가 낮은 조건은
  사용자가 직접 고르도록 되묻는다.

## 다음 단계

`RecommendationRepository` 계약만 유지되어 있어, 이후 원격 구현을 같은 계약으로 추가하면 된다.
주입 지점은 `lib/app/giftmap_app.dart`의 `_bootstrap()` 한 곳이다.
