import type { VercelRequest, VercelResponse } from '@vercel/node';
import { FieldValue } from 'firebase-admin/firestore';

import { db } from '../_lib/firestore';

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
    const token = `${body.token ?? ''}`.trim();
    const platform = `${body.platform ?? 'unknown'}`.trim();
    const lat = toNumber(body.lat);
    const lng = toNumber(body.lng);

    if (!token) {
      return res.status(400).json({ error: 'Token FCM wajib diisi.' });
    }

    const docId = Buffer.from(token).toString('base64url').slice(0, 240);
    await db()
      .collection('device_tokens')
      .doc(docId)
      .set(
        {
          token,
          platform,
          lat,
          lng,
          radiusKm: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

    return res.status(200).json({
      success: true,
      docId,
    });
  } catch (error) {
    return res.status(500).json({
      error: 'Gagal menyimpan data perangkat.',
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
  return 0;
}
