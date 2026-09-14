/**
 * Supabase REST(PostgREST) 를 읽는 얇은 클라이언트.
 *
 * 서버에서만 돈다. 키는 환경변수에서 오고 응답에 담지 않는다.
 * SDK 를 쓰지 않는 이유는 읽기 몇 개뿐이라 fetch 로 충분해서다.
 */

/** 호출 쪽이 상태 코드로 분기할 수 있게 하는 오류. */
export class UpstreamError extends Error {
  constructor(message, { status = 502, code = 'upstream_error' } = {}) {
    super(message);
    this.name = 'UpstreamError';
    this.status = status;
    this.code = code;
  }
}

export function createSupabase({ url, key, fetchImpl = fetch, timeoutMs = 10_000 }) {
  async function request(path, params, { range } = {}) {
    const target = new URL(`${url}/rest/v1/${path}`);
    for (const [name, value] of params ?? []) {
      target.searchParams.append(name, value);
    }

    const headers = { apikey: key, authorization: `Bearer ${key}` };
    if (range) headers.range = range;
    // 전체 개수를 같이 받아 hasMore 를 정확히 판단한다.
    if (range) headers.prefer = 'count=estimated';

    let res;
    try {
      res = await fetchImpl(target, {
        headers,
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (error) {
      throw new UpstreamError(`상품 저장소에 연결하지 못했습니다: ${error?.name ?? error}`, {
        status: 504,
        code: 'upstream_timeout',
      });
    }

    if (!res.ok) {
      throw new UpstreamError(`상품 저장소가 ${res.status} 를 돌려줬습니다.`, {
        status: res.status === 404 ? 404 : 502,
      });
    }

    let body;
    try {
      body = await res.json();
    } catch {
      throw new UpstreamError('상품 저장소 응답을 읽지 못했습니다.');
    }
    if (!Array.isArray(body)) {
      throw new UpstreamError('상품 저장소가 예상과 다른 모양을 돌려줬습니다.');
    }
    return { rows: body, contentRange: res.headers?.get?.('content-range') ?? null };
  }

  return { request };
}

/** `0-59/1886` 같은 헤더에서 전체 개수를 읽는다. 모르면 null. */
export function totalFromContentRange(value) {
  if (typeof value !== 'string') return null;
  const total = value.split('/')[1];
  if (!total || total === '*') return null;
  const parsed = Number.parseInt(total, 10);
  return Number.isFinite(parsed) ? parsed : null;
}
