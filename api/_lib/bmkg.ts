export interface LatestEarthquakeEvent {
  dateTime: string;
  magnitude: number;
  depthKm: number;
  wilayah: string;
  eqLat: number;
  eqLng: number;
  potensi?: string;
  dirasakan?: string;
}

type BmkgFeed = 'autogempa' | 'm5' | 'dirasakan';

const BMKG_FEED_URL: Record<BmkgFeed, string> = {
  autogempa: 'https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json',
  m5: 'https://data.bmkg.go.id/DataMKG/TEWS/gempaterkini.json',
  dirasakan: 'https://data.bmkg.go.id/DataMKG/TEWS/gempadirasakan.json',
};

export async function fetchLatestEarthquake(): Promise<LatestEarthquakeEvent> {
  const url = resolveBmkgUrl();
  const response = await fetch(url, {
    headers: {
      accept: 'application/json',
    },
  });
  if (!response.ok) {
    throw new Error(`Gagal mengambil BMKG (${response.status}).`);
  }

  const payload = (await response.json()) as Record<string, unknown>;
  const gempa = pickLatestGempa(payload);

  const coordinatesText = (gempa.Coordinates as string | undefined) ?? '';
  let [eqLat, eqLng] = parseCoordinates(coordinatesText);
  if (eqLat === 0 && eqLng === 0) {
    eqLat = parseCoordinateFromHemisphere((gempa.Lintang as string | undefined) ?? '');
    eqLng = parseCoordinateFromHemisphere((gempa.Bujur as string | undefined) ?? '');
  }

  const magnitude = parseNumber((gempa.Magnitude as string | number | undefined) ?? 0);
  const depthKm = parseNumber((gempa.Kedalaman as string | number | undefined) ?? 0);
  const dateTime = parseDateTime(gempa.DateTime as string | undefined);

  return {
    dateTime,
    magnitude,
    depthKm,
    wilayah: `${gempa.Wilayah ?? 'Wilayah tidak diketahui'}`,
    eqLat,
    eqLng,
    potensi: gempa.Potensi ? `${gempa.Potensi}` : undefined,
    dirasakan: gempa.Dirasakan ? `${gempa.Dirasakan}` : undefined,
  };
}

function resolveBmkgUrl(): string {
  const customUrl = process.env.BMKG_URL?.trim();
  if (customUrl) {
    return customUrl;
  }
  const feed = resolveBmkgFeed();
  return BMKG_FEED_URL[feed];
}

function resolveBmkgFeed(): BmkgFeed {
  const raw = normalizeEnvValue(process.env.BMKG_FEED);
  if (
    raw === 'm5' ||
    raw === 'm5+' ||
    raw === '5+' ||
    raw === '5.0+' ||
    raw === 'm 5,0+' ||
    raw === 'm 5.0+' ||
    raw === 'gempaterkini'
  ) {
    return 'm5';
  }
  if (raw === 'dirasakan' || raw === 'gempadirasakan') {
    return 'dirasakan';
  }
  if (
    raw === 'autogempa' ||
    raw === 'latest' ||
    raw === 'terkini' ||
    raw === 'realtime' ||
    raw === 'real-time'
  ) {
    return 'autogempa';
  }
  return 'autogempa';
}

function normalizeEnvValue(value: string | undefined): string {
  if (!value) {
    return '';
  }
  return value
    .trim()
    .replace(/^['"]+/, '')
    .replace(/['"]+$/, '')
    .toLowerCase();
}

function pickLatestGempa(payload: Record<string, unknown>): Record<string, unknown> {
  const infoGempa = payload.Infogempa;
  if (!isRecord(infoGempa)) {
    throw new Error('Format data BMKG tidak dikenali (Infogempa tidak ada).');
  }
  const gempaNode = infoGempa.gempa;
  if (Array.isArray(gempaNode)) {
    const first = gempaNode.find((item) => isRecord(item));
    if (!first) {
      throw new Error('Data BMKG gempa kosong.');
    }
    return first;
  }
  if (isRecord(gempaNode)) {
    return gempaNode;
  }
  throw new Error('Format data BMKG tidak dikenali (field gempa invalid).');
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function parseDateTime(value?: string): string {
  if (value) {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
  }
  return new Date().toISOString();
}

function parseCoordinates(value: string): [number, number] {
  const cleaned = value.trim();
  if (!cleaned) {
    return [0, 0];
  }
  const parts = cleaned.split(',');
  if (parts.length < 2) {
    return [0, 0];
  }
  const lat = parseNumber(parts[0]);
  const lng = parseNumber(parts[1]);
  return [lat, lng];
}

function parseCoordinateFromHemisphere(text: string): number {
  const value = parseNumber(text);
  const upper = text.toUpperCase();
  if (upper.includes('LS') || upper.includes('BB')) {
    return -Math.abs(value);
  }
  return Math.abs(value);
}

function parseNumber(raw: string | number): number {
  if (typeof raw === 'number') {
    return raw;
  }
  const normalized = raw.replace(',', '.');
  const match = normalized.match(/-?\d+(\.\d+)?/);
  if (!match) {
    return 0;
  }
  return Number.parseFloat(match[0]);
}
