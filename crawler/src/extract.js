/**
 * 공개 페이지에서 상품 정보를 뽑는다.
 *
 * 우선순위
 *   1. JSON-LD 의 schema.org Product / Offer
 *   2. 없으면 공개 메타데이터(og:title, og:image, product:price 등)
 *
 * 로그인·CAPTCHA·접근 제한 페이지는 우회하지 않고 그대로 실패로 남긴다.
 */

/** 페이지가 사람 확인·로그인 벽에 막혔는지 본다. 막혔으면 건너뛴다. */
export async function detectAccessWall(page) {
  const url = page.url();
  if (/\/login|\/member|signin|captcha/i.test(url)) return 'login/captcha URL';
  const title = ((await page.title()) || '').toLowerCase();
  if (/robot|captcha|access denied|잠시만 기다려|로그인/.test(title)) {
    return `page title: ${title}`;
  }
  const hasCaptcha = await page
    .locator('iframe[src*="recaptcha"], #captcha, .g-recaptcha')
    .count()
    .catch(() => 0);
  return hasCaptcha > 0 ? 'captcha widget' : null;
}

/** 페이지 안의 모든 JSON-LD 블록을 파싱해 평평한 배열로 돌려준다. */
export async function readJsonLd(page) {
  const blocks = await page.$$eval('script[type="application/ld+json"]', (nodes) =>
    nodes.map((n) => n.textContent || ''),
  );
  const out = [];
  for (const block of blocks) {
    let parsed;
    try {
      parsed = JSON.parse(block);
    } catch {
      continue; // 한 블록이 깨져도 나머지는 쓴다.
    }
    flatten(parsed, out);
  }
  return out;
}

function flatten(node, out) {
  if (Array.isArray(node)) {
    for (const item of node) flatten(item, out);
    return;
  }
  if (!node || typeof node !== 'object') return;
  out.push(node);
  if (Array.isArray(node['@graph'])) flatten(node['@graph'], out);
}

const isType = (node, type) => {
  const value = node?.['@type'];
  return Array.isArray(value) ? value.includes(type) : value === type;
};

/** JSON-LD Product/Offer 에서 필요한 값만 뽑는다. 없으면 null. */
export function fromJsonLd(nodes) {
  const product = nodes.find((n) => isType(n, 'Product'));
  if (!product) return null;

  const offer = firstOf(product.offers) ?? {};
  // 정가는 Offer 의 UnitPriceSpecification 에 들어 있는 경우가 많다.
  const listPrice = pickNumber(firstOf(offer.hasPriceSpecification)?.price);

  return {
    source: 'json-ld',
    name: text(product.name),
    brand: text(firstOf(product.brand)?.name ?? product.brand),
    sku: text(product.sku ?? product.productID),
    imageUrl: text(firstOf(product.image)?.url ?? firstOf(product.image)),
    description: text(product.description),
    keywords: splitKeywords(product.keywords),
    price: pickNumber(offer?.price ?? offer?.lowPrice),
    listPrice,
    currency: text(offer?.priceCurrency),
    availability: text(offer?.availability),
    productUrl: text(offer?.url),
    breadcrumb: readBreadcrumb(nodes),
    breadcrumbUrls: readBreadcrumbUrls(nodes),
  };
}

function readBreadcrumb(nodes) {
  const list = nodes.find((n) => isType(n, 'BreadcrumbList'));
  if (!list || !Array.isArray(list.itemListElement)) return [];
  return list.itemListElement
    .map((item) => text(item?.name ?? item?.item?.name))
    .filter(Boolean);
}

/**
 * breadcrumb 이 가리키는 분류 페이지 주소.
 * 공급원이 스스로 공개한 하위 분류라 수집 범위를 넓힐 때 쓴다.
 */
function readBreadcrumbUrls(nodes) {
  const list = nodes.find((n) => isType(n, 'BreadcrumbList'));
  if (!list || !Array.isArray(list.itemListElement)) return [];
  return list.itemListElement
    .map((entry) => {
      const item = entry?.item;
      return text(typeof item === 'string' ? item : item?.['@id'] ?? entry?.url);
    })
    .filter(Boolean);
}

/** JSON-LD 가 없을 때 쓰는 공개 메타데이터 경로. */
export async function fromMetaTags(page) {
  const meta = await page.evaluate(() => {
    const read = (selector, attr = 'content') =>
      document.querySelector(selector)?.getAttribute(attr) ?? null;
    return {
      title: read('meta[property="og:title"]') ?? document.title,
      image: read('meta[property="og:image"]'),
      url: read('meta[property="og:url"]') ?? location.href,
      description: read('meta[property="og:description"]') ?? read('meta[name="description"]'),
      price:
        read('meta[property="product:price:amount"]') ??
        read('meta[property="og:price:amount"]'),
      currency:
        read('meta[property="product:price:currency"]') ??
        read('meta[property="og:price:currency"]'),
      brand: read('meta[property="product:brand"]'),
    };
  });
  if (!meta.title) return null;
  return {
    source: 'meta',
    name: text(meta.title),
    brand: text(meta.brand),
    sku: null,
    imageUrl: text(meta.image),
    description: text(meta.description),
    keywords: [],
    price: pickNumber(meta.price),
    listPrice: null,
    currency: text(meta.currency),
    availability: null,
    productUrl: text(meta.url),
    breadcrumb: [],
    breadcrumbUrls: [],
  };
}

/** JSON-LD 우선, 실패하면 메타데이터. 둘 다 없으면 null. */
export async function extractProduct(page) {
  const nodes = await readJsonLd(page);
  return fromJsonLd(nodes) ?? (await fromMetaTags(page));
}

const firstOf = (value) => (Array.isArray(value) ? value[0] : value);

function text(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.replace(/\s+/g, ' ').trim();
  return trimmed.length > 0 ? trimmed : null;
}

/** "30,000 원" 같은 문자열에서도 정수를 얻는다. 값이 없으면 null(0 으로 만들지 않는다). */
function pickNumber(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? Math.round(value) : null;
  if (typeof value !== 'string') return null;
  const digits = value.replace(/[^0-9.]/g, '');
  if (!digits) return null;
  const parsed = Math.round(Number(digits));
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function splitKeywords(value) {
  if (Array.isArray(value)) return value.map(text).filter(Boolean);
  if (typeof value !== 'string') return [];
  return value
    .split(/[,|]/)
    .map((item) => text(item))
    .filter(Boolean);
}
