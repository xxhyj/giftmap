import { collectLinks, hintMap, listingPages } from './helpers.js';

/**
 * 알라딘 어댑터.
 *
 * robots.txt 가 `ClaudeBot` 을 포함한 그룹에 `/shop/` 을 허용한다.
 * 상품 상세는 `schema.org/Product` JSON-LD 와 `Offer.availability` 를 준다.
 *
 * 책·음반·문구 등 선물로 고르기 좋은 분류만 시작점으로 쓴다.
 */
/** 알라딘이 파는 것 중 책이 아닌 것을 알아보는 표시. */
const NOT_A_BOOK =
  /\[?(LP|CD|DVD|블루레이|Blu-ray)\]?|\d+집|정규|미니앨범|OST|음반/i;

export const aladinAdapter = {
  id: 'aladin',
  label: '알라딘',
  origin: 'https://www.aladin.co.kr',

  /** 분야별 베스트셀러 목록. `BranchType` 이 분야 코드다. */
  listingUrls: listingPages(
    [1, 2, 3, 4, 5, 6, 7].map(
      (branch) =>
        `https://www.aladin.co.kr/shop/common/wbest.aspx?BranchType=${branch}`,
    ),
    // 알라딘 베스트 목록은 page 파라미터로 넘긴다.
    { param: 'page', pages: 4 },
  ),

  /** 분야 코드로 분류를 정한다. 1=도서, 3=음반, 나머지는 취미·소품으로 본다. */
  categoryFor: hintMap([
    ['BranchType=1', 'book'],
    ['BranchType=2', 'book'],
    ['BranchType=3', 'music'],
    ['BranchType=4', 'hobby'],
    ['BranchType=5', 'hobby'],
    ['BranchType=6', 'book'],
    ['BranchType=7', 'stationery'],
  ]),

  /**
   * 알라딘에서 파는 것은 대부분 책이다.
   *
   * 상품명 키워드만 보면 "Student Book"·"Reading" 같은 영어 교재가 문구로,
   * 만화 「스킵과 로퍼」가 신발로 새어 도서 분류가 텅 비고 다른 분류가
   * 책으로 뒤덮인다. 그래서 음반·영상·문구처럼 책이 아닌 것이 분명할 때만
   * 다른 분류를 쓰고, 나머지는 도서로 둔다.
   */
  classify({ guessed, hint, name }) {
    if (hint === 'stationery') return guessed;
    if (NOT_A_BOOK.test(name)) return guessed === 'book' ? 'music' : guessed;
    if (guessed === 'dessert' || guessed === 'music') return guessed;
    return 'book';
  },

  async collectProductUrls(page, listingUrl, limit) {
    return collectLinks(page, listingUrl, {
      limit,
      // wproduct.aspx?ItemId=<숫자> 가 상품 상세다.
      match: /wproduct\.aspx\?ItemId=(\d+)/i,
      canonical: (id) => `https://www.aladin.co.kr/shop/wproduct.aspx?ItemId=${id}`,
      // 목록이 한 화면에 모두 나와 스크롤이 필요 없다.
      scrolls: 0,
    });
  },

  discoverListings() {
    return [];
  },

  /**
   * 도서 페이지에는 Product JSON-LD 가 없어 가격·저자가 비어 온다.
   * 공개된 화면 표시값을 그대로 읽어 채운다(값을 지어내지 않는다).
   *
   * `.Ritem` 두 개가 정가와 판매가로 나온다. 둘이면 작은 쪽이 판매가다.
   */
  async enrich(page, raw) {
    if (raw.price !== null && raw.price !== undefined) return raw;

    const found = await page.evaluate(() => {
      const prices = [];
      for (const el of document.querySelectorAll('.Ritem')) {
        const match = /^(\d{1,3}(?:,\d{3})+)\s*원$/.exec((el.textContent || '').trim());
        if (match) prices.push(Number(match[1].replace(/,/g, '')));
      }
      const title = document.title || '';
      return { prices, title };
    });

    const prices = found.prices.filter((value) => Number.isFinite(value) && value > 0);
    if (prices.length === 0) return raw;

    const price = Math.min(...prices);
    const listPrice = Math.max(...prices);

    // 도서 제목은 "책 이름 | 저자" 형태로 온다. 저자를 브랜드 자리에 넣는다.
    const parts = String(raw.name ?? found.title)
      .split('|')
      .map((part) => part.trim())
      .filter(Boolean);

    return {
      ...raw,
      price,
      listPrice: listPrice > price ? listPrice : null,
      name: parts[0] ?? raw.name,
      brand: raw.brand ?? (parts.length > 1 ? parts[1] : null),
    };
  },

  async openDetail(page, url) {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45_000 });
    await page.waitForTimeout(800);
  },
};
