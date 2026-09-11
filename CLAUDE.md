# CLAUDE.md — Giftmap 개발 기준

Claude Code가 이 저장소에서 작업할 때 항상 지켜야 할 기준이다.
제품 상세는 `docs/PRD.md`, 구조는 `docs/ARCHITECTURE.md`, UI는 `docs/DESIGN_SYSTEM.md`,
검증은 `docs/TESTING.md`를 따른다.

## 1. 프로젝트 목적

GiftMap(선물지도)은 기념일·생일처럼 선물을 골라야 하는 순간에, 상대방과의 관계·상황·예산·선호를
입력하면 어울리는 **선물 상품과 탐색 방향**을 추천하는 모바일 앱이다.
조건 입력 → 추천 → 상품 탐색 → 비교 → 찜 → 상세 확인으로 이어지는 커머스형 탐색 경험을 목표로 한다.
실제 결제·판매는 하지 않으며, 현재 상품 데이터는 전부 로컬 데모 데이터다.

## 2. 현재 개발 단계의 범위

이 단계의 목표는 **외부 AI/API 없이 Flutter 내부의 로컬 데이터와 결정론적 추천 로직만으로
핵심 사용자 흐름을 완성하는 것**이다.

포함:
- Flutter Stable / Dart null safety / Material 3 / Android API 24+
- 로컬 번들 JSON 데이터(카테고리 방향 + 상품 카탈로그)와 결정론적 추천 엔진
- 상품 검색 · 상품 상세 · 찜 · 최근 본 상품(로컬 저장)
- 로컬(인메모리) 추천 기록과 기념일
- 로컬 키워드 기반 자연어 파서

제외(이후 별도 명령으로 진행):
- OpenAI·ChatGPT·LLM 등 외부 AI API
- 서버, Supabase, Firebase, PostgreSQL, REST/GraphQL, 네트워크 요청
- 실제 상품 데이터·실시간 가격·재고·실제 제휴 링크·외부 이미지 URL
- 로그인/회원가입/결제/장바구니/배송
- Push Notification, 카메라, 관리자 CMS

## 3. 절대 금지

- 외부 AI/API/서버/DB 코드, 그리고 "나중을 위한" 빈 API client·서버 스텁 작성
- API Key·Secret·인증정보를 앱 코드나 asset에 포함
- 새 dependency 임의 추가 (특히 AI/API/서버/DB 관련), code generation 도입
- `flutter clean`, `git reset --hard`, 프로젝트 삭제·재생성
- 기존 기능 삭제나 주석 처리로 오류 숨기기
- 알 수 없는 가격을 0원으로 표시하기
- 화면(presentation) 파일에서 추천 점수 계산하기

## 4. 아키텍처 원칙

- **feature-first**: `lib/features/<feature>/{domain,data,application,presentation}`
- 공통 토큰·위젯·정책은 `lib/core`, 앱 조립은 `lib/app`
- 의존 방향은 presentation → application → domain, data는 domain 계약을 구현한다
- 상태 관리는 `ChangeNotifier` + `InheritedWidget`(`AppScope`)만 사용한다. 상태관리 패키지 금지
- 로컬 저장은 `IdListStorage` 계약을 통해서만 접근한다(현재 구현: shared_preferences / 인메모리)
- 라우팅은 `Navigator` + `MaterialPageRoute` (`lib/app/app_router.dart`). 라우팅 패키지 금지
- 저장소는 인터페이스로 추상화한다. 현재 구현체는 Mock/InMemory뿐이다
- 과도한 추상화 금지. 계층은 실제로 필요한 만큼만 만든다

## 5. 추천 엔진 원칙

점수 로직은 `lib/features/gift_finder/data/`의 두 엔진에만 존재한다.
`LocalRecommendationEngine`이 카테고리(선물 방향)를, `ProductRecommendationEngine`이 상품을 고른다.

### 5-1. 카테고리 방향

