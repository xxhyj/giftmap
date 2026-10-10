/**
 * 공급원 레지스트리.
 *
 * 텐바이텐·무신사·알라딘·다이소 Playwright 어댑터는 카카오톡 선물하기
 * PlayMCP 수집(`crawler/src/kakao/build.js`)으로 교체되어 제거했다.
 * 새 Playwright 공급원을 추가하려면 예전처럼 `id, label, origin, listingUrls,
 * collectProductUrls(page, url, limit), discoverListings(rawItems),
 * openDetail(page, url)` 계약을 구현한 객체를 아래 배열에 넣는다.
 */
export const adapters = [];

export function adapterById(id) {
  return adapters.find((adapter) => adapter.id === id) ?? null;
}

export const adapterIds = adapters.map((adapter) => adapter.id);
