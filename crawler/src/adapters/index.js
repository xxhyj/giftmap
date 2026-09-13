import { aladinAdapter } from './aladin.js';
import { daisoAdapter } from './daiso.js';
import { musinsaAdapter } from './musinsa.js';
import { tenByTenAdapter } from './tenbyten.js';

/**
 * 공급원 레지스트리.
 *
 * 새 공급원을 추가하려면 `tenbyten.js` 와 같은 모양의 객체를 만들어
 * 아래 배열에 넣기만 하면 된다. 필요한 계약은 다음 네 가지다.
 *   id, label, origin, listingUrls, collectProductUrls(page, url, limit),
 *   discoverListings(rawItems), openDetail(page, url)
 *
 * 목록 렌더·링크 수집·페이지 넘기기는 `helpers.js` 를 함께 쓰면 된다.
 */
export const adapters = [
  tenByTenAdapter,
  musinsaAdapter,
  aladinAdapter,
  daisoAdapter,
];

export function adapterById(id) {
  return adapters.find((adapter) => adapter.id === id) ?? null;
}

export const adapterIds = adapters.map((adapter) => adapter.id);
