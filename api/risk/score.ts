import type { VercelRequest, VercelResponse } from '@vercel/node';

import { calculateRisk } from '../_lib/risk';

export default async function handler(
  req: VercelRequest,
  res: VercelResponse,
) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Metode tidak diizinkan.' });
  }

  try {
    const body = parseBody(req.body);
    const userLat = toNumber(body.userLat);
    const userLng = toNumber(body.userLng);
    const eqLat = toNumber(body.eqLat);
    const eqLng = toNumber(body.eqLng);
    const magnitude = toNumber(body.magnitude);
    const depthKm = toNumber(body.depthKm);

    if (
      Number.isNaN(userLat) ||
      Number.isNaN(userLng) ||
      Number.isNaN(eqLat) ||
      Number.isNaN(eqLng) ||
      Number.isNaN(magnitude) ||
      Number.isNaN(depthKm)
    ) {
      return res.status(400).json({ error: 'Payload risk score tidak valid.' });
    }

    const result = calculateRisk({
      userLat,
      userLng,
      eqLat,
      eqLng,
      magnitude,
      depthKm,
    });

    return res.status(200).json(result);
  } catch (error) {
    return res.status(500).json({
      error: 'Gagal menghitung skor risiko.',
      detail: `${error}`,
    });
  }
}

function parseBody(body: unknown): Record<string, unknown> {
  if (!body) {
    return {};
  }
  if (typeof body === 'string') {
    return JSON.parse(body) as Record<string, unknown>;
  }
  if (typeof body === 'object') {
    return body as Record<string, unknown>;
  }
  return {};
}

function toNumber(value: unknown): number {
  if (typeof value === 'number') {
    return value;
  }
  if (typeof value === 'string') {
    return Number.parseFloat(value);
  }
  return Number.NaN;
}
