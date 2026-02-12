import { fetchNowcastForLocation, type NowcastAlert } from "./nowcast";
import {
  fetchWeatherForecast,
  type WeatherForecastSummary,
} from "./bmkg-weather";

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
  const message = (input.message ?? "").trim();
  const messageLower = message.toLowerCase();

  if (!message) {
    return "Silakan tuliskan pertanyaan Anda terkait bencana (mis. banjir/gempa/tsunami/kebakaran) beserta lokasi.";
  }

  // 1) Casual / identitas bot
  if (isCasualQuestion(messageLower)) {
    return casualReply();
  }

  // 2) Scope check
  if (!isDisasterScope(messageLower)) {
    return outOfScopeReply();
  }

  // 3) Safety triage: bahaya langsung
  if (isImmediateDanger(messageLower)) {
    return immediateDangerReply(messageLower, input);
  }

  // 4) Nowcast: jam-jaman / hari ini
  if (shouldCheckNowcast(messageLower)) {
    const location =
      extractLocationFromMessage(message) ??
      readString(input.userLocation?.label, "");
    if (location) {
      try {
        const alert = await fetchNowcastForLocation(location);
        if (alert) {
          return formatNowcastReply(alert, location);
        }
        return formatNoNowcastReply(location);
      } catch (error) {
        console.error("Nowcast fetch failed", error);
        // lanjut ke Gemini / fallback
      }
    } else {
      // Lokasi tidak ada tapi user minta kondisi "hari ini"
      return [
        "Status: Sedang",
        "Ringkas: Saya perlu lokasi Anda untuk cek peringatan dini cuaca (nowcast).",
        "Langkah cepat:",
        "1) Sebutkan lokasi minimal kota/kecamatan (contoh: “di Depok, Cimanggis”).",
        "2) Sambil menunggu, jika hujan lebat: jauhi sungai/selokan besar, pantau genangan, amankan listrik.",
        "Sumber: BMKG/BPBD.",
      ].join("\n");
    }
  }

  // 5) Query gempa terbaru (pakai data context jika tersedia)
  if (isLatestEventQuery(messageLower)) {
    const quickReply = formatLatestEventReply(input);
    if (quickReply) {
      return quickReply;
    }
  }

  // 6) Forecast multi-hari dengan BMKG API
  if (isForecastQuery(messageLower)) {
    const location =
      extractLocationFromMessage(message) ??
      readString(input.userLocation?.label, "");

    if (location) {
      try {
        const forecast = await fetchWeatherForecast(location);
        if (forecast) {
          return formatWeatherForecastReply(forecast);
        }
      } catch (error) {
        console.error("Weather forecast fetch failed", error);
      }
    }

    // Fallback jika forecast tidak tersedia
    return forecastFallbackReply(messageLower, input);
  }

  // 7) Gemini AI (jika tersedia)
  if (!readEnv("GEMINI_API_KEY")) {
    return fallbackReply(input);
  }

  try {
    const geminiText = await requestGemini(systemPrompt, input);
    return enforceReplyFormat(geminiText);
  } catch (error) {
    console.error("Gemini request failed, using rule-based fallback", error);
    return fallbackReply(input);
  }
}

/** -------------------- PROMPT -------------------- */

