import { collectLinks, hintMap, listingPages } from './helpers.js';

/**
 * 무신사 어댑터.
 *
 * robots.txt 가 `ClaudeBot` 을 포함한 그룹에 상품 경로를 허용한다.
 * 로그인·장바구니·마이페이지 경로에는 접근하지 않는다.
 *
 * 상품 상세는 `schema.org/Product` JSON-LD 를 주고 `Offer.availability` 로
 * 재고까지 알려준다. 목록은 자바스크립트로 그려져 Playwright 로 렌더한다.
 */
export const musinsaAdapter = {
  id: 'musinsa',
  label: '무신사',
  origin: 'https://www.musinsa.com',

  /** 선물로 볼 만한 상위 분류들. `category/<코드>` 는 공개 목록 경로다. */
  listingUrls: listingPages(
    [
      '001', // 상의
      '002', // 아우터
      '003', // 바지
      '004', // 원피스
      '005', // 스커트
      '007', // 신발
      '020', // 스포츠
      '022', // 남성 언더웨어
      '026', // 여성 언더웨어
      '103', // 가방
      '104', // 모자
      '017', // 시계·주얼리
      '018', // 액세서리
      '101', // 뷰티
    ].map((code) => `https://www.musinsa.com/category/${code}`),
    // 무신사 목록은 page 파라미터로 넘긴다.
    { param: 'page', pages: 5 },
  ),

  async collectProductUrls(page, listingUrl, limit) {
    return collectLinks(page, listingUrl, {
      limit,
      // /products/<숫자> 가 상품 상세다.
      match: /\/products\/(\d+)/,
      canonical: (id) => `https://www.musinsa.com/products/${id}`,
    });
  },

  /** 무신사는 상품에 분류를 달아 주지 않아 목록 코드로 분류를 정한다. */
  categoryFor: hintMap([
    ['/category/001', 'fashion_clothing'],
    ['/category/002', 'fashion_clothing'],
    ['/category/003', 'fashion_clothing'],
    ['/category/004', 'fashion_clothing'],
    ['/category/005', 'fashion_clothing'],
    ['/category/007', 'shoes'],
    ['/category/020', 'fashion_clothing'],
    ['/category/022', 'homewear'],
    ['/category/026', 'homewear'],
    ['/category/103', 'bag'],
    ['/category/104', 'fashion_accessory'],
    ['/category/017', 'fashion_accessory'],
    ['/category/018', 'fashion_accessory'],
    ['/category/101', 'beauty'],
  ]),

  /**
   * 무신사는 breadcrumb 을 목록 주소로 주지 않아 분류 확장을 하지 않는다.
   * 대신 시작 목록에 페이지를 충분히 넣어 범위를 확보한다.
   */
  discoverListings() {
    return [];
  },

  async openDetail(page, url) {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45_000 });
    await page.waitForTimeout(1_200);
  },
};
