/**
 * 수집 결과를 Supabase `products` 행으로 바꾼다.
 *
 * 규칙
 * - 가격을 확인하지 못하면 `price` 는 null 이다. 0 원으로 만들지 않는다.
 * - 수집한 상품은 `is_demo = false` 로 데모 데이터와 구분한다.
 * - 같은 입력은 항상 같은 행이 되도록 추측·난수를 쓰지 않는다.
 */

/** 카테고리 추정에 쓰는 키워드 표. 앞에 있는 규칙이 이긴다. */
const CATEGORY_RULES = [
  ['perfume', ['향수', '퍼퓸', '오드', 'perfume', '코롱']],
  ['candle', ['캔들', '디퓨저', '인센스', '룸스프레이', 'candle']],
  ['hand_care', ['핸드크림', '핸드워시', '핸드케어', '핸드밤']],
  ['body_care', ['바디', '입욕', '보디', '샤워', '배스']],
  ['beauty', ['뷰티', '립', '스킨케어', '화장품', '마스크팩', '세럼']],
  ['tea_coffee', ['티백', '홍차', '녹차', '커피', '원두', '드립', '티팟', '찻잔']],
  ['dessert', ['쿠키', '초콜릿', '초콜렛', '디저트', '케이크', '마카롱', '수제잼', '푸딩']],
  ['tumbler', ['텀블러', '보온병', '머그', '물병', '보틀']],
  ['stationery', ['노트', '다이어리', '펜', '문구', '캘린더', '달력', '스티커', '메모']],
  ['desk', ['데스크', '오거나이저', '연필꽂이', '마우스패드', '조명', '램프']],
  ['homewear', ['잠옷', '파자마', '홈웨어', '가운', '슬리퍼']],
  ['wallet', ['지갑', '카드지갑', '카드케이스', '머니클립']],
  ['shoes', ['운동화', '스니커즈', '구두', '샌들', '부츠', '슬리퍼', '로퍼']],
  ['bag', ['가방', '백팩', '숄더백', '토트백', '크로스백', '파우치', '지갑가방']],
  ['fashion_accessory', ['목걸이', '팔찌', '귀걸이', '반지', '스카프', '머플러', '키링', '시계', '모자', '벨트']],
  ['fashion_clothing', ['티셔츠', '맨투맨', '후드', '니트', '셔츠', '코트', '자켓', '재킷', '블루종', '패딩', '바지', '팬츠', '청바지', '원피스', '스커트', '롱슬리브', '스웨트', '카디건', '점퍼']],
  ['book', ['도서', '책', '소설', '에세이', '시집', '문고', '전집']],
  ['music', ['음반', 'cd', 'lp', '앨범', '바이닐']],
  ['living', ['수건', '타월', '쿠션', '담요', '블랭킷', '식기', '컵', '그릇', '주방']],
  ['hobby', ['퍼즐', '보드게임', '키트', '취미', '엽서', '포스터', '피규어']],
];

const DEFAULT_CATEGORY = 'hobby';