function buildSystemPrompt(input: ChatContextInput): string {
  const event = input.latestEarthquake ?? {};
  const risk = input.risk ?? {};
  const location = input.userLocation ?? {};

  const contextText = [
    "Konteks realtime (boleh tidak lengkap):",
    `- Lokasi pengguna: ${location.label ?? "tidak diketahui"} (${location.lat ?? "-"}, ${location.lng ?? "-"})`,
    `- Gempa terakhir: M${(event as any).magnitude ?? "-"} kedalaman ${(event as any).depthKm ?? "-"} km, wilayah ${(event as any).wilayah ?? "-"}, waktu ${(event as any).dateTime ?? "-"}`,
    `- Risiko banjir/curah hujan (jika ada): skor ${(risk as any).riskScore ?? "-"} level ${(risk as any).riskLevel ?? "-"}`,
  ].join("\n");

  return [
    "Anda adalah AI Darurat EVACUATE.AI untuk mitigasi bencana di Indonesia.",
    "WAJIB menjawab hanya Bahasa Indonesia.",
    "",
    "PRIORITAS UTAMA: keselamatan manusia. Jika ada indikasi bahaya langsung, dahulukan langkah evakuasi/pertolongan pertama.",
    "",
    "ATURAN JAWABAN:",
    "1) Jawab singkat, sangat praktis, gunakan langkah bernomor (maks 6–9 langkah).",
    "2) Selalu tentukan: (a) jenis bahaya, (b) tingkat urgensi (Rendah/Sedang/Tinggi), (c) tindakan 10 menit pertama.",
    "3) Jika info penting kurang (lokasi spesifik, waktu, kondisi sekitar), ajukan maksimal 1 pertanyaan klarifikasi di akhir.",
    "4) Untuk banjir/cuaca: bedakan NOWCAST (jam-jaman/hari ini) vs PRAKIRAAN (besok/3 hari/mingguan).",
    "5) Jika tidak yakin, katakan jujur + arahkan ke sumber resmi BMKG/BPBD/BNPB, tanpa mengarang detail.",
    "6) Jika ada anak/lansia/ibu hamil/disabilitas/cedera/gedung bertingkat/kebakaran/listrik-gas, beri saran khusus kondisi tersebut.",
    "7) Jangan beri instruksi berbahaya (mis. menerobos banjir deras).",
    "",
    "FORMAT OUTPUT (usahakan konsisten):",
    "- Status: <Rendah/Sedang/Tinggi>",
    "- Ringkas: 1 kalimat",
    "- Langkah cepat: (1)...(n)...",
    "- Catatan: (opsional) hal yang perlu diwaspadai",
    "- Sumber: BMKG/BPBD/BNPB (sebutkan sebagai rujukan)",
    "",
    contextText,
  ].join("\n");
}

/** -------------------- GEMINI -------------------- */

async function requestGemini(
  systemPrompt: string,
  input: ChatContextInput,
): Promise<string> {
  const apiKey = readEnv("GEMINI_API_KEY");
  if (!apiKey) {
    throw new Error("GEMINI_API_KEY tidak tersedia.");
  }

  const model = (readEnv("GEMINI_MODEL") || "gemini-1.5-flash-latest").trim();
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

  const historyContents: Array<{
    role: "user" | "model";
    parts: Array<{ text: string }>;
  }> = [];

  for (const item of input.history ?? []) {
    const text = readMessageText(item);
    if (!text) continue;
    historyContents.push({
      role: item.isUser || item.role === "user" ? "user" : "model",
      parts: [{ text }],
    });
  }

  const body = {
    systemInstruction: {
      role: "system",
      parts: [{ text: systemPrompt }],
    },
    contents: [
      ...historyContents,
      {
        role: "user",
        parts: [{ text: input.message }],
      },
    ],
    generationConfig: {
      temperature: 0.2,
      maxOutputTokens: 450,
    },
  };

  const response = await fetchWithRetry(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-goog-api-key": apiKey,
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
    throw new Error("Respon Gemini kosong.");
  }
  return text;
}

function enforceReplyFormat(text: string): string {
  let out = (text ?? "").trim();

  // Basic guardrails
  const hasSource = /sumber\s*:/i.test(out);
  const hasStatus = /status\s*:/i.test(out);
  if (!hasStatus) out = `Status: Sedang\n${out}`;
  if (!hasSource) out = `${out}\nSumber: BMKG/BPBD/BNPB (rujukan resmi)`;

  // Limit excessive length
  if (out.length > 1500) out = out.slice(0, 1490) + "…";

  return out;
}

/** -------------------- ROUTING / INTENTS -------------------- */

function isGreeting(message: string): boolean {
  const text = message.trim().toLowerCase();
  return (
    text === "halo" ||
    text === "hai" ||
    text === "hello" ||
    text === "hi" ||
    text === "assalamualaikum" ||
    text === "assalamu’alaikum" ||
    text === "assalamu alaikum"
  );
}

function isCasualQuestion(message: string): boolean {
  const text = message.toLowerCase().trim();
  const patterns = [
    "nama kamu siapa",
    "kamu siapa",
    "siapa kamu",
    "siapa nama kamu",
    "nama anda siapa",
    "kamu bot apa",
    "bot apa",
    "siapa namamu",
    "namamu siapa",
  ];
  return patterns.some((pattern) => text.includes(pattern));
}

