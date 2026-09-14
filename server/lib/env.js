/**
 * 환경변수를 읽는 곳.
 *
 * 값은 Vercel 프로젝트 환경변수에만 존재한다. 소스에는 이름만 있고 값은 없다.
 * 없는 값을 지어내지 않고, 없으면 없다고 말한다(호출한 쪽이 503 으로 답한다).
 */

/** 값이 없으면 null. 빈 문자열도 없는 것으로 본다. */
export function read(name, env = process.env) {
  const value = env[name];
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/** Supabase 접속 정보. 하나라도 없으면 null. */
export function supabaseEnv(env = process.env) {
  const url = read('SUPABASE_URL', env);
  const key =
    read('SUPABASE_SERVICE_ROLE_KEY', env) ?? read('SUPABASE_ANON_KEY', env);
  if (!url || !key) return null;
  return { url: url.replace(/\/+$/, ''), key };
}

/** OpenAI 접속 정보. 키가 없으면 null(추천은 앱의 로컬 엔진이 맡는다). */
export function openaiEnv(env = process.env) {
  const key = read('OPENAI_API_KEY', env);
  if (!key) return null;
  return { key, model: read('OPENAI_MODEL', env) ?? 'gpt-5-nano' };
}

/** 허용 출처 목록. 비어 있으면 모든 출처를 허용한다. */
export function allowedOrigins(env = process.env) {
  const raw = read('ALLOWED_ORIGINS', env);
  if (!raw) return [];
  return raw
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

/** 분당 추천 호출 허용 수. */
export function recommendRateLimit(env = process.env) {
  const raw = read('RECOMMEND_RATE_LIMIT_PER_MINUTE', env);
  const parsed = Number.parseInt(raw ?? '', 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 10;
}
