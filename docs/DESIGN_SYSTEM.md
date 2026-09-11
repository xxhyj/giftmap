# Design System — Giftmap

이 문서의 값은 `lib/core/theme/`와 `lib/core/widgets/`의 실제 구현과 일치한다.
값을 바꿀 때는 토큰 파일을 먼저 수정하고 이 문서를 함께 갱신한다.

## 1. 브랜드 디자인 방향

- 따뜻하고 친근하되, 선물 서비스다운 단정함과 프리미엄한 인상
- 광고처럼 보이지 않는 중립 배경 + 절제된 코랄 accent
- 한 손 사용 우선: 주요 CTA는 하단, 스크롤은 세로 한 방향
- 금지: 과도한 그라디언트, 짙은 그림자, 카드 남발, 기계적인 AI 느낌의 UI

## 2. 컬러 시스템 (`app_colors.dart`)

빨간색 중심 팔레트를 걷어내고, **차분한 딥 그린(primary) + 따뜻한 클레이(accent)**
조합으로 바꿨다. 배경은 상품 이미지와 경쟁하지 않는 따뜻한 오프화이트다.

| 토큰 | 값 | 역할 |
|---|---|---|
| `primary` | `#2E5D4B` | 주요 CTA, 선택 상태, 브랜드 워드마크 |
| `onPrimary` | `#FFFFFF` | primary 위 텍스트 |
| `primaryContainer` | `#DCE8E1` | 배너·추천 이유 블록, 내비 인디케이터 |
| `onPrimaryContainer` | `#16352A` | primaryContainer 위 텍스트 |
| `accent` | `#C0714F` | 찜 활성, 할인율 — 절제된 포인트 |
| `accentContainer` | `#F7E7DE` | 추천 배지 배경 |
| `onAccentContainer` | `#6B3721` | 배지 텍스트 |
| `background` | `#FBF9F6` | 화면 바탕(따뜻한 오프화이트) |
| `surface` | `#FFFFFF` | 카드·입력·내비게이션 |
| `surfaceVariant` | `#F3F0EB` | 칩·스켈레톤·보조 블록 |
| `textPrimary` | `#1E2422` | 제목·본문 |
| `textSecondary` | `#5F6B66` | 보조 텍스트 |
| `textTertiary` | `#8A938F` | 캡션·비활성 아이콘 |
| `outline` | `#E3DED6` | 얇은 경계선 |
| `outlineStrong` | `#CFC8BE` | 버튼 테두리 |
| `error` | `#B3261E` | **오직 오류·파괴적 행동** |
| `success` / `warning` | `#2F6D4F` / `#8A5A00` | 위험도 표기 보조 |

- `ColorScheme.fromSeed(primary)` 위에 위 값을 덮어써 Material 3 스킴을 만든다.
- **색상만으로 의미를 전달하지 않는다.** 탭 선택은 아이콘 채움+굵기, 찜은 하트 채움,
  캐러셀 버튼 비활성은 semantics로 함께 전달한다.
- 본문 대비는 WCAG AA(4.5:1) 이상을 목표로 한다.

## 3. Typography (`app_text_styles.dart`)

| 스타일 | 크기/두께 | 용도 |
|---|---|---|
| displaySmall | 30 / w700 | 홈 히어로 |
| headlineMedium | 26 / w700 | 스플래시 브랜드 |
| headlineSmall | 22 / w700 | 화면 제목, 시트 제목 |
| titleLarge | 19 / w700 | 추천 카드 제목, AppBar |
| titleMedium | 17 / w600 | 섹션 제목, 목록 제목 |
| bodyLarge | 16 / w400 | 본문 |
| bodyMedium | 15 / w400 | 보조 본문 (최소 본문 크기) |
| labelLarge | 16 / w600 | 버튼 |
| labelMedium | 14 / w600 | 칩, 라벨 |
| labelSmall | 13 / w500 | 캡션, 고지 |

행간은 1.2~1.5를 사용한다. 본문 15sp 미만은 쓰지 않는다.