/** 카테고리별 기본 상황·관계. 실제 판매 페이지에는 이 정보가 없어 카테고리로 정한다. */
const CATEGORY_CONTEXT = {
  perfume: { occasions: ['birthday', 'anniversary'], recipients: ['partner', 'friend'] },
  candle: { occasions: ['housewarming', 'thanks'], recipients: ['friend', 'acquaintance'] },
  hand_care: { occasions: ['thanks', 'holiday'], recipients: ['colleague', 'acquaintance'] },
  body_care: { occasions: ['birthday', 'thanks'], recipients: ['friend', 'family'] },
  beauty: { occasions: ['birthday'], recipients: ['friend', 'partner'] },
  tea_coffee: { occasions: ['thanks', 'holiday'], recipients: ['colleague', 'manager'] },
  dessert: { occasions: ['birthday', 'thanks'], recipients: ['friend', 'colleague'] },
  tumbler: { occasions: ['promotion', 'thanks'], recipients: ['colleague', 'friend'] },
  stationery: { occasions: ['promotion', 'support'], recipients: ['colleague', 'friend'] },
  desk: { occasions: ['promotion', 'housewarming'], recipients: ['colleague', 'manager'] },
  homewear: { occasions: ['birthday', 'anniversary'], recipients: ['partner', 'family'] },
  wallet: { occasions: ['birthday', 'promotion'], recipients: ['partner', 'family'] },
  fashion_accessory: { occasions: ['birthday', 'anniversary'], recipients: ['partner', 'friend'] },
  living: { occasions: ['housewarming', 'holiday'], recipients: ['family', 'acquaintance'] },
  hobby: { occasions: ['birthday', 'support'], recipients: ['friend', 'acquaintance'] },
  fashion_clothing: { occasions: ['birthday', 'anniversary'], recipients: ['partner', 'family'] },
  bag: { occasions: ['birthday', 'promotion'], recipients: ['partner', 'family'] },
  shoes: { occasions: ['birthday', 'anniversary'], recipients: ['partner', 'friend'] },
  book: { occasions: ['birthday', 'support'], recipients: ['friend', 'colleague'] },
  music: { occasions: ['birthday', 'thanks'], recipients: ['friend', 'partner'] },
};

/** 태그는 회피 태그와 같은 어휘를 쓴다(앱의 riskRules 와 맞물린다). */
const TAG_RULES = [
  ['scent', ['향수', '캔들', '디퓨저', '퍼퓸', '인센스', '룸스프레이']],
  ['food', ['쿠키', '초콜릿', '디저트', '커피', '홍차', '녹차', '티백', '케이크', '간식']],
  ['sizing', ['잠옷', '파자마', '홈웨어', '슬리퍼', '반지', '장갑']],
  ['strongTaste', ['위스키', '와인', '전통주', '매운']],
];

/**
 * schema.org 의 availability 를 재고 여부로 바꾼다.
 * 알려주지 않으면 null 이다. 품절로 단정하지 않는다.
 */
export function readStock(availability) {
  if (typeof availability !== 'string' || availability.trim() === '') return null;
  const value = availability.toLowerCase();
  if (/(outofstock|soldout|discontinued)/.test(value)) return false;
  if (/(instock|onlineonly|limitedavailability|preorder|backorder|instoreonly)/.test(value)) {
    return true;
  }
  return null;
}

/**
 * 공급원이 달라도 같은 상품이면 같은 값이 나오는 키.
 *
 * 브랜드와 상품명에서 옵션·수량·판촉 문구를 걷어내고 남은 글자만 쓴다.
 * 완벽한 동일성 판정이 아니라 "같은 상품이 여러 번 보이는 것"을 줄이는 장치다.
 */
export function dedupeKey(brand, name) {
  const strip = (value) =>
    (value ?? '')
      .toLowerCase()
      // [단독], (2종 선택) 같은 괄호 표기와 1+1 판촉 문구를 지운다.
      .replace(/[[(<{][^\])>}]*[\])>}]/g, ' ')
      .replace(/\d+\s*\+\s*\d+/g, ' ')
      .replace(/[^0-9a-z가-힣]+/g, '');

  const brandKey = strip(brand);
  let nameKey = strip(name);
  // 상품명이 브랜드로 시작하면 한 번만 남긴다(공급원마다 표기가 달라서다).
  if (brandKey && nameKey.startsWith(brandKey)) {
    nameKey = nameKey.slice(brandKey.length);
  }
  const key = `${brandKey}${nameKey}`;
  return key.length > 0 ? key : null;
}

export function priceBand(price) {
  if (price === null || price === undefined) return 'custom';
  if (price <= 10000) return 'under10k';
  if (price <= 30000) return 'from10kTo30k';
  if (price <= 50000) return 'from30kTo50k';
  if (price <= 100000) return 'from50kTo100k';
  return 'over100k';
}

export function guessCategory(haystack, fallback = DEFAULT_CATEGORY) {
  const text = (haystack || '').toLowerCase();
  for (const [id, keywords] of CATEGORY_RULES) {
    if (keywords.some((word) => text.includes(word.toLowerCase()))) return id;
  }
  return fallback;
}

