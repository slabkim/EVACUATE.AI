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
- `BMKG_URL` (opsional, default BMKG autogempa)
- `GEMINI_API_KEY` atau `OPENAI_API_KEY`

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
