import type { VercelRequest, VercelResponse } from '@vercel/node';

import { fetchLatestEarthquake } from '../_lib/bmkg';

export default async function handler(
  req: VercelRequest,
  res: VercelResponse,
) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'Metode tidak diizinkan.' });
  }

  try {
    const event = await fetchLatestEarthquake();
    return res.status(200).json({
      source: 'BMKG',
      event,
    });
  } catch (error) {
    return res.status(500).json({
      error: 'Gagal mengambil data BMKG terbaru.',
      detail: `${error}`,
    });
  }
}
