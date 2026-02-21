# Dokumentasi Detail Proyek EVACUATE.AI

Dokumen ini menjelaskan kondisi proyek saat ini berdasarkan kode di repository.

## 1. Ringkasan Proyek

EVACUATE.AI adalah aplikasi Flutter untuk respons darurat bencana, dengan fokus utama gempa bumi, yang terhubung ke backend serverless (Vercel) untuk:

- Mengambil data gempa BMKG.
- Menghitung skor risiko berbasis lokasi pengguna.
- Registrasi token perangkat untuk push notification FCM.
- Mengirim notifikasi peringatan otomatis lewat cron job.
- Menyediakan AI chat asisten darurat berbahasa Indonesia.

Target platform aplikasi:

- Android
- iOS
- Web (Flutter web scaffolding tersedia)
- Desktop (struktur Flutter default tersedia)

## 2. Arsitektur Sistem

Arsitektur utama terdiri dari 2 lapisan:

1. `Flutter App` (`lib/`)
2. `Serverless API` (`api/`) di Vercel

Integrasi eksternal:

- BMKG data feed (gempa, nowcast, prakiraan cuaca)
- Firebase Admin SDK (Firestore + FCM)
- LLM Provider (Gemini, Groq fallback)

Alur tinggi:

1. Aplikasi memuat lokasi pengguna.
2. Aplikasi memanggil backend `GET /api/bmkg/list` untuk data gempa.
3. Aplikasi memanggil backend `POST /api/risk/score` untuk skor risiko.
4. Aplikasi registrasi FCM token ke backend `POST /api/device/register`.
5. Cron backend cek event BMKG terbaru, hitung risiko per device, kirim push jika memenuhi aturan.
6. Saat user chat, aplikasi kirim konteks ke `POST /api/chat`, backend memilih rute rule-based atau LLM.

## 3. Struktur Folder Penting

- `lib/`: aplikasi Flutter.
- `api/`: endpoint serverless TypeScript untuk Vercel.
- `api/_lib/`: utilitas backend (BMKG parser, risk scoring, LLM, Firebase).
- `api/_test/`: script uji manual endpoint/LLM/FCM.
- `assets/sounds/sirene.mp3`: aset sirene untuk alert.
- `android/app/src/main/res/raw/sirene.mp3`: sirene untuk channel notifikasi Android.
- `ui_template/`: template HTML desain UI awal/prototipe.
- `vercel.json`: konfigurasi cron Vercel.
- `.env.example`: contoh env backend.
- `pubspec.yaml`: dependency Flutter.
- `package.json`: dependency backend TypeScript.

## 4. Detail Flutter App

### 4.1 Entry Point dan Bootstrap

File: `lib/main.dart`

- Inisialisasi Firebase di startup.
- Registrasi `FirebaseMessaging.onBackgroundMessage(...)`.
- Menggunakan `Provider` dengan `ChangeNotifierProvider<AppState>`.
- Shell aplikasi berupa `IndexedStack` dengan 5 tab:
  - Beranda
  - Peta
  - Chat
  - Riwayat
  - Pengaturan
- Menerima stream alert dari `AppState.alertStream` untuk membuka `EmergencyAlertScreen`.

### 4.2 State Management

File: `lib/state/app_state.dart`

`AppState` adalah pusat orkestrasi data dan state UI:

- Menyimpan lokasi user aktif.
- Menyimpan event gempa terbaru/riwayat.
- Menyimpan hasil risk scoring.
- Mengelola chat history.
- Mengelola status loading/error.
- Mengelola unread notification indicator.
- Mengelola `ThemeMode` dan menyimpannya ke local storage.

Flow inisialisasi `initialize()`:

1. Muat theme dari `PreferencesService`.
2. Muat lokasi tersimpan (fallback jika GPS gagal).
3. Inisialisasi FCM + local notification callback.
4. Coba ambil GPS live.
5. Refresh dashboard (ambil gempa + hitung risiko).
6. Register device token ke backend.
7. Seed pesan awal AI chat.

### 4.3 Service Layer

`lib/services/api_client.dart`

- Base URL dari `--dart-define=API_BASE_URL`.
- Default fallback: `http://10.0.2.2:3000`.
- Timeout:
  - 15 detik untuk endpoint data.
  - 30 detik untuk endpoint chat.
- Endpoint yang dipakai:
  - `GET /api/bmkg/latest`
  - `GET /api/bmkg/list`
  - `POST /api/risk/score`
  - `POST /api/device/register`
  - `POST /api/chat`

`lib/services/location_service.dart`

- Cek service + permission lokasi.
- Ambil GPS dengan timeout 10 detik (fallback akurasi medium).
- Reverse geocoding untuk label lokasi.
- Hitung jarak via Haversine.

`lib/services/fcm_service.dart`

- Request permission FCM.
- Menangani foreground message dengan local notification.
- Menangani notifikasi tapped (`onMessageOpenedApp` dan `getInitialMessage`).

`lib/services/local_notif_service.dart`

