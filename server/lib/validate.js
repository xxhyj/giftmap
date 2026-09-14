/**
 * 입력 검증.
 *
 * 들어온 값을 그대로 믿지 않는다. 숫자가 아니거나 범위를 벗어나면 기본값으로
 * 되돌리고, 문자열은 길이를 자른다. 검색어는 Supabase 필터 문법에서 뜻을
 * 갖는 문자를 걸러 낸다.
 */

export const MAX_LIMIT = 200;
export const DEFAULT_LIMIT = 60;
export const MAX_QUERY_LENGTH = 60;

function toInt(value) {
  if (Array.isArray(value)) value = value[0];
  if (typeof value === 'number') return Number.isFinite(value) ? Math.trunc(value) : null;
  if (typeof value !== 'string') return null;
  if (!/^-?\d{1,9}$/.test(value.trim())) return null;
  return Number.parseInt(value.trim(), 10);
}

/** page 는 1부터. 범위를 벗어난 값은 조용히 기본값으로 되돌린다. */
export function parsePaging(query = {}) {
  const page = toInt(query.page);
  const limit = toInt(query.limit);
  const safePage = page !== null && page >= 1 ? page : 1;
  const safeLimit =
    limit !== null && limit >= 1 ? Math.min(limit, MAX_LIMIT) : DEFAULT_LIMIT;
  return { page: safePage, limit: safeLimit, offset: (safePage - 1) * safeLimit };
}

function firstString(value) {
  if (Array.isArray(value)) value = value[0];
  return typeof value === 'string' ? value : null;
}

/** 분류 id. 영문·숫자·밑줄만 허용한다(DB 의 category_id 형식). */
export function parseCategory(query = {}) {
  const raw = firstString(query.category);
  if (!raw) return null;
  const trimmed = raw.trim();
  if (trimmed.length === 0 || trimmed.length > 40) return null;
  return /^[a-z0-9_]+$/i.test(trimmed) ? trimmed : null;
}

/**
 * 검색어.
 *
 * PostgREST 의 `ilike` 값에서 뜻을 갖는 문자(`,` `.` `(` `)` `*` `%` `\`)를
 * 지워 필터가 비틀리지 않게 한다. 너무 긴 입력은 자른다.
 */
export function parseQuery(query = {}) {
  const raw = firstString(query.query ?? query.q);
  if (!raw) return null;
  const cleaned = raw
    .replace(/[,.()*%\\"']/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, MAX_QUERY_LENGTH);
  return cleaned.length > 0 ? cleaned : null;
}

/**
 * 남겨도 되는 검색어인지 보고 다듬는다.
 *
 * 앱과 같은 기준이다. 20자를 넘거나 단어 셋을 넘으면 문장일 가능성이 높고,
 * 문장에는 개인적인 내용이 담기기 쉬워 아예 남기지 않는다(null).
 */
export function normalizeKeyword(raw) {
  const value = firstString(raw);
  if (!value) return null;
  const trimmed = value.trim().replace(/\s+/g, ' ');
  if (trimmed.length === 0 || trimmed.length > 20) return null;
  if (trimmed.split(' ').length > 3) return null;
  return trimmed.toLowerCase();
}

/** 검색 기록의 종류. 모르는 값은 검색으로 본다. */
export function parseKind(raw) {
  const value = firstString(raw);
  return value === 'click' ? 'click' : 'search';
}

/** 상품 id. 수집기가 붙이는 `<source>-<id>` 형식만 받는다. */
export function parseProductId(value) {
  const raw = firstString(value);
  if (!raw) return null;
  const trimmed = raw.trim();
  if (trimmed.length === 0 || trimmed.length > 120) return null;
  return /^[A-Za-z0-9_.:-]+$/.test(trimmed) ? trimmed : null;
}

// 앱이 보내는 값(RelationshipType·GiftSituation·AgeBand 의 wireName)과 같아야 한다.
// 여기 없는 값은 조건에서 빠지므로, 앱에 항목을 더하면 이 목록도 함께 고친다.
const RELATIONSHIPS = new Set([
  'partner', 'friend', 'family', 'colleague', 'manager', 'acquaintance',
]);
const SITUATIONS = new Set([
  'birthday', 'anniversary', 'promotion', 'thanks', 'housewarming',
  'birth', 'holiday', 'support', 'other',
]);
const AGE_BANDS = new Set([
  'teens', 'twenties', 'thirties', 'fortiesPlus', 'unspecified',
]);

/**
 * 추천 조건. 모르는 값은 버리고 아는 값만 남긴다.
 * 전부 비어 있어도 조건 없는 추천으로 동작한다.
 */
export function parseIntent(body = {}) {
  const intent = {};
  const relationship = firstString(body.relationship);
  if (relationship && RELATIONSHIPS.has(relationship)) intent.relationship = relationship;

  const situation = firstString(body.situation);
  if (situation && SITUATIONS.has(situation)) intent.situation = situation;

  const ageBand = firstString(body.ageBand);
  if (ageBand && AGE_BANDS.has(ageBand)) intent.ageBand = ageBand;

  const min = toInt(body.budgetMin);
  if (min !== null && min >= 0) intent.budgetMin = Math.min(min, 100_000_000);
  const max = toInt(body.budgetMax);
  if (max !== null && max >= 0) intent.budgetMax = Math.min(max, 100_000_000);
  if (
    typeof intent.budgetMin === 'number' &&
    typeof intent.budgetMax === 'number' &&
    intent.budgetMin > intent.budgetMax
  ) {
    // 뒤집힌 예산은 버린다. 그대로 쓰면 결과가 0건이 된다.
    delete intent.budgetMin;
    delete intent.budgetMax;
  }

  // 앱은 preference 를 0.0(실용적)~1.0(감성적) 실수로 보낸다.
  // 사람이 쓴 글이 올 수도 있어(다른 호출자) 둘 다 받아 둔다.
  const preference = body.preference;
  if (typeof preference === 'number' && Number.isFinite(preference)) {
    intent.preference = Math.min(1, Math.max(0, preference));
  } else if (typeof preference === 'string' && preference.trim().length > 0) {
    intent.preference = preference.trim().slice(0, 200);
  }

  if (Array.isArray(body.avoidTags)) {
    const tags = body.avoidTags
      .filter((tag) => typeof tag === 'string')
      .map((tag) => tag.trim().slice(0, 40))
      .filter(Boolean)
      .slice(0, 20);
    if (tags.length > 0) intent.avoidTags = tags;
  }
  return intent;
}