function isDisasterScope(message: string): boolean {
  const text = message.toLowerCase();
  const keywords = [
    "gempa",
    "guncang",
    "magnitude",
    "magnitudo",
    "kedalaman",
    "episentrum",
    "hiposentrum",
    "seismik",
    "tsunami",
    "evakuasi",
    "jalur evakuasi",
    "titik kumpul",
    "posko",
    "pengungsian",
    "bpbd",
    "bmkg",
    "bnpb",
    "darurat",
    "bencana",
    "korban",
    "cedera",
    "luka",
    "p3k",
    "ambulans",
    "kebakaran",
    "retak",
    "runtuh",
    "listrik",
    "gas",
    "aftershock",
    "gempa susulan",
    "banjir",
    "genangan",
    "rob",
    "longsor",
    "tanah bergerak",
    "api",
    "asap",
    "erupsi",
    "gunung",
    "letusan",
    "hujan",
    "cuaca",
    "petir",
    "angin kencang",
    "puting beliung",
  ];
  return keywords.some((keyword) => text.includes(keyword)) || isGreeting(text);
}

function isLatestEventQuery(message: string): boolean {
  const text = message.toLowerCase();
  if (!text.includes("gempa")) return false;

  const keywords = [
    "terbaru",
    "terkini",
    "terakhir",
    "paling baru",
    "update",
    "lokasi",
    "wilayah",
    "di mana",
    "dimana",
    "pusat",
    "episentrum",
    "epicenter",
    "hiposentrum",
  ];
  return keywords.some((keyword) => text.includes(keyword));
}

function isFloodQuery(message: string): boolean {
  const t = message.toLowerCase();
  return t.includes("banjir") || t.includes("genangan") || t.includes("rob");
}

function isFireQuery(message: string): boolean {
  const t = message.toLowerCase();
  return t.includes("kebakaran") || t.includes("api") || t.includes("asap");
}

function isLandslideQuery(message: string): boolean {
  const t = message.toLowerCase();
  return t.includes("longsor") || t.includes("tanah bergerak");
}

function shouldCheckNowcast(message: string): boolean {
  const text = message.toLowerCase();
  const aboutWeatherOrFlood =
    isFloodQuery(text) ||
    text.includes("hujan") ||
    text.includes("cuaca") ||
    text.includes("angin") ||
    text.includes("petir");

  if (!aboutWeatherOrFlood) return false;

  const nowKeywords = [
    "hari ini",
    "sekarang",
    "saat ini",
    "terkini",
    "pagi ini",
    "siang ini",
    "sore ini",
    "malam ini",
    "jam ini",
    "1 jam",
    "2 jam",
    "beberapa jam",
    "sebentar lagi",
  ];
  return nowKeywords.some((k) => text.includes(k));
}

function isForecastQuery(message: string): boolean {
  const text = message.toLowerCase();
  const aboutWeatherOrFlood =
    isFloodQuery(text) ||
    text.includes("hujan") ||
    text.includes("cuaca") ||
    text.includes("angin") ||
    text.includes("gelombang");

  if (!aboutWeatherOrFlood) return false;

  const keywords = [
    "besok",
    "lusa",
    "minggu ini",
    "pekan ini",
    "akhir pekan",
    "3 hari",
    "5 hari",
    "7 hari",
    "beberapa hari",
    "prakiraan",
    "prediksi",
    "ramalan",
    "perkiraan",
    "ke depan",
  ];
  return keywords.some((k) => text.includes(k));
}

function isImmediateDanger(message: string): boolean {
  const t = message.toLowerCase();
  const dangerSignals = [
    // banjir parah / terseret
    "air sudah masuk rumah",
    "air masuk rumah",
    "air naik cepat",
    "sepinggang",
    "sedada",
    "seleher",
    "arus deras",
    "terseret",
    "hanyut",
    "tenggelam",
    "orang hilang",
    // listrik / gas / api
    "korsleting",
    "listrik nyala",
    "bau gas",
    "api besar",
    "asap tebal",
    // medis
    "pingsan",
    "tidak sadar",
    "sesak napas",
    "perdarahan",
    "luka parah",
    // bangunan
    "bangunan retak besar",
    "runtuh",
  ];
  return dangerSignals.some((k) => t.includes(k));
}

/** -------------------- LOCATION / FORMATTING -------------------- */