## 4. Spacing & Radius (`app_spacing.dart`)

```
xs 4 · sm 8 · md 16 · lg 24 · xl 32
screen 20        화면 좌우 기본 여백
bottomAction 96  하단 CTA 영역을 가리지 않기 위한 리스트 하단 패딩
minTouchTarget 48 · primaryButtonHeight 56
```

```
radius(app_radius.dart): xs 8 · button 12 · card 16 · xl 20 · sheet 24 · chip 999
```

`AppSpacing.screen`은 16(8pt 배수), `maxContentWidth`는 720이다.

## 5. Button

- **Primary** `FilledButton`: 높이 56dp, radius 16, labelLarge. 화면당 하나의 주요 행동에만 사용
- **Secondary** `FilledButton.tonal`: 카드 내부의 주 행동("자세히")
- **Tertiary** `OutlinedButton`: 보조 행동, 최소 48×48dp, outline 테두리
- **Text** `TextButton`: 링크성 행동(전체 보기, 조건 수정), 색상은 `brandCoralDark`
- 비활성 상태는 Material 기본 disabled를 쓰고, **왜 비활성인지 버튼 아래에 문장으로 설명한다**
  (예: 상품 이동 버튼의 Mock 상태 안내)

## 6. Input

- `TextField`는 `surfaceMuted` 채움, 테두리 없음, radius 16, 포커스 시 코랄 2dp
- 오류는 `errorText`로 필드 바로 아래에 표시하고 테두리를 `riskAvoid`로 바꾼다
- 숫자 입력(예산)은 `digitsOnly` 포맷터와 `helperText`로 허용 범위를 함께 안내한다

## 7. Card / Surface

- `RoundedSurface`: 배경 + 1dp outline + radius 20. **그림자를 쓰지 않는다**
- `NoticeBlock`: `surfaceMuted` 배경 + 아이콘 + labelSmall. 고지·안내 전용
- 카드는 "의미 단위"에만 쓴다. 목록 전체를 카드로 감싸 나열하지 않는다

## 8. Chip

- `SelectableChip`: radius 999, 최소 높이 48dp, 선택 시 코랄 배경 + 체크 아이콘 + w700
  (색상 외 신호를 반드시 동반)
- `ReadOnlyChip`: 조건 요약처럼 탭할 수 없는 칩. 버튼 semantics를 붙이지 않는다
- `ChipWrap`: `Wrap`으로 줄바꿈해 텍스트 확대에서도 넘치지 않게 한다

## 9. Navigation

- `NavigationBar` 5탭(홈 / 카테고리 / 선물추천 / 찜 / 기록), 높이 66,
  인디케이터는 `primaryContainer`
- 선택 상태는 색 + 채워진 아이콘 + label weight(w700)로 함께 전달한다
- 5개 라벨이 작은 화면에서도 잘리지 않도록 라벨 크기를 11.5sp로 두고 항상 표시한다
- 모든 destination에 tooltip(= semantic label)을 준다
- 선택 아이콘은 채움(filled), 비선택은 외곽선(outlined)으로 형태까지 바꾼다
- AppBar는 elevation 0, 배경 `surface`, 왼쪽 정렬 제목

## 10. Bottom Sheet

- radius 28(상단만), 드래그 핸들 표시, `useSafeArea: true`
- 상세 시트는 `DraggableScrollableSheet`(초기 0.75 / 최소 0.5 / 최대 0.95)
- 시트 안의 긴 내용은 스크롤되며, 고지는 링크 버튼과 **같은 뷰 트리**에 항상 존재해야 한다

## 11. Loading / Analyzing

- 스플래시: 브랜드 + 코랄 원형 인디케이터. 인위적 지연을 넣지 않는다
- 분석 화면: 3단계 체크리스트가 순차적으로 채워지는 형태
- `MediaQuery.disableAnimations`가 켜져 있으면 애니메이션 없이 최종 상태를 바로 보여준다
- 로컬 계산은 즉시 끝나므로 진행 표시는 "기다림"이 아니라 "무엇을 검토했는지"를 전달한다

