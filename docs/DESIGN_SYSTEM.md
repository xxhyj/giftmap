# Design System — Giftmap

이 문서의 값은 `lib/core/theme/`와 `lib/core/widgets/`의 실제 구현과 일치한다.
값을 바꿀 때는 토큰 파일을 먼저 수정하고 이 문서를 함께 갱신한다.

## 1. 브랜드 디자인 방향

- 따뜻하고 친근하되, 선물 서비스다운 단정함과 프리미엄한 인상
- 광고처럼 보이지 않는 중립 배경 + 절제된 코랄 accent
- 한 손 사용 우선: 주요 CTA는 하단, 스크롤은 세로 한 방향
- 금지: 과도한 그라디언트, 짙은 그림자, 카드 남발, 기계적인 AI 느낌의 UI

## 2. 컬러 시스템 (`app_colors.dart`)

| 토큰 | 값 | 용도 |
|---|---|---|
| `brandCoral` | `#F4635A` | 주요 CTA, 선택 상태, 진행률 |
| `brandCoralDark` | `#C94840` | 브랜드 텍스트, 텍스트 버튼, D-day |
| `ink` | `#1B1A1F` | 본문·제목 |
| `inkMuted` | `#5C5A66` | 보조 텍스트, 비활성 아이콘 |
| `surface` | `#FFFFFF` | 기본 배경 |
| `surfaceMuted` | `#F5F4F7` | 칩·입력·고지 블록 배경 |
| `outline` | `#DDDAE3` | 경계선 |
| `riskSafe` | `#1F7A4D` | 위험도 safe |
| `riskCaution` | `#8A5A00` | 위험도 caution |
| `riskAvoid` | `#9B1C1C` | 위험도 avoid, 입력 오류 |

- `ColorScheme.fromSeed(brandCoral)` 위에 위 값들을 덮어써 Material 3 스킴을 만든다.
- **색상만으로 의미를 전달하지 않는다.** 위험도는 아이콘+라벨, 적합도는 점 5개+수치를 병행한다.
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
radius: chip 999 · button 16 · card 20 · sheet 28
```

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

- `NavigationBar` 3탭(홈 / 선물 찾기 / 보관함), 높이 68, 인디케이터는 코랄 14% 틴트
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

### 홈 섹션

- 가로 캐러셀(인기·가격대·관계·상황)과 2열 그리드(큐레이션)를 번갈아 써 단조로움을 피한다
- 섹션 머리글은 `SectionTitleRow`로 통일하고, 필요할 때만 "더 보기"를 붙인다

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