function extractLocationFromMessage(message: string): string | null {
  const text = message.toLowerCase();

  // Ambil maksimal 60 char setelah kata lokasi
  const match = text.match(
    /\b(?:di|daerah|wilayah|kecamatan|kelurahan|kota|kabupaten)\s+([a-z0-9\s\-.,]{3,60})/i,
  );
  if (!match?.[1]) return null;

  let location = match[1]
    .replace(/[?!.]/g, " ")
    .replace(
      /\b(hari ini|sekarang|saat ini|terkini|potensi|banjir|hujan|cuaca|gempa|tsunami|kebakaran|longsor|di mana|dimana)\b/g,
      " ",
    )
    .trim()
    .replace(/\s{2,}/g, " ");

  if (location.length < 3) return null;
  return location;
}

function formatNowcastReply(alert: NowcastAlert, location: string): string {
  const headline =
    alert.headline || alert.event || "Peringatan dini cuaca BMKG";
  const windowText = formatAlertWindow(alert.effective, alert.expires);
  const description = alert.description
    ? summarizeDescription(alert.description)
    : "";

  const extraFloodNote =
    isHeavyRainSignal(alert) ||
    /lebat|sangat lebat|ekstrem|petir|angin kencang/i.test(description)
      ? "Catatan: Hujan lebat/ekstrem dapat memicu banjir, genangan, dan longsor terutama di area rendah/lereng."
      : "Catatan: Tetap pantau kondisi lokal; genangan bisa terjadi meski tanpa peringatan aktif.";

  const parts = [
    "Status: Sedang",
    `Ringkas: ${headline} untuk wilayah terkait ${location}.`,
    "Langkah cepat:",
    "1) Siapkan rencana evakuasi lokal (jalur aman, titik kumpul keluarga).",
    "2) Bersihkan saluran air di sekitar rumah bila aman.",
    "3) Amankan listrik (hindari kabel/colokan di area basah), simpan dokumen penting kedap air.",
    "4) Hindari berteduh di bawah pohon saat petir/angin kencang.",
    windowText ? `Catatan: ${windowText}` : "",
    description ? `Info: ${description}` : "",
    extraFloodNote,
    `Sumber: BMKG Peringatan Dini Cuaca.`,
  ];

  return parts.filter(Boolean).join("\n");
}

function formatNoNowcastReply(location: string): string {
  return [
    "Status: Rendah–Sedang",
    `Ringkas: Saat ini tidak ada peringatan dini cuaca BMKG yang aktif untuk ${location}.`,
    "Langkah cepat:",
    "1) Ini bukan jaminan bebas banjir; pantau hujan lokal dan kondisi drainase.",
    "2) Jika hujan lebat berulang: siapkan tas darurat, amankan listrik, dan waspadai area rendah/sungai.",
    "3) Ikuti informasi BPBD setempat jika ada imbauan siaga/evakuasi.",
    "Sumber: BMKG Peringatan Dini Cuaca / BPBD.",
  ].join("\n");
}

function summarizeDescription(text: string): string {
  const cleaned = text.replace(/\s+/g, " ").trim();
  if (cleaned.length <= 320) return cleaned;
  return `${cleaned.slice(0, 317)}...`;
}

function isHeavyRainSignal(alert: NowcastAlert): boolean {
  const t =
    `${alert.headline ?? ""} ${alert.event ?? ""} ${alert.description ?? ""}`.toLowerCase();
  return (
    t.includes("hujan lebat") ||
    t.includes("hujan sangat lebat") ||
    t.includes("ekstrem") ||
    t.includes("banjir") ||
    t.includes("angin kencang") ||
    t.includes("petir")
  );
}

/** -------------------- QUICK REPLIES -------------------- */

function casualReply(): string {
  return [
    "Status: Rendah",
    "Ringkas: Saya AI Darurat EVACUATE.AI, fokus membantu panduan keselamatan bencana.",
    "Langkah cepat:",
    "1) Tulis jenis bencana (banjir/gempa/tsunami/kebakaran/longsor).",
    "2) Sertakan lokasi (kota/kecamatan) dan kondisi sekitar (aman/terjebak/ada korban).",
    "Sumber: BMKG/BPBD/BNPB (rujukan resmi).",
  ].join("\n");
}

function outOfScopeReply(): string {
  return "Maaf, saya hanya melayani pertanyaan terkait bencana (gempa/tsunami/banjir/kebakaran/evakuasi/keselamatan). Silakan ajukan pertanyaan dalam konteks kejadian bencana.";
}