```
base                 40
situation match    0..20
relationship match 0..15
budget fit         0..15
preference distance 0..10
risk penalty      0..-50
avoidTags 충돌        제외
riskLevel == avoid    제외
최종 점수          0..100
```

- 동점은 `categoryId` 오름차순 → **같은 입력은 항상 같은 순서**
- 결과는 서로 다른 카테고리 **정확히 3개**, 상위 그룹당 1개로 다양성 확보
- 3개 미만이면 `safeDefault` 카테고리로 보충

### 5-2. 상품 추천 (사용자에게 보이는 결과)

```
base                 30
occasion match     0..25
recipient match    0..20
budget fit         0..25   (예산 초과 시 크게 감점)
preference match   0..10
age match          0..5
direction bonus    0..12   (카테고리 방향 1/2/3위 = 12/8/5)
risk penalty      0..-50
avoidTags 충돌        제외
riskLevel == avoid    제외
최종 점수          0..100
```

- 동점은 **상품 id 오름차순** → 같은 입력은 항상 같은 상품·같은 순서
- 결과는 상품 단위이며 같은 상품을 중복 추천하지 않는다
- 조건이 좁아 3개 미만이면 예산에 맞는 안전한 상품으로 보충한다

## 6. 데이터 원칙

- 카테고리·위험 규칙·검색어 템플릿·상품 카탈로그는 `lib/data/*.json` 번들 asset이다
- 상품은 전부 `isDemo: true`인 **데모 데이터**이며, 실제 브랜드·상품·시세가 아니다
- 상품 이미지는 외부 URL을 쓰지 않는다. asset이 없으면 카테고리별 로컬 비주얼을 그린다
- 가격은 **Demo/Mock 시세**이며 UI에 항상 고지를 표시한다
- 시세 근거가 없으면 가격 필드는 `null`이고 화면에는 "가격 확인 필요"로 표시한다
- 번들 데이터가 손상되면 예외를 던지지 않고 안전한 기본 카테고리 세트로 진입한다

## 7. UI 원칙

- Premium하되 부담 없는, 따뜻하고 친근한 인상. 과도한 카드·그라디언트·그림자·AI 느낌 금지
- 한 손 사용 기준: 주요 CTA는 하단, 높이 56dp, 최소 터치 영역 48dp
- 본문 최소 15sp, 캡션 13sp, 명확한 타이포그래피 계층과 충분한 여백
- 색상만으로 상태를 전달하지 않는다(적합도·위험도는 수치·라벨·아이콘 병행)
- Text Scale 1.3배에서도 overflow가 없어야 한다
- 코랄 accent는 주요 CTA와 선택 상태에만 사용한다
- 상품 화면은 이미지가 가장 먼저 인식되어야 한다. 텍스트가 이미지를 압도하지 않는다
- 가격은 강한 위계로 표시하고, 할인 정보는 할인율 → 판매가 → 정가 순으로 읽히게 한다

## 8. 작업 절차

모든 작업 단위에서 다음 순서를 지킨다.

1. 현재 프로젝트 상태 확인 (파일을 먼저 읽는다)
2. 계획 수립
3. 구현 (작은 단위로)
4. `dart format lib test`
5. `flutter analyze`
6. 관련 `flutter test`
7. 에뮬레이터/시뮬레이터에서 작은 단위 실행 확인

최종 검증:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

오류를 남긴 채 다음 기능으로 넘어가지 않는다. 원인을 분석하고 수정한 뒤 다시 검증한다.

## 9. 개발 환경

- 메인 IDE는 Cursor이며 프로젝트 개발은 Claude Code가 수행한다
- Android Studio는 개발 IDE로 사용하지 않는다 (SDK/에뮬레이터 관리 용도만)
- Android Gradle 파일, SDK/JDK/PATH를 임의로 수정하지 않는다

## 10. 문서 유지

기능을 추가·변경하면 관련 문서(`docs/`)와 `README.md`를 같은 작업에서 갱신한다.
문서는 **현재 저장소의 실제 상태**만 기술한다. 미구현 기능을 구현된 것처럼 쓰지 않는다.