## 12. 상품 표현

상품 화면의 위계는 **이미지 → 상품명 → 브랜드 → 가격 → 할인 → 추천 이유 → 찜** 순이다.

- `ProductImage`: 1:1 비율. `imageAsset`이 없으면 카테고리별 색·아이콘으로 그린다
  (외부 URL을 쓰지 않는다). 카드에서 가장 먼저 인식되는 요소다.
- `ProductGridCard`: 2열 그리드용. 이미지 위에 찜 버튼과 DEMO 배지를 얹는다.
- `ProductTileCard`: 가로 캐러셀용(기본 폭 156).
- `ProductRowCard`: 목록형. 88 폭 썸네일 + 정보 + 찜.
- `ProductPrice`: 할인이 있으면 `할인율 → 판매가 → 정가(취소선)` 순서로 읽힌다.
- 추천 배지는 코랄 10% 틴트의 작은 칩 하나로 제한한다.
- 상품 카드에는 테두리와 그림자를 쓰지 않는다. 이미지와 여백으로 구분한다.

### Result UI

- 상단에 조건 요약(제목 + 예산·성향·개수) → "이런 선물을 추천해요" 이유 블록
- 그 아래 추천 상품 2열 그리드(기본 8개, "추천 상품 더 보기"로 확장)
- 회피 조건이 있으면 제외 칩으로 함께 보여준다
- 마지막에 데모 데이터 고지

### 홈 섹션과 캐러셀

- 홈은 콤팩트한 선물추천 배너 → 상황 빠른 시작 → 큐레이션 캐러셀 순으로 쌓인다
- 캐러셀은 `PageView`(viewportFraction)로 손가락 스와이프를 지원하고,
  다음 카드가 살짝 보이도록 viewport를 카드보다 좁게 잡는다
- 섹션 머리글(`CarouselSectionHeader`)에 둥근 이전/다음 버튼을 둔다.
  첫 페이지에서 이전, 마지막에서 다음이 비활성이며 스와이프 상태와 동기화된다
- 각 캐러셀은 자신의 `PageController`를 가지며 화면 폭이 바뀌면 다시 만든다
- 상품 0개면 섹션 자체를 그리지 않고, 1개면 화살표가 비활성이다

## 13. Empty / Loading / Error State

- `EmptyStateView`: 원형 아이콘 + 제목 + 설명 + (선택) 행동 버튼
- 검색 결과 없음, 찜 없음, 최근 본 상품 없음, 추천 기록 없음, 기념일 없음, 추천 실패에
  같은 형태를 사용한다
- 검색 결과가 없을 때는 추천 검색어 칩을 함께 제공한다
- 로딩은 스피너 대신 `SkeletonBox` / `ProductGridSkeleton`으로 상품 자리를 먼저 잡는다
- 오류 문구는 원인을 탓하지 않고 다음 행동을 제시한다

## 14. Accessibility

- 최소 터치 영역 48×48dp, 주요 CTA 56dp
- 적합도는 `Semantics(label: '적합도 100점 만점에 N점')`으로 읽히게 한다
- 선택 칩은 `selected` semantics를 제공한다
- 모든 아이콘 버튼에 `tooltip`을 지정한다
- Text Scale 1.3배에서 overflow가 없어야 하며, 이는 위젯 테스트로 검증한다

## 15. Responsive / Mobile Layout

- 세로 모바일 우선. 좌우 여백은 `AppSpacing.screen`(20)으로 통일한다
- 가로 나열은 `Row` 대신 `Wrap`을 우선한다. 길이가 변하는 텍스트는 `Expanded`/`Flexible`로 감싼다
- 리스트 하단에는 `bottomAction`(96) 패딩을 둬 하단 바에 내용이 가리지 않게 한다
- 고정 높이 대신 내용 기반 높이를 사용한다. 텍스트 확대 시 줄바꿈을 허용한다