function immediateDangerReply(
  message: string,
  input: ChatContextInput,
): string {
  const loc = readString(input.userLocation?.label, "");
  const locText = loc ? ` (lokasi terdeteksi: ${loc})` : "";

  // Prioritize based on hints
  if (
    isFireQuery(message) ||
    message.includes("asap") ||
    message.includes("api")
  ) {
    return [
      "Status: Tinggi",
      `Ringkas: Ada indikasi bahaya kebakaran${locText}. Evakuasi segera jika aman.`,
      "Langkah cepat:",
      "1) Evakuasi segera. Jangan gunakan lift, gunakan tangga darurat.",
      "2) Jika ada asap: merunduk, tutup hidung/mulut dengan kain, tutup pintu saat keluar.",
      "3) Jika baju terbakar: berhenti–jatuh–guling (stop, drop, roll).",
      "4) Hubungi darurat 112 / pemadam setempat secepatnya.",
      "5) Jika ada korban sesak/pingsan: pindahkan ke udara segar bila aman dan minta bantuan medis.",
      "Pertanyaan: Anda berada di lantai berapa dan ada jalur keluar yang aman?",
      "Sumber: BPBD/BNPB & layanan darurat setempat.",
    ].join("\n");
  }

  if (
    isFloodQuery(message) ||
    message.includes("arus") ||
    message.includes("hanyut")
  ) {
    return [
      "Status: Tinggi",
      `Ringkas: Ada indikasi banjir berbahaya${locText}. Utamakan keselamatan dan evakuasi ke tempat lebih tinggi.`,
      "Langkah cepat:",
      "1) Jika aman, MATIKAN listrik MCB dan gas. Jangan sentuh peralatan listrik saat basah.",
      "2) Pindahkan anak/lansia ke tempat lebih tinggi (lantai atas/area elevasi).",
      "3) Jangan menerobos arus deras atau berkendara menerjang banjir.",
      "4) Jauhi kabel jatuh, gardu listrik, dan genangan dekat sumber listrik.",
      "5) Jika terjebak: naik ke titik tertinggi, minta bantuan tetangga/RT/BPBD, siapkan peluit/senter.",
      "6) Hubungi 112 atau posko BPBD setempat bila butuh evakuasi.",
      "Pertanyaan: ketinggian air sekarang (mata kaki/lutut/pinggang) dan arusnya deras atau tidak?",
      "Sumber: BPBD/BNPB & layanan darurat setempat.",
    ].join("\n");
  }

  if (
    message.includes("pingsan") ||
    message.includes("tidak sadar") ||
    message.includes("sesak") ||
    message.includes("perdarahan")
  ) {
    return [
      "Status: Tinggi",
      `Ringkas: Ada indikasi kondisi medis darurat${locText}. Cari bantuan medis segera.`,
      "Langkah cepat:",
      "1) Hubungi 112 / layanan medis terdekat sekarang.",
      "2) Jika tidak sadar tapi bernapas: posisikan miring stabil (recovery position).",
      "3) Jika perdarahan: tekan luka dengan kain bersih kuat dan terus-menerus.",
      "4) Jangan beri makan/minum bila korban tidak sadar.",
      "5) Jika dicurigai cedera tulang belakang: jangan dipindahkan kecuali ada bahaya langsung.",
      "Pertanyaan: korban bernapas normal atau tidak?",
      "Sumber: layanan darurat setempat (112) / BPBD.",
    ].join("\n");
  }

  // Generic danger
  return [
    "Status: Tinggi",
    `Ringkas: Ada indikasi bahaya langsung${locText}. Utamakan evakuasi dan keselamatan.`,
    "Langkah cepat:",
    "1) Jauhkan diri dari sumber bahaya (air deras/api/gas/struktur retak).",
    "2) Cari tempat aman/lebih tinggi, ajak anak/lansia lebih dulu.",
    "3) Jika aman, putus listrik/gas.",
    "4) Hubungi 112 atau BPBD setempat bila perlu evakuasi.",
    "Pertanyaan: Anda sedang menghadapi banjir, kebakaran, atau cedera?",
    "Sumber: BPBD/BNPB & layanan darurat setempat.",
  ].join("\n");
}

