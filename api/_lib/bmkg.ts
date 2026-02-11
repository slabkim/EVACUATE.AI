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

const DEFAULT_BMKG_URL =
  'https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json';

export async function fetchLatestEarthquake(): Promise<LatestEarthquakeEvent> {
  const url = process.env.BMKG_URL?.trim() || DEFAULT_BMKG_URL;
  const response = await fetch(url, {
    headers: {
      accept: 'application/json',
    },
  });
  if (!response.ok) {
    throw new Error(`Gagal mengambil BMKG (${response.status}).`);
  }

  const payload = (await response.json()) as Record<string, unknown>;
  const gempa = (((payload.Infogempa as Record<string, unknown> | undefined)
    ?.gempa ?? {}) as Record<string, unknown>);
  if (Object.keys(gempa).length === 0) {
    throw new Error('Format data BMKG tidak dikenali.');
  }

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