function guessTags(haystack) {
  const text = (haystack || '').toLowerCase();
  return TAG_RULES.filter(([, words]) =>
    words.some((word) => text.includes(word.toLowerCase())),
  ).map(([tag]) => tag);
}

/**
 * 수집 결과 하나를 `products` 행으로 만든다.
 * 필수값(상품명·상품 URL)이 없으면 null 을 돌려주고 호출자가 건너뛴다.
 */
export function toProductRow(raw, { sourceId, sourceLabel, collectedAt, categoryHint }) {
  const name = clean(raw.name);
  const productUrl = clean(raw.productUrl);
  if (!name || !productUrl) return null;

  const sourceProductId = clean(raw.sku) ?? hashId(productUrl);
  const price = positive(raw.price);
  const listPrice = positive(raw.listPrice);
  const discounted = price !== null && listPrice !== null && listPrice > price;
  // 분류·태그 판단에는 브랜드명과 배송 안내가 섞인 설명을 넣지 않는다.
  // (브랜드명이 상품 성격과 무관한 경우가 많다. 예: "잼몬스터" 마우스패드)
  const breadcrumb = (raw.breadcrumb ?? []).filter(Boolean).join(' ');
  const haystack = [breadcrumb, name, ...(raw.keywords ?? [])].filter(Boolean).join(' ');
  // 공급원이 붙인 분류(breadcrumb)를 가장 믿고,
  // 없으면 어댑터가 목록에서 넘긴 힌트, 그다음 상품명·키워드 순으로 본다.
  const category =
    guessCategory(breadcrumb, null) ??
    categoryHint ??
    guessCategory(haystack);
  const context = CATEGORY_CONTEXT[category] ?? CATEGORY_CONTEXT[DEFAULT_CATEGORY];

  return {
    id: `${sourceId}-${sourceProductId}`,
    brand_name: clean(raw.brand),
    product_name: name,
    category_id: category,
    sub_category: clean(raw.breadcrumb?.at(-1)) ?? '',
    price,
    original_price: discounted ? listPrice : null,
    discount_rate: discounted
      ? Math.max(1, Math.min(99, Math.round(((listPrice - price) / listPrice) * 100)))
      : null,
    image_asset: null,
    image_url: clean(raw.imageUrl),
    product_url: productUrl,
    tags: guessTags(haystack),
    occasions: context.occasions,
    recipient_types: context.recipients,
    gender_target: null,
    age_range: [],
    price_range: priceBand(price),
    recommendation_keywords: (raw.keywords ?? []).map(clean).filter(Boolean).slice(0, 8),
    description: shortDescription(raw.description),
    recommendation_reason: `${sourceLabel}에서 공개된 정보를 그대로 옮긴 실제 판매 상품이에요.`,
    in_stock: readStock(raw.availability),
    dedupe_key: dedupeKey(raw.brand, name),
    is_demo: false,
    is_active: true,
    sort_order: 0,
    source: sourceId,
    source_product_id: sourceProductId,
    source_url: productUrl,
    collected_at: collectedAt,
  };
}

/**
 * 설명에서 배송·결제 안내를 떼어낸다.
 * 공급원 설명에는 가격·배송비 안내가 붙어 있어 그대로 두면 화면에서 읽히지 않는다.
 */
function shortDescription(value) {
  const text = clean(value);
  if (!text) return '';
  const cut = text.split(/판매가:|배송구분:|배송비 안내:/)[0];
  return clean(cut) ?? '';
}

function clean(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.replace(/\s+/g, ' ').trim();
  return trimmed.length > 0 ? trimmed : null;
}

function positive(value) {
  return typeof value === 'number' && Number.isFinite(value) && value > 0
    ? Math.round(value)
    : null;
}

/** sku 가 없을 때 URL 로 안정적인 id 를 만든다(같은 URL = 같은 id). */
function hashId(url) {
  let hash = 0;
  for (let i = 0; i < url.length; i += 1) {
    hash = (hash * 31 + url.charCodeAt(i)) >>> 0;
  }
  return hash.toString(36);
}
