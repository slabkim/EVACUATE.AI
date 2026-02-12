# EVACUATE.AI (MVP Gempa)

Aplikasi Flutter + backend Vercel untuk deteksi gempa BMKG, skor risiko, notifikasi FCM, dan AI chat darurat berbahasa Indonesia.

## Fitur MVP

- Dashboard gempa BMKG terbaru (`/api/bmkg/latest`)
- Perhitungan skor risiko rule-based (`/api/risk/score`)
- Registrasi perangkat FCM + lokasi ke Firestore (`/api/device/register`)
- Cron Vercel tiap 5 menit untuk push notifikasi gempa (`/api/cron/check-bmkg`)
- AI Chat darurat berfokus gempa (`/api/chat`)
- Layar kritis Emergency Alert full-screen

## Struktur Utama

- Flutter: `lib/`
- Serverless backend: `api/`
- Konfigurasi cron: `vercel.json`
- Contoh env backend: `.env.example`

## Konfigurasi Environment (Vercel)

Tambahkan variable berikut pada project Vercel:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`
- `CRON_SECRET`
- `BMKG_FEED` (opsional: `autogempa` | `m5` | `dirasakan`, default `autogempa`)
- `BMKG_URL` (opsional, override langsung endpoint BMKG apa pun)
- `GEMINI_API_KEY` (opsional, provider utama)
- `GEMINI_MODEL` (opsional, default `gemini-1.5-flash`)
- `GROQ_API_KEY` (opsional, fallback jika Gemini gagal)
- `GROQ_MODEL` (opsional, default `llama-3.1-70b-versatile`)

Catatan:

- Jika `BMKG_URL` diisi, nilai ini diprioritaskan dibanding `BMKG_FEED`.
- Isi `BMKG_FEED` tanpa kutip, contoh: `dirasakan`.
- Jika ingin memakai `BMKG_FEED`, kosongkan/hapus `BMKG_URL`.

## Menjalankan Flutter

1. Install dependency:

```bash
flutter pub get
```

2. Jalankan aplikasi dengan URL backend:

```bash
flutter run --dart-define=API_BASE_URL=https://<domain-backend-anda>
```

Catatan: Untuk Android emulator lokal, default fallback adalah `http://10.0.2.2:3000`.

## Catatan Firebase Mobile

Agar FCM berjalan di aplikasi Flutter, pastikan konfigurasi Firebase mobile sudah ditambahkan:

- Android: `google-services.json`
- iOS: `GoogleService-Info.plist`

Tanpa file tersebut, aplikasi tetap bisa dibuka namun fitur push notification tidak aktif.