function formatWeatherForecastReply(forecast: WeatherForecastSummary): string {
  const { location, days } = forecast;
  if (!days?.length) {
    return [
      "Status: Sedang",
      `Ringkas: Data prakiraan ${location} tidak tersedia.`,
      "Sumber: BMKG.",
    ].join("\n");
  }

  const parts = ["Status: Sedang"];
  const d0 = days[0];
  parts.push(
    `Ringkas: Prakiraan ${location}: ${d0.weather}, ${d0.tempMin}-${d0.tempMax}°C.`,
  );
  parts.push("Prakiraan:");

  days.forEach((d, i) => {
    const lbl = i === 0 ? "Hari ini" : i === 1 ? "Besok" : "Lusa";
    const rain = d.rainProbability > 50 ? ` (hujan ${d.rainProbability}%)` : "";
    parts.push(
      `${i + 1}) ${lbl}: ${d.weather}, ${d.tempMin}-${d.tempMax}°C${rain}`,
    );
  });

  parts.push("Langkah cepat:");
  const hasRain = days.some((d) => d.rainProbability > 50);
  if (hasRain) {
    parts.push(
      "1) Bawa payung, hindari genangan.",
      "2) Pantau peringatan BMKG.",
    );
  } else {
    parts.push("1) Tetap siapkan pelindung cuaca.");
  }
  parts.push("Sumber: BMKG Prakiraan Cuaca.");
  return parts.join("\n");
}

function forecastFallbackReply(
  message: string,
  input: ChatContextInput,
): string {
  const location =
    extractLocationFromMessage(message) ??
    readString(input.userLocation?.label, "");

  const locText = location ? ` di ${location}` : "";

  // Fokus: user ingin prakiraan → jika belum ada API, berikan mitigasi + cara cek resmi
  if (
    isFloodQuery(message) ||
    message.includes("hujan") ||
    message.includes("cuaca")
  ) {
    return [
      "Status: Sedang",
      `Ringkas: Untuk prakiraan (besok/3–7 hari)${locText}, saya bisa bantu mitigasi dan cara cek info resmi.`,
      "Langkah cepat:",
      "1) Cek prakiraan resmi BMKG untuk lokasi Anda (prakiraan harian & peringatan dini).",
      "2) Jika prediksi hujan lebat/berulang: bersihkan drainase, siapkan karung pasir bila rawan, pindahkan barang berharga ke tempat tinggi.",
      "3) Amankan listrik: naikkan stopkontak/perangkat, siapkan senter & powerbank.",
      "4) Siapkan tas darurat (dokumen, obat, pakaian, air minum) dan rencana evakuasi keluarga.",
      "5) Waspada khusus jika dekat sungai/lereng: pantau kenaikan debit & tanda longsor (retakan, pohon miring).",
      "Pertanyaan: lokasi Anda di area rendah/dekat sungai atau perbukitan/lereng?",
      "Sumber: BMKG (prakiraan & peringatan dini), BPBD setempat.",
    ].join("\n");
  }

  return [
    "Status: Rendah–Sedang",
    `Ringkas: Saya butuh detail untuk memberi saran prakiraan${locText}.`,
    "Langkah cepat:",
    "1) Sebutkan jenis bencana yang Anda maksud (banjir/angin/petir/gelombang).",
    "2) Sebutkan lokasi (kota/kecamatan) dan rentang waktu (besok/3 hari/1 minggu).",
    "Sumber: BMKG/BPBD.",
  ].join("\n");
}

/** -------------------- FALLBACK (NO GEMINI) -------------------- */

