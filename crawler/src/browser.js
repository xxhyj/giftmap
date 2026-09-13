import { chromium } from 'playwright';

/// 수집기가 자신을 밝히는 User-Agent. robots.txt 의 규칙 판단 기준과 같은 이름을 쓴다.
export const USER_AGENT =
  'Mozilla/5.0 (compatible; GiftmapBot/1.0; +https://github.com/giftmap) ClaudeBot';

/**
 * Chromium 을 띄우고 컨텍스트를 돌려준다.
 * 이미지·폰트는 받지 않아 수집 부하를 줄인다(이미지 URL 은 마크업에서 읽는다).
 */
export async function openBrowser({ headless = true } = {}) {
  const browser = await chromium.launch({ headless });
  const context = await browser.newContext({
    userAgent: USER_AGENT,
    locale: 'ko-KR',
    viewport: { width: 1280, height: 900 },
  });
  await context.route('**/*', (route) => {
    const type = route.request().resourceType();
    if (type === 'image' || type === 'media' || type === 'font') return route.abort();
    return route.continue();
  });
  return {
    context,
    async close() {
      await context.close();
      await browser.close();
    },
  };
}