- Channel Android: `evacuate_alert_channel_v4`.
- Sound custom Android: `sirene`.
- Sound iOS: `sirene.mp3`.
- Payload notifikasi diserialisasi JSON.

`lib/services/audio_service.dart`

- Memutar sirene lokal berulang (`ReleaseMode.loop`) saat alert kritis.

`lib/services/preferences_service.dart`

- Menyimpan:
  - Theme mode
  - Lokasi terakhir user (lat/lng/label)

### 4.4 Model Data Flutter

- `EarthquakeEvent`: normalisasi data event gempa.
- `RiskResult`: hasil skor + level + rekomendasi.
- `EmergencyAlertPayload`: gabungan event + risk + jarak.
- `ChatMessage`: item chat user/AI.

### 4.5 Screen dan UX Utama

`lib/screens/home_screen.dart`

- Header lokasi + badge notifikasi unread.
- Kartu status risiko (`AMAN/WASPADA/PERINGATAN`).
- Mini map (user + episentrum + radius dampak estimasi).
- Statistik gempa (magnitudo, kedalaman, jarak).
- Laporan sekitar (riwayat ringkas).
- Aksi cepat ke chat dan checklist.

`lib/screens/map_screen.dart`

- Feed category:
  - `autogempa` (terbaru)
  - `m5` (M 5.0+)
  - `dirasakan`
- Marker user + marker event.
- Radius dampak estimasi.
- Daftar event tappable untuk memfokuskan peta.

`lib/screens/chat_screen.dart`

- Bubble chat user/AI.
- Typing indicator.
- Quick prompt.
- Integrasi kirim pesan ke backend AI.

`lib/screens/emergency_alert_screen.dart`

- Full-screen critical alert.
- Menampilkan magnitudo, level risiko, jarak.
- Checklist tindakan cepat (Drop, Cover, Hold, dsb).
- Tombol ke chat AI.
- Tombol SOS (simulasi snackbar).

`lib/screens/history_screen.dart`

- Riwayat laporan gempa lokal.
- Ringkasan balasan AI.

`lib/screens/notifications_screen.dart`

- Daftar notifikasi masuk (berbasis `nearbyReports`).

`lib/screens/settings_screen.dart`

- Ubah tema.
- Penjelasan aturan notifikasi.
- Refresh data BMKG.
- Simulasi test peringatan.

## 5. Detail Backend API (Vercel)

### 5.1 Endpoint Publik

`GET /api/bmkg/latest`

- Ambil 1 event terbaru BMKG.
- Return: `source`, `sourceMeta`, `event`.

`GET /api/bmkg/list?limit=<n>&feed=<feed>`

- Ambil daftar event BMKG.
- `limit` default 20, max 100.
- `feed` alias yang didukung:
  - `autogempa`, `latest`, `terkini`, `realtime`
  - `m5`, `m5+`, `5+`, `5.0+`, `gempaterkini`
  - `dirasakan`, `gempadirasakan`

`POST /api/risk/score`

- Input:
  - `userLat`, `userLng`
  - `eqLat`, `eqLng`
  - `magnitude`, `depthKm`
- Return:
  - `riskScore`, `riskLevel`, `rekomendasi`, `distanceKm`

`POST /api/device/register`

- Input: `token`, `platform`, `lat`, `lng`.
- Simpan/merge ke Firestore collection `device_tokens`.

`POST /api/chat`

- Input:
  - `message`
  - `history`
  - `latestEarthquake`
  - `risk`
  - `userLocation`
- Return: `reply` (teks jawaban asisten).

`GET /api/cron/check-bmkg`

- Endpoint cron untuk push notifikasi massal.
- Otentikasi via:
  - `x-cron-secret`
  - atau `Authorization: Bearer <CRON_SECRET>`
- Query pendukung:
  - `force=1` untuk paksa kirim notifikasi.
  - `dummy=1` untuk event simulasi (dapat dipadu query magnitudo/lokasi).

### 5.2 Library Backend Inti

`api/_lib/bmkg.ts`

- Mapping feed BMKG:
  - `autogempa.json`
  - `gempaterkini.json`
  - `gempadirasakan.json`
- Parser robust untuk:
  - `Coordinates`
  - fallback `Lintang/Bujur` hemisphere (`LS/BB` jadi negatif).
- Dukungan override env:
  - `BMKG_URL` (prioritas tertinggi)
  - `BMKG_FEED`

`api/_lib/risk.ts`

Formula skor:

- `base = magnitude * 15`
- `distPenalty = min(60, distanceKm * 0.25)`
- `depthFactor`:
  - 15 jika kedalaman <= 30 km
  - 8 jika <= 70 km
  - 3 jika > 70 km
- `score = clamp(base + depthFactor - distPenalty, 0..100)`

Mapping level:

- `>= 85` EKSTREM
- `>= 70` TINGGI
- `>= 40` SEDANG
- sisanya RENDAH

`api/_lib/llm.ts`

Pipeline jawaban chat:

