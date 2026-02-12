import { XMLParser } from 'fast-xml-parser';

const NOWCAST_RSS_URL = 'https://www.bmkg.go.id/alerts/nowcast/id';

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '',
  trimValues: true,
});

export interface NowcastAlert {
  headline?: string;
  event?: string;
  effective?: string;
  expires?: string;
  description?: string;
  link?: string;
  source: 'BMKG';
}

export async function fetchNowcastForLocation(
  location: string,
): Promise<NowcastAlert | null> {
  const rssText = await fetchText(NOWCAST_RSS_URL);
  const rss = parser.parse(rssText) as Record<string, unknown>;
  const items = ensureArray(
    (rss as any)?.rss?.channel?.item as Record<string, unknown> | undefined,
  );
  if (items.length === 0) {
    return null;
  }

  const matched = items.filter((item) => {
    const title = readString((item as any)?.title);
    const description = readString((item as any)?.description);
    return matchesLocation(title, location) || matchesLocation(description, location);
  });

  if (matched.length === 0) {
    return null;
  }

  const item = matched[0];
  const link = readString((item as any)?.link);
  if (!link) {
    return {
      headline: readString((item as any)?.title),
      description: readString((item as any)?.description),
      source: 'BMKG',
    };
  }

  const capText = await fetchText(link);
  const cap = parser.parse(capText) as Record<string, unknown>;
  const info = pickInfo(cap);

  return {
    headline: readString(info?.headline ?? (item as any)?.title),
    event: readString(info?.event),
    effective: readString(info?.effective),
    expires: readString(info?.expires),
    description: readString(info?.description ?? (item as any)?.description),
    link,
    source: 'BMKG',
  };
}

function ensureArray(
  value?: Record<string, unknown> | Array<Record<string, unknown>>,
): Array<Record<string, unknown>> {
  if (!value) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  return [value];
}

function pickInfo(cap: Record<string, unknown>): Record<string, unknown> | null {
  const info = (cap as any)?.alert?.info;
  if (!info) {
    return null;
  }
  if (Array.isArray(info)) {
    return info[0] as Record<string, unknown>;
  }
  return info as Record<string, unknown>;
}

function matchesLocation(text: string, location: string): boolean {
  const hay = normalize(text);
  const needle = normalize(location);
  if (!needle) {
    return false;
  }
  if (hay.includes(needle)) {
    return true;
  }
  const tokens = needle.split(' ').filter((token) => token.length >= 4);
  if (tokens.length === 0) {
    return false;
  }
  const hits = tokens.filter((token) => hay.includes(token)).length;
  if (tokens.length <= 2) {
    return hits >= 1;
  }
  return hits >= 2;
}

function normalize(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function readString(value: unknown): string {
  if (typeof value === 'string') {
    return value.trim();
  }
  return '';
}

async function fetchText(url: string): Promise<string> {
  const response = await fetch(url, {
    headers: {
      accept: 'application/xml,text/xml,application/rss+xml',
    },
  });
  if (!response.ok) {
    throw new Error(`BMKG nowcast error ${response.status}`);
  }
  return response.text();
}
