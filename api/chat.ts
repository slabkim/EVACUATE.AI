import type { VercelRequest, VercelResponse } from '@vercel/node';

import { generateEarthquakeReply } from './_lib/llm';

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
    const message = `${body.message ?? ''}`.trim();

    if (!message) {
      return res.status(400).json({ error: 'Pesan wajib diisi.' });
    }

    const reply = await generateEarthquakeReply({
      message,
      history: Array.isArray(body.history)
        ? (body.history as Array<Record<string, unknown>>)
        : [],
      latestEarthquake: asRecord(body.latestEarthquake),
      risk: asRecord(body.risk),
      userLocation: asRecord(body.userLocation),
    });

    return res.status(200).json({ reply });
  } catch (error) {
    return res.status(500).json({
      error: 'Gagal memproses chat AI darurat.',
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

function asRecord(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object') {
    return value as Record<string, unknown>;
  }
  return {};
}
