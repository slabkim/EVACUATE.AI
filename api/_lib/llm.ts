import { fetchNowcastForLocation, type NowcastAlert } from './nowcast';

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

  if (isCasualQuestion(message)) {
    return casualReply();
  }

  if (!isDisasterScope(message)) {
    return outOfScopeReply();
  }

  if (shouldCheckNowcast(message)) {
    const location =
      extractLocationFromMessage(message) ??
      readString(input.userLocation?.label, '');
    if (location) {
      try {
        const alert = await fetchNowcastForLocation(location);
        if (alert) {
          return formatNowcastReply(alert, location);
        }
        return formatNoNowcastReply(location);
      } catch (error) {
        console.error('Nowcast fetch failed', error);
      }
    }
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
    'Fokus pada panduan keselamatan bencana (gempa, tsunami, banjir, kebakaran, longsor, dll).',
    'Jawab ringkas, praktis, berbentuk langkah bernomor saat relevan.',
    'Jika informasi tidak pasti, katakan jujur dan arahkan ke sumber resmi BMKG/BPBD.',
    'Jika pengguna menyebut anak, lansia, gedung bertingkat, cedera, atau kebakaran, berikan saran spesifik kondisi tersebut.',
    'Jika pertanyaan di luar konteks bencana, tolak dengan sopan dan minta kembali ke topik bencana.',
    'Jika jenis bencana tidak jelas, ajukan satu pertanyaan klarifikasi singkat.',
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

  const model = (process.env.GEMINI_MODEL || 'gemini-1.5-flash').trim();
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

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

  const response = await fetchWithRetry(url, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const detail = await safeReadBody(response);
    throw new Error(`Gemini error ${response.status}: ${detail}`);
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
    return 'Halo. Saya AI Darurat EVACUATE.AI. Silakan jelaskan kondisi terkait bencana yang sedang Anda alami, misalnya lokasi, jenis bencana, dan kebutuhan bantuan.';
  }
  if (message.includes('tsunami')) {
    return 'Untuk potensi tsunami: 1) Segera evakuasi ke tempat lebih tinggi. 2) Ikuti jalur evakuasi resmi. 3) Jauhi pantai dan muara sungai. 4) Pantau peringatan resmi BMKG/BPBD.';
  }
  if (isFloodQuery(message)) {
    return 'Jika terjadi banjir: 1) Matikan listrik dan gas bila aman. 2) Pindah ke tempat lebih tinggi. 3) Hindari arus deras dan kabel listrik. 4) Bawa dokumen penting dalam plastik kedap air. 5) Ikuti instruksi evakuasi BPBD.';
  }
  if (isFireQuery(message)) {
    return 'Jika terjadi kebakaran: 1) Aktifkan alarm dan evakuasi segera. 2) Jangan gunakan lift. 3) Merunduk untuk hindari asap. 4) Tutup pintu di belakang Anda. 5) Hubungi 112 atau pemadam setempat.';
  }
  if (isLandslideQuery(message)) {
    return 'Jika terjadi longsor: 1) Menjauh dari lereng/tebing. 2) Evakuasi ke area terbuka yang lebih aman. 3) Waspadai longsor susulan terutama saat hujan. 4) Ikuti arahan BPBD setempat.';
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
  return 'Tetap tenang. Identifikasi jenis bencana, evakuasi jika berbahaya, dan ikuti instruksi resmi BPBD/BMKG. Jika Anda jelaskan jenis bencana dan lokasi, saya bisa memberi langkah yang lebih tepat.';
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
    'kebakaran',
    'api',
    'asap',
    'erupsi',
    'gunung',
    'letusan',
  ];
  return keywords.some((keyword) => text.includes(keyword)) || isGreeting(text);
}

function outOfScopeReply(): string {
  return 'Maaf, saya hanya melayani pertanyaan terkait bencana (gempa/tsunami/banjir/kebakaran/evakuasi/keselamatan). Silakan ajukan pertanyaan dalam konteks kejadian bencana.';
}

function shouldCheckNowcast(message: string): boolean {
  const text = message.toLowerCase();
  if (!isFloodQuery(text) && !text.includes('hujan') && !text.includes('cuaca')) {
    return false;
  }
  return (
    text.includes('hari ini') ||
    text.includes('sekarang') ||
    text.includes('terkini') ||
    text.includes('saat ini') ||
    text.includes('pagi ini') ||
    text.includes('siang ini') ||
    text.includes('sore ini') ||
    text.includes('malam ini')
  );
}

