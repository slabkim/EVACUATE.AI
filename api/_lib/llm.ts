interface ChatHistoryItem {
  text?: string;
  message?: string;
  content?: string;
  isUser?: boolean;
  role?: string;
}

interface ChatContextInput {
  message: string;
  history?: ChatHistoryItem[];
  latestEarthquake?: Record<string, unknown>;
  risk?: Record<string, unknown>;
  userLocation?: Record<string, unknown>;
}

export async function generateEarthquakeReply(
  input: ChatContextInput,
): Promise<string> {
  const systemPrompt = buildSystemPrompt(input);
  const message = input.message ?? '';

  if (!isDisasterScope(message)) {
    return outOfScopeReply();
  }

  if (isLatestEventQuery(message)) {
    const quickReply = formatLatestEventReply(input);
    if (quickReply) {
      return quickReply;
    }
  }

  if (!process.env.GEMINI_API_KEY) {
    return fallbackReply(input);
  }

  try {
    return await requestGemini(systemPrompt, input);
  } catch (error) {
    console.error('Gemini request failed', error);
    return fallbackReply(input);
  }
}

function buildSystemPrompt(input: ChatContextInput): string {
  const event = input.latestEarthquake ?? {};
  const risk = input.risk ?? {};
  const location = input.userLocation ?? {};

  const contextText = [
    'Konteks realtime:',
    `- Lokasi pengguna: ${location.label ?? 'tidak diketahui'} (${location.lat ?? '-'}, ${location.lng ?? '-'})`,
    `- Gempa terakhir: M${event.magnitude ?? '-'} kedalaman ${event.depthKm ?? '-'} km, wilayah ${event.wilayah ?? '-'}, waktu ${event.dateTime ?? '-'}`,
    `- Risiko: skor ${risk.riskScore ?? '-'} level ${risk.riskLevel ?? '-'}`,
  ].join('\n');

  return [
    'Anda adalah AI Darurat EVACUATE.AI.',
    'WAJIB menjawab hanya dalam Bahasa Indonesia.',
    'Fokus eksklusif pada panduan keselamatan GEMPA.',
    'Jawab ringkas, praktis, berbentuk langkah bernomor saat relevan.',
    'Jika informasi tidak pasti, katakan jujur dan arahkan ke sumber resmi BMKG/BPBD.',
    'Jika pengguna menyebut anak, lansia, gedung bertingkat, cedera, atau kebakaran, berikan saran spesifik kondisi tersebut.',
    'Jika pertanyaan di luar konteks bencana, tolak dengan sopan dan minta kembali ke topik bencana.',
    contextText,
  ].join('\n');
}

async function requestGemini(
  systemPrompt: string,
  input: ChatContextInput,
): Promise<string> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY tidak tersedia.');
  }

  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;

  const historyContents: Array<{
    role: 'user' | 'model';
    parts: Array<{ text: string }>;
  }> = [];
  for (const item of input.history ?? []) {
    const text = readMessageText(item);
    if (!text) {
      continue;
    }
    historyContents.push({
      role: item.isUser || item.role === 'user' ? 'user' : 'model',
      parts: [{ text }],
    });
  }

  const body = {
    systemInstruction: {
      role: 'system',
      parts: [{ text: systemPrompt }],
    },
    contents: [
      ...historyContents,
      {
        role: 'user',
        parts: [{ text: input.message }],
      },
    ],
    generationConfig: {
      temperature: 0.2,
      maxOutputTokens: 350,
    },
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    throw new Error(`Gemini error ${response.status}`);
  }
  const result = (await response.json()) as {
    candidates?: Array<{
      content?: {
        parts?: Array<{ text?: string }>;
      };
    }>;
  };
  const text = result.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
  if (!text) {
    throw new Error('Respon Gemini kosong.');
  }
  return text;
}

function readMessageText(item: ChatHistoryItem): string {
  return `${item.text ?? item.content ?? item.message ?? ''}`.trim();
}

function fallbackReply(input: ChatContextInput): string {
  const message = input.message.toLowerCase();
  if (!isDisasterScope(message)) {
    return outOfScopeReply();
  }
  if (isGreeting(message)) {
    return 'Halo. Saya AI Darurat EVACUATE.AI. Silakan jelaskan kondisi terkait gempa yang sedang Anda alami, misalnya lokasi, guncangan, atau kebutuhan bantuan.';
  }
  if (message.includes('tsunami')) {
    return 'Untuk potensi tsunami, ikuti peringatan resmi BMKG. Jika Anda di pesisir dan ada peringatan, segera evakuasi ke tempat lebih tinggi melalui jalur resmi.';
  }
  if (message.includes('cedera')) {
    return 'Jika ada cedera: 1) Hentikan perdarahan dengan penekanan kain bersih. 2) Jangan memindahkan korban dengan dugaan cedera tulang belakang. 3) Hubungi 112 atau layanan medis terdekat.';
  }
  if (
    message.includes('lantai') ||
    message.includes('apartemen') ||
    message.includes('gedung')
  ) {
    return 'Jika berada di gedung bertingkat: 1) Jatuhkan diri. 2) Lindungi kepala dan leher. 3) Bertahan sampai guncangan berhenti. 4) Jauhi kaca dan jangan gunakan lift. 5) Evakuasi lewat tangga darurat setelah aman.';
  }
  return 'Tetap tenang. Lakukan Jatuhkan Diri, Lindungi Kepala, dan Bertahan. Setelah guncangan berhenti, evakuasi tertib, jauhi bangunan retak, dan pantau informasi resmi BMKG/BPBD.';
}

