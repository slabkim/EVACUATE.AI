import type { VercelRequest, VercelResponse } from '@vercel/node';

import { fetchEarthquakeEvents, getBmkgRuntimeInfo } from '../_lib/bmkg';

export default async function handler(
  req: VercelRequest,
  res: VercelResponse,
) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'Metode tidak diizinkan.' });
  }

  try {
    const limit = parseLimit(req.query.limit);
    const sourceMeta = getBmkgRuntimeInfo();
    const events = await fetchEarthquakeEvents(limit);
    return res.status(200).json({
      source: 'BMKG',
      sourceMeta,
      count: events.length,
      events,
    });
  } catch (error) {
    return res.status(500).json({
      error: 'Gagal mengambil daftar data BMKG.',
      detail: `${error}`,
    });
  }
}

function parseLimit(value: string | string[] | undefined): number {
  const raw = Array.isArray(value) ? value[0] : value;
  const parsed = Number.parseInt(`${raw ?? ''}`, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return 20;
  }
  return Math.min(parsed, 100);
}