function fallbackReply(input: ChatContextInput): string {
  const message = (input.message ?? "").toLowerCase();

  if (!isDisasterScope(message)) {
    return outOfScopeReply();
  }

  const loc = readString(input.userLocation?.label, "");

  if (isGreeting(message)) {
    return [
      "Status: Rendah",
      "Ringkas: Halo. Saya AI Darurat EVACUATE.AI.",
      "Langkah cepat:",
      "1) Jelaskan jenis bencana (banjir/gempa/tsunami/kebakaran/longsor).",
      `2) Sertakan lokasi (contoh: ${loc || "kota/kecamatan Anda"}).`,
      "3) Beritahu kondisi (aman/terjebak/ada korban).",
      "Sumber: BMKG/BPBD/BNPB.",
    ].join("\n");
  }

  if (message.includes("tsunami")) {
    return [
      "Status: Tinggi",
      "Ringkas: Jika ada potensi tsunami, segera evakuasi ke tempat tinggi dan jauhi pantai.",
      "Langkah cepat:",
      "1) Evakuasi ke tempat lebih tinggi/sejauh mungkin dari pantai dan muara sungai.",
      "2) Ikuti jalur evakuasi & arahan petugas; jangan menunggu melihat gelombang.",
      "3) Jika di gedung: naik ke lantai atas hanya jika tidak ada rute evakuasi ke dataran tinggi.",
      "4) Pantau peringatan resmi BMKG/BPBD.",
      "Sumber: BMKG/BPBD.",
    ].join("\n");
  }

  if (isFloodQuery(message)) {
    return floodMaxReply(loc);
  }

  if (isFireQuery(message)) {
    return [
      "Status: Tinggi",
      "Ringkas: Kebakaran berbahaya—evakuasi segera dan hindari asap.",
      "Langkah cepat:",
      "1) Aktifkan alarm/teriak minta bantuan, evakuasi segera.",
      "2) Jangan gunakan lift; gunakan tangga darurat.",
      "3) Merunduk untuk hindari asap; tutup hidung/mulut dengan kain.",
      "4) Tutup pintu di belakang Anda untuk memperlambat api/asap.",
      "5) Hubungi 112 atau pemadam setempat.",
      "Sumber: BPBD/BNPB & layanan darurat setempat.",
    ].join("\n");
  }

  if (isLandslideQuery(message)) {
    return [
      "Status: Tinggi",
      "Ringkas: Longsor berpotensi susulan—menjauh dari lereng dan cari area aman.",
      "Langkah cepat:",
      "1) Menjauh dari lereng/tebing dan aliran material.",
      "2) Evakuasi ke area terbuka yang lebih aman.",
      "3) Waspadai longsor susulan terutama saat hujan berlanjut.",
      "4) Hindari jalur bawah tebing dan bantaran sungai.",
      "5) Ikuti arahan BPBD setempat.",
      "Sumber: BPBD/BNPB.",
    ].join("\n");
  }

  if (
    message.includes("cedera") ||
    message.includes("luka") ||
    message.includes("perdarahan")
  ) {
    return [
      "Status: Tinggi",
      "Ringkas: Tangani cedera dengan aman dan hubungi bantuan medis bila perlu.",
      "Langkah cepat:",
      "1) Hentikan perdarahan dengan penekanan kain bersih.",
      "2) Jangan memindahkan korban bila diduga cedera tulang belakang (kecuali bahaya langsung).",
      "3) Jaga korban tetap hangat dan tenang.",
      "4) Hubungi 112 atau layanan medis terdekat.",
      "Sumber: layanan darurat setempat.",
    ].join("\n");
  }

  if (
    message.includes("lantai") ||
    message.includes("apartemen") ||
    message.includes("gedung")
  ) {
    return [
      "Status: Sedang–Tinggi",
      "Ringkas: Di gedung bertingkat saat gempa, lindungi diri dan evakuasi lewat tangga setelah aman.",
      "Langkah cepat:",
      "1) Jatuhkan diri (Drop).",
      "2) Lindungi kepala & leher (Cover).",
      "3) Bertahan sampai guncangan berhenti (Hold).",
      "4) Jauhi kaca/lemari; jangan gunakan lift.",
      "5) Evakuasi lewat tangga darurat setelah aman dan periksa kebocoran gas/listrik.",
      "Sumber: BMKG/BNPB.",
    ].join("\n");
  }

  // Generic
  return [
    "Status: Sedang",
    "Ringkas: Jelaskan jenis bencana dan lokasi agar saya bisa beri langkah yang tepat.",
    "Langkah cepat:",
    "1) Sebutkan bencana (banjir/gempa/tsunami/kebakaran/longsor).",
    "2) Sertakan lokasi (kota/kecamatan) dan kondisi sekitar (air naik/ada asap/terasa gempa).",
    "Sumber: BMKG/BPBD/BNPB.",
  ].join("\n");
}

function floodMaxReply(locationLabel?: string): string {
  const loc = locationLabel ? ` di ${locationLabel}` : "";
  return [
    "Status: Sedang–Tinggi",
    `Ringkas: Jika ada potensi/kejadian banjir${loc}, amankan listrik dan siapkan evakuasi ke tempat lebih tinggi.`,
    "Langkah cepat:",
    "1) Jika aman, MATIKAN listrik MCB dan gas. Jangan sentuh peralatan listrik saat lantai basah.",
    "2) Pindahkan keluarga (anak/lansia) ke area lebih tinggi. Siapkan tas darurat (obat, identitas, powerbank).",
    "3) Jangan menerobos arus deras; hindari berkendara melewati banjir.",
    "4) Jauhi kabel listrik jatuh/gardu dan genangan dekat sumber listrik.",
    "5) Simpan dokumen penting dalam plastik kedap air; siapkan air minum dan P3K.",
    "6) Ikuti instruksi evakuasi BPBD/RT/RW setempat.",
    "Catatan: Risiko meningkat bila hujan lebat berkepanjangan, drainase tersumbat, atau dekat sungai/lereng.",
    "Sumber: BMKG/BPBD.",
  ].join("\n");
}

