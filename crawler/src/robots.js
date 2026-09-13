import { USER_AGENT } from './browser.js';

/**
 * robots.txt 를 읽어 우리 User-Agent 에 해당하는 규칙만 남긴다.
 *
 * 완전한 robots 구현이 아니라 "허용된 경로만 방문한다"를 지키기 위한 최소 검사다.
 * 판단이 서지 않으면 막는 쪽을 고른다.
 */
export async function loadRobots(origin, agentTokens = ['ClaudeBot', 'GiftmapBot', '*']) {
  const res = await fetch(new URL('/robots.txt', origin), {
    headers: { 'user-agent': USER_AGENT },
  });
  if (!res.ok) return { rules: null, raw: '' };
  const raw = await res.text();
  return { rules: pickGroup(raw, agentTokens), raw };
}

/** 우리에게 적용되는 가장 구체적인 그룹의 allow/disallow 목록을 고른다. */
function pickGroup(raw, agentTokens) {
  const groups = [];
  let current = null;
  let expectingAgents = false;

  for (const line of raw.split(/\r?\n/)) {
    const text = line.replace(/#.*$/, '').trim();
    if (!text) continue;
    const idx = text.indexOf(':');
    if (idx < 0) continue;
    const key = text.slice(0, idx).trim().toLowerCase();
    const value = text.slice(idx + 1).trim();

    if (key === 'user-agent') {
      if (!expectingAgents || !current) {
        current = { agents: [], allow: [], disallow: [] };
        groups.push(current);
        expectingAgents = true;
      }
      current.agents.push(value.toLowerCase());
      continue;
    }
    if (!current) continue;
    expectingAgents = false;
    if (key === 'allow' && value) current.allow.push(value);
    if (key === 'disallow') current.disallow.push(value);
  }

  for (const token of agentTokens) {
    const found = groups.find((g) => g.agents.includes(token.toLowerCase()));
    if (found) return found;
  }
  return null;
}

/** robots 규칙상 이 경로를 방문해도 되는지. 가장 긴 패턴이 이긴다. */
export function isAllowed(rules, pathname) {
  if (!rules) return true; // robots.txt 가 없으면 제한이 없다.
  const allow = longestMatch(rules.allow, pathname);
  const disallow = longestMatch(rules.disallow, pathname);
  if (disallow === null) return true;
  if (allow === null) return false;
  return allow.length >= disallow.length;
}

function longestMatch(patterns, pathname) {
  let best = null;
  for (const pattern of patterns) {
    if (pattern === '') continue;
    if (!matches(pattern, pathname)) continue;
    if (best === null || pattern.length > best.length) best = pattern;
  }
  return best;
}

function matches(pattern, pathname) {
  const escaped = pattern
    .replace(/[.+?^${}()|[\]\\]/g, '\\$&')
    .replace(/\\\*/g, '.*')
    .replace(/\\\$$/, '$');
  return new RegExp('^' + escaped).test(pathname);
}