function extractLocationFromMessage(message: string): string | null {
  const text = message.toLowerCase();
  const match = text.match(
    /\b(?:di|daerah|wilayah|kecamatan|kelurahan|kota|kabupaten)\s+([a-z0-9\s\-.,]+)/i,
  );
  if (!match || !match[1]) {
    return null;
  }
  let location = match[1]
    .replace(/[?!.]/g, ' ')
    .replace(/\b(hari ini|sekarang|saat ini|terkini|potensi|banjir|gempa|tsunami|kebakaran|longsor)\b/g, ' ')
    .trim();
  location = location.replace(/\s{2,}/g, ' ');
  if (location.length < 4) {
    return null;
  }
  return location;
}

function formatNowcastReply(alert: NowcastAlert, location: string): string {
  const headline = alert.headline || alert.event || 'Peringatan dini cuaca BMKG';
  const windowText = formatAlertWindow(alert.effective, alert.expires);
  const description = alert.description ? summarizeDescription(alert.description) : '';
  const parts = [
    `${headline}.`,
    windowText,
    description,
    `Lokasi yang ditanyakan: ${location}.`,
    'Potensi banjir bisa meningkat jika hujan lebat atau ekstrem. Pantau kondisi lokal dan ikuti instruksi BPBD.',
    'Sumber: BMKG Peringatan Dini Cuaca.',
  ];
  return parts.filter(Boolean).join(' ');
}

function formatNoNowcastReply(location: string): string {
  return `Saat ini tidak ada peringatan dini cuaca BMKG yang aktif untuk ${location}. Ini bukan jaminan bebas banjir; tetap pantau hujan lokal dan info resmi BPBD/BMKG. Sumber: BMKG Peringatan Dini Cuaca.`;
}

function isCasualQuestion(message: string): boolean {
  const text = message.toLowerCase().trim();
  const patterns = [
    'nama kamu siapa',
    'kamu siapa',
    'siapa kamu',
    'siapa nama kamu',
    'nama anda siapa',
    'kamu bot apa',
    'bot apa',
    'siapa namamu',
    'namamu siapa',
  ];
  return patterns.some((pattern) => text.includes(pattern));
}

function casualReply(): string {
  return 'Saya AI Darurat EVACUATE.AI. Saya fokus membantu info keselamatan bencana. Jika ada situasi bencana yang ingin ditanyakan, silakan beri detailnya.';
}

async function fetchWithRetry(
  url: string,
  init: RequestInit,
  attempts = 3,
): Promise<Response> {
  let lastError: unknown;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      const response = await fetchWithTimeout(url, init, 15000);
      if (response.ok) {
        return response;
      }
      if (isRetryableStatus(response.status) && attempt < attempts - 1) {
        await sleep(backoffDelay(attempt));
        continue;
      }
      return response;
    } catch (error) {
      lastError = error;
      if (attempt < attempts - 1) {
        await sleep(backoffDelay(attempt));
        continue;
      }
    }
  }
  throw lastError ?? new Error('Gemini request failed.');
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs: number,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, {
      ...init,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }
}

function isRetryableStatus(status: number): boolean {
  return status === 408 || status === 429 || status === 500 || status === 503 || status === 504;
}

function backoffDelay(attempt: number): number {
  const base = 400 * Math.pow(2, attempt);
  const jitter = Math.floor(Math.random() * 200);
  return base + jitter;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function safeReadBody(response: Response): Promise<string> {
  try {
    return await response.text();
  } catch (_) {
    return '';
  }
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

function isFloodQuery(message: string): boolean {
  return message.includes('banjir');
}

function isFireQuery(message: string): boolean {
  return message.includes('kebakaran') || message.includes('api') || message.includes('asap');
}

function isLandslideQuery(message: string): boolean {
  return message.includes('longsor') || message.includes('tanah bergerak');
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

function formatAlertWindow(effective?: string, expires?: string): string {
  const start = effective ? formatDateTime(effective) : '';
  const end = expires ? formatDateTime(expires) : '';
  if (start && end) {
    return `Berlaku ${start} hingga ${end}.`;
  }
  if (start) {
    return `Mulai ${start}.`;
  }
  if (end) {
    return `Berlaku hingga ${end}.`;
  }
  return '';
}

function summarizeDescription(text: string): string {
  const cleaned = text.replace(/\s+/g, ' ').trim();
  if (cleaned.length <= 260) {
    return cleaned;
  }
  return `${cleaned.slice(0, 257)}...`;
}
