import { readJsonLd } from '../extract.js';

/**
 * 텐바이텐(10x10) 어댑터.
 *
 * robots.txt 가 우리 User-Agent(ClaudeBot 계열)에게 `/shopping/`, `/category/`,
 * `/search/` 를 허용한다. 이 어댑터는 그 경로 안에서만 움직이며
 * 로그인·회원 영역(`/login/`, `/member/`, `/my10x10/`)에는 접근하지 않는다.
 *
 * 목록은 자바스크립트로 그려지므로 Playwright 로 렌더한 뒤 상품 링크를 모으고,
 * 상세 페이지에서 JSON-LD(Product/Offer)를 읽는다.
 */
export const tenByTenAdapter = {
  id: '10x10',
  label: '텐바이텐',
  origin: 'https://www.10x10.co.kr',

  /**
   * 수집 시작점. 공개 카테고리 목록 페이지다.
   * 한 카테고리에 몰리지 않도록 상위 분류를 고루 넣는다(`disp` 는 10x10 의 분류 코드).
   */
  listingUrls: [
    101, 102, 103, 104, 106, 107, 109, 110, 111, 112,
  ].map((disp) => `https://www.10x10.co.kr/shopping/category_list.asp?disp=${disp}`),

  /**
   * 목록 페이지에서 상품 상세 URL 을 모은다.
   *
   * 목록도 JSON-LD `ItemList` 로 공개돼 있어 그것을 먼저 읽고,
   * 없을 때만 DOM 의 링크를 본다.
   */
  async collectProductUrls(page, listingUrl, limit) {
    await page.goto(listingUrl, { waitUntil: 'domcontentloaded', timeout: 45_000 });
    await page.waitForTimeout(1_500);

    const nodes = await readJsonLd(page);
    const fromList = nodes
      .filter((node) => node['@type'] === 'ItemList' || node.mainEntity?.['@type'] === 'ItemList')
      .flatMap((node) => (node.mainEntity ?? node).itemListElement ?? [])
      .map((item) => item?.url ?? item?.item?.['@id'] ?? item?.item)
      .filter((url) => typeof url === 'string' && url.includes('category_prd.asp'));

    const hrefs =
      fromList.length > 0
        ? fromList
        : await page.$$eval('a[href*="category_prd.asp"]', (anchors) =>
            anchors.map((a) => a.href),
          );

    const seen = new Set();
    const urls = [];
    for (const href of hrefs) {
      const itemId = new URL(href).searchParams.get('itemid');
      if (!itemId || seen.has(itemId)) continue;
      seen.add(itemId);
      // 추적 파라미터를 떼어 항상 같은 URL 로 만든다.
      urls.push(`${this.origin}/shopping/category_prd.asp?itemid=${itemId}`);
      if (urls.length >= limit) break;
    }
    return urls;
  },

  /**
   * 이미 수집한 상품의 breadcrumb 에서 하위 분류 목록 주소를 얻는다.
   *
   * 분류 목록 한 장이 20개까지만 공개되므로, 공급원이 스스로 드러낸
   * 하위 분류를 따라 내려가며 범위를 넓힌다. 새로 만든 주소가 아니라
   * 공급원이 링크로 공개한 주소만 쓴다.
   */
  discoverListings(rawItems) {
    const found = new Set();
    for (const raw of rawItems) {
      for (const url of raw.breadcrumbUrls ?? []) {
        if (!url.includes('category_list.asp')) continue;
        const disp = new URL(url).searchParams.get('disp');
        // 최상위 분류(3자리)는 이미 시작점에 있으므로 하위 분류만 새로 본다.
        if (!disp || disp.length <= 3) continue;
        found.add(`${this.origin}/shopping/category_list.asp?disp=${disp}`);
      }
    }
    return [...found].sort();
  },

  /** 상세 페이지를 연다. 값 추출은 공통 extract 모듈이 맡는다. */
  async openDetail(page, url) {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45_000 });
    await page.waitForTimeout(500);
  },
};
