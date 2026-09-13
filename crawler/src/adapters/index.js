import { tenByTenAdapter } from './tenbyten.js';

/**
 * 공급원 레지스트리.
 *
 * 새 공급원을 추가하려면 `tenbyten.js` 와 같은 모양의 객체를 만들어
 * 아래 배열에 넣기만 하면 된다. 필요한 계약은 다음 네 가지다.
 *   id, label, origin, listingUrls, collectProductUrls(page, url, limit), openDetail(page, url)
 */
export const adapters = [tenByTenAdapter];

export function adapterById(id) {
  return adapters.find((adapter) => adapter.id === id) ?? null;
}

export const adapterIds = adapters.map((adapter) => adapter.id);
