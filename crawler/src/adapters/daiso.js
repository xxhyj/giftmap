import { USER_AGENT } from '../browser.js';
import { sitemapProductUrls } from './helpers.js';

/**
 * 다이소몰 어댑터.
 *
 * robots.txt 가 `ClaudeBot` 그룹에 상품 경로(`/pd/`)를 허용하고,
 * sitemap 으로 상품 주소를 직접 공개한다(약 2만 건).
 * 상세 페이지는 `schema.org/Product` JSON-LD 에 이름·브랜드·가격·재고·이미지와
 * 분류 breadcrumb 까지 담고 있어 따로 보완할 값이 없다.
 *
 * 생활용품·주방·청소·문구·뷰티까지 분야가 넓어, 한 공급원에 쏠린 분류를
 * 고르게 펴 주는 역할을 한다.
 */
export const daisoAdapter = {
  id: 'daiso',
  label: '다이소몰',
  origin: 'https://www.daisomall.co.kr',

  /**
   * 목록 대신 sitemap 을 쓴다.
   * 한 번에 다 가져오지 않도록 묶음을 나누고, 묶음마다 다른 구간을 읽는다.
   */
  listingUrls: [
    'https://www.daisomall.co.kr/sitemap.xml#1',
    'https://www.daisomall.co.kr/sitemap.xml#2',
    'https://www.daisomall.co.kr/sitemap.xml#3',
    'https://www.daisomall.co.kr/sitemap.xml#4',
  ],

  /** 분류는 상품 breadcrumb 이 정확하므로 힌트를 쓰지 않는다. */
  categoryFor: () => null,

  async collectProductUrls(page, listingUrl, limit) {
    // sitemap 은 렌더링이 필요 없다. 그대로 읽는다.
    const chunk = Number(listingUrl.split('#')[1] ?? '1');
    const urls = await sitemapProductUrls(listingUrl.split('#')[0], {
      match: /\/pd\//,
      // 묶음마다 다른 구간을 보도록 넉넉히 뽑은 뒤 잘라 쓴다.
      limit: limit * 4,
      userAgent: USER_AGENT,
    });

    const size = Math.ceil(urls.length / 4);
    const start = (chunk - 1) * size;
    return urls.slice(start, start + size).slice(0, limit);
  },

  discoverListings() {
    return [];
  },

  async openDetail(page, url) {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45_000 });
    await page.waitForTimeout(900);
  },
};