/** -------------------- GEMPA TERBARU (CONTEXT) -------------------- */

function formatLatestEventReply(input: ChatContextInput): string | null {
  const event = input.latestEarthquake;
  if (!event || typeof event !== "object") return null;

  const record = event as Record<string, unknown>;
  const magnitude = readNumber(record.magnitude);
  const depthKm = readNumber(record.depthKm);
  const wilayah = readString(record.wilayah, "Wilayah tidak diketahui");
  const dateTime = formatDateTime(readString(record.dateTime, ""));
  const lat = readNumber(record.eqLat);
  const lng = readNumber(record.eqLng);
  const potensi = readString(record.potensi);
  const dirasakan = readString(record.dirasakan);

  const magnitudeText = magnitude == null ? "-" : magnitude.toFixed(1);
  const depthText = depthKm == null ? "-" : depthKm.toFixed(0);

  const parts: string[] = [];
  parts.push("Status: Sedang");
  parts.push(
    `Ringkas: Gempa terbaru M${magnitudeText} kedalaman ${depthText} km di ${wilayah}.`,
  );
  parts.push("Langkah cepat:");
  parts.push(
    "1) Jika masih ada guncangan/aftershock: lakukan Drop–Cover–Hold.",
  );
  parts.push(
    "2) Jauhi bangunan retak, cek gas/listrik, siapkan evakuasi jika diperlukan.",
  );
  if (dateTime) parts.push(`Catatan: Waktu kejadian: ${dateTime}.`);
  if (lat != null && lng != null && !(lat === 0 && lng === 0)) {
    parts.push(`Catatan: Koordinat: ${lat.toFixed(2)}, ${lng.toFixed(2)}.`);
  }
  if (potensi) parts.push(`Catatan: Potensi: ${potensi}.`);
  if (dirasakan) parts.push(`Catatan: Dirasakan: ${dirasakan}.`);
  parts.push("Sumber: BMKG/BPBD (pantau pembaruan resmi).");

  return parts.join("\n");
}

/** -------------------- UTILITIES -------------------- */

function readMessageText(item: ChatHistoryItem): string {
  return `${item.text ?? item.content ?? item.message ?? ""}`.trim();
}

function readNumber(value: unknown): number | null {
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === "string") {
    const normalized = value.replace(",", ".");
    const parsed = Number.parseFloat(normalized);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function readString(value: unknown, fallback = ""): string {
  if (typeof value === "string" && value.trim()) {
    return value.trim();
  }
  return fallback;
}

function readEnv(key: string): string | undefined {
  const env = (globalThis as { process?: { env?: Record<string, unknown> } })
    .process?.env;
  const value = env?.[key];
  if (typeof value !== "string") {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

function formatDateTime(value: string): string {
  if (!value) return "";
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return value;
  return parsed.toLocaleString("id-ID", {
    timeZone: "Asia/Jakarta",
    hour12: false,
  });
}

function formatAlertWindow(effective?: string, expires?: string): string {
  const start = effective ? formatDateTime(effective) : "";
  const end = expires ? formatDateTime(expires) : "";
  if (start && end) return `Berlaku ${start} hingga ${end}.`;
  if (start) return `Mulai ${start}.`;
  if (end) return `Berlaku hingga ${end}.`;
  return "";
}

/** -------------------- FETCH HELPERS -------------------- */

async function fetchWithRetry(
  url: string,
  init: RequestInit,
  attempts = 3,
): Promise<Response> {
  let lastError: unknown;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      const response = await fetchWithTimeout(url, init, 15000);
      if (response.ok) return response;

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

  throw lastError ?? new Error("Gemini request failed.");
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
  return (
    status === 408 ||
    status === 429 ||
    status === 500 ||
    status === 503 ||
    status === 504
  );
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
    return "";
  }
}
