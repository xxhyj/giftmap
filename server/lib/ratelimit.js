/**
 * 아주 단순한 호출 제한.
 *
 * OpenAI 호출은 돈이 들고 느리다. 한 사람이 연달아 부르는 것만 막으면 되므로
 * 함수 인스턴스 메모리에 분 단위로 센다. 인스턴스가 여러 개면 그만큼 느슨해지지만,
 * 저장소를 새로 두지 않고 얻을 수 있는 만큼의 보호다.
 */

const WINDOW_MS = 60_000;
const buckets = new Map();

/** 허용되면 `{ allowed: true }`, 아니면 남은 초를 함께 돌려준다. */
export function take(key, limitPerMinute, now = Date.now()) {
  if (buckets.size > 5000) buckets.clear(); // 메모리가 무한히 늘지 않게 한다.

  const bucket = buckets.get(key);
  if (!bucket || now >= bucket.resetAt) {
    buckets.set(key, { count: 1, resetAt: now + WINDOW_MS });
    return { allowed: true, remaining: limitPerMinute - 1 };
  }
  if (bucket.count >= limitPerMinute) {
    return {
      allowed: false,
      remaining: 0,
      retryAfterSeconds: Math.max(1, Math.ceil((bucket.resetAt - now) / 1000)),
    };
  }
  bucket.count += 1;
  return { allowed: true, remaining: limitPerMinute - bucket.count };
}

/** 테스트에서 상태를 비운다. */
export function resetForTest() {
  buckets.clear();
}
