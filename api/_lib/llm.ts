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

  try {
    if (process.env.GEMINI_API_KEY) {
      return await requestGemini(systemPrompt, input);
    }
    if (process.env.OPENAI_API_KEY) {
      return await requestOpenAi(systemPrompt, input);
    }
  } catch (_) {
    return fallbackReply(input);
  }

  return fallbackReply(input);
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
    'Jangan membahas topik di luar keselamatan darurat.',
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

async function requestOpenAi(
  systemPrompt: string,
  input: ChatContextInput,
): Promise<string> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error('OPENAI_API_KEY tidak tersedia.');
  }

  const messages: Array<{
    role: 'system' | 'user' | 'assistant';
    content: string;
  }> = [{ role: 'system', content: systemPrompt }];
  for (const item of input.history ?? []) {
    const text = readMessageText(item);
    if (!text) {
      continue;
    }
    messages.push({
      role: item.isUser || item.role === 'user' ? 'user' : 'assistant',
      content: text,
    });
  }
  messages.push({ role: 'user', content: input.message });

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
      temperature: 0.2,
      max_tokens: 350,
      messages,
    }),
  });

  if (!response.ok) {
    throw new Error(`OpenAI error ${response.status}`);
  }
  const result = (await response.json()) as {
    choices?: Array<{
      message?: { content?: string };
    }>;
  };
  const text = result.choices?.[0]?.message?.content?.trim();
  if (!text) {
    throw new Error('Respon OpenAI kosong.');
  }
  return text;
}

function readMessageText(item: ChatHistoryItem): string {
  return `${item.text ?? item.content ?? item.message ?? ''}`.trim();
}

function fallbackReply(input: ChatContextInput): string {
  const message = input.message.toLowerCase();
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