1. Validasi pesan kosong.
2. Deteksi pertanyaan casual/identitas bot.
3. Scope check (hanya konteks bencana).
4. Triage kondisi bahaya langsung.
5. Cek nowcast BMKG untuk query kondisi "hari ini/sekarang".
6. Cek query gempa terbaru berbasis context.
7. Cek prakiraan cuaca 3 hari.
8. Fallback cascade provider:
   - Gemini
   - Groq
   - Rule-based response

Guardrails:

- Wajib Bahasa Indonesia.
- Paksa format respons dengan `Status:` dan `Sumber:` jika provider tidak menyertakan.
- Retry + timeout untuk request provider.

`api/_lib/nowcast.ts`

- Parse RSS/CAP BMKG nowcast.
- Matching lokasi berbasis token.

`api/_lib/bmkg-weather.ts`

- Ambil prakiraan cuaca BMKG berbasis kode lokasi (`adm4`).
- Ringkas 3 hari ke format temp min/max, cuaca, peluang hujan.

`api/_lib/firestore.ts`, `api/_lib/fcm.ts`

- Init Firebase Admin dari env service account.
- Kirim push FCM dengan payload notification + data.
- Android channel/sound dan APNS sound diset untuk sirene.

## 6. Logika Cron Notifikasi

File: `api/cron/check-bmkg.ts`

Langkah kerja:

1. Validasi metode + secret.
2. Ambil event BMKG terbaru (atau dummy event jika mode test).
3. Cegah duplikasi kirim dengan `system/earthquake_state.lastProcessedDateTime`.
4. Ambil semua device token dari Firestore.
5. Hitung risk/distance per device.
6. Kirim notifikasi jika:
   - jarak ke episentrum <= 200 km, atau
   - magnitudo >= 5.0
   - kecuali mode `force`/`dummy` (kirim paksa)
7. Hapus token invalid dari Firestore jika FCM return error invalid token.
8. Simpan state event terakhir (kecuali force/dummy mode).

## 7. Data Firestore yang Dipakai

`device_tokens/{docId}`

- `token`: string
- `platform`: string
- `lat`: number
- `lng`: number
- `updatedAt`: server timestamp

`system/earthquake_state`

- `lastProcessedDateTime`: string ISO
- `updatedAt`: server timestamp

## 8. Konfigurasi Environment

### 8.1 Backend (Vercel / local env)

Minimal wajib:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`
- `CRON_SECRET`

Opsional BMKG:

- `BMKG_FEED` (`autogempa`/`m5`/`dirasakan`)
- `BMKG_URL` (override URL feed langsung)

Opsional AI:

- `GEMINI_API_KEY`
- `GEMINI_MODEL` (default `gemini-1.5-flash`)
- `GROQ_API_KEY`
- `GROQ_MODEL` (default `llama-3.3-70b-versatile`)

### 8.2 Flutter runtime

- `API_BASE_URL` via `--dart-define`.

Contoh:

```bash
flutter run --dart-define=API_BASE_URL=https://<domain-backend>
```

## 9. Dependency Utama

### 9.1 Flutter (`pubspec.yaml`)

- State/UI/network: `provider`, `http`, `google_fonts`, `intl`
- Lokasi: `geolocator`, `geocoding`, `permission_handler`
- Firebase notif: `firebase_core`, `firebase_messaging`
- Notif lokal: `flutter_local_notifications`
- Persistensi: `shared_preferences`
- Peta: `flutter_map`, `latlong2`
- Audio: `audioplayers`

### 9.2 Backend (`package.json`)

- `firebase-admin`
- `fast-xml-parser`
- TypeScript toolchain (`typescript`, `@vercel/node`, `@types/node`)

## 10. Testing yang Ada

Flutter:

- `test/widget_test.dart` (uji tampilan bottom nav).

Backend script manual (`api/_test/`):

- `test-chatbot-questions.js`
- `test-llm-providers.ts`
- `test_fcm_siren.js`

Catatan: script test backend bersifat manual/integrasi dan memerlukan env/token nyata.

## 11. Catatan Teknis Penting (Current State)

1. Ada perbedaan jadwal cron di dokumentasi lama vs kode aktif.
   - `vercel.json` saat ini: `0 2 * * *` (sekali per hari, jam 02:00 UTC).
   - Beberapa dokumen lama menyebut interval 5 menit.
2. `README.md` dan `DEPLOY_VERCEL_FIREBASE.md` belum sepenuhnya sinkron dengan semua perubahan terbaru.
3. `llm.ts` saat ini menggunakan fallback Gemini -> Groq -> rule-based.
   - Beberapa script test lama masih menyebut OpenAI.
4. `.env.example` belum mencantumkan variabel Groq, meskipun kode mendukungnya.

## 12. Cara Menjalankan Singkat

### Flutter app

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://<domain-backend-anda>
```

### Type check backend

```bash
npm run typecheck
```

---

Dokumen ini fokus pada kondisi implementasi aktual di repository saat ini.