function isGreeting(message: string): boolean {
  const text = message.trim().toLowerCase();
  return (
    text == 'halo' ||
    text == 'hai' ||
    text == 'hello' ||
    text == 'hi' ||
    text == 'assalamualaikum' ||
    text == 'assalamu’alaikum' ||
    text == 'assalamu alaikum'
  );
}

function isDisasterScope(message: string): boolean {
  const text = message.toLowerCase();
  const keywords = [
    'gempa',
    'guncang',
    'magnitude',
    'magnitudo',
    'kedalaman',
    'episentrum',
    'hiposentrum',
    'seismik',
    'tsunami',
    'evakuasi',
    'jalur evakuasi',
    'titik kumpul',
    'posko',
    'pengungsian',
    'bpbd',
    'bmkg',
    'darurat',
    'bencana',
    'korban',
    'cedera',
    'luka',
    'p3k',
    'ambulans',
    'kebakaran',
    'retak',
    'runtuh',
    'listrik',
    'gas',
    'aftershock',
    'gempa susulan',
    'banjir',
    'longsor',
  ];
  return keywords.some((keyword) => text.includes(keyword)) || isGreeting(text);
}

function outOfScopeReply(): string {
  return 'Maaf, saya hanya melayani pertanyaan terkait bencana (gempa/tsunami/evakuasi/keselamatan). Silakan ajukan pertanyaan dalam konteks kejadian bencana.';
}

function isLatestEventQuery(message: string): boolean {
  const text = message.toLowerCase();
  if (!text.includes('gempa')) {
    return false;
  }
  const keywords = [
    'terbaru',
    'terkini',
    'terakhir',
    'paling baru',
    'update',
    'lokasi',
    'wilayah',
    'di mana',
    'dimana',
    'pusat',
    'episentrum',
    'epicenter',
    'hiposentrum',
  ];
  return keywords.some((keyword) => text.includes(keyword));
}

function formatLatestEventReply(input: ChatContextInput): string | null {
  const event = input.latestEarthquake;
  if (!event || typeof event !== 'object') {
    return null;
  }

  const record = event as Record<string, unknown>;
  const magnitude = readNumber(record.magnitude);
  const depthKm = readNumber(record.depthKm);
  const wilayah = readString(record.wilayah, 'Wilayah tidak diketahui');
  const dateTime = formatDateTime(readString(record.dateTime, ''));
  const lat = readNumber(record.eqLat);
  const lng = readNumber(record.eqLng);
  const potensi = readString(record.potensi);
  const dirasakan = readString(record.dirasakan);

  const parts: string[] = [];
  const magnitudeText = magnitude == null ? '-' : magnitude.toFixed(1);
  const depthText = depthKm == null ? '-' : depthKm.toFixed(0);
  parts.push(`Gempa terbaru: M${magnitudeText} kedalaman ${depthText} km di ${wilayah}.`);
  if (dateTime) {
    parts.push(`Waktu: ${dateTime}.`);
  }
  if (
    lat != null &&
    lng != null &&
    !(Number.isFinite(lat) && Number.isFinite(lng) && lat === 0 && lng === 0)
  ) {
    parts.push(`Koordinat: ${lat.toFixed(2)}, ${lng.toFixed(2)}.`);
  }
  if (potensi) {
    parts.push(`Potensi: ${potensi}.`);
  }
  if (dirasakan) {
    parts.push(`Dirasakan: ${dirasakan}.`);
  }
  parts.push('Pantau info resmi BMKG/BPBD untuk pembaruan.');
  return parts.join(' ');
}

function readNumber(value: unknown): number | null {
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === 'string') {
    const normalized = value.replace(',', '.');
    const parsed = Number.parseFloat(normalized);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function readString(value: unknown, fallback = ''): string {
  if (typeof value === 'string' && value.trim()) {
    return value.trim();
  }
  return fallback;
}

function formatDateTime(value: string): string {
  if (!value) {
    return '';
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return value;
  }
  return parsed.toLocaleString('id-ID', {
    timeZone: 'Asia/Jakarta',
    hour12: false,
  });
}
