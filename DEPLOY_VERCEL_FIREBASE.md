# Panduan Deploy EVACUATE.AI ke Vercel + Setup Firebase

Dokumen ini fokus pada:
- Deploy backend serverless (`api/*`) ke Vercel
- Konfigurasi Firebase (Firestore + FCM + Service Account)
- Koneksi Flutter app ke backend

## 1. Prasyarat

- Akun Vercel
- Akun Firebase (Google Cloud)
- Flutter SDK terpasang
- Project ini sudah ada di Git repository (GitHub/GitLab/Bitbucket)

## 2. Setup Firebase

### 2.1 Buat Project Firebase

1. Buka Firebase Console.
2. Buat project baru, misal: `evacuateai-prod`.

### 2.2 Aktifkan Firestore

1. Masuk menu **Firestore Database**.
2. Klik **Create database**.
3. Pilih mode yang sesuai (umumnya Production).
4. Pilih region terdekat (misal `asia-southeast2`/`asia-southeast1`).

Catatan:
- Backend menggunakan Firebase Admin SDK, jadi tidak bergantung pada rule client.
- Untuk keamanan awal, Anda bisa menutup akses client langsung:

```txt
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### 2.3 Aktifkan Cloud Messaging (FCM)

1. Masuk menu **Cloud Messaging**.
2. Pastikan FCM aktif di project.
3. Untuk iOS, siapkan APNs Key/Certificate (lihat 2.6).

### 2.4 Daftarkan App Android dan iOS

Android:
- Package name saat ini di project: `com.example.evacuateai` (lihat `android/app/build.gradle.kts`).
- Tambahkan app Android di Firebase dengan package tersebut.
- Unduh `google-services.json`, letakkan di `android/app/google-services.json`.

iOS:
- Tambahkan app iOS dengan bundle identifier yang Anda pakai.
- Unduh `GoogleService-Info.plist`, letakkan di `ios/Runner/GoogleService-Info.plist`.

### 2.5 Konfigurasi FlutterFire (disarankan)

Jalankan:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<FIREBASE_PROJECT_ID> --platforms=android,ios
```

Tujuan:
- Menghasilkan konfigurasi Firebase Flutter sesuai platform.
- Membantu sinkronisasi konfigurasi Android/iOS untuk plugin Firebase.

### 2.6 Konfigurasi iOS Push (APNs)

1. Apple Developer -> buat APNs Auth Key (`.p8`) atau certificate.
2. Upload ke Firebase Console -> Cloud Messaging -> iOS app.
3. Pastikan capability Push Notifications dan Background Modes (`remote-notification`) aktif di iOS project.

## 3. Service Account Firebase untuk Backend

Backend Vercel butuh kredensial Admin SDK:

1. Firebase Console -> Project Settings -> Service Accounts.
2. Generate private key (JSON).
3. Ambil nilai:
- `project_id` -> `FIREBASE_PROJECT_ID`
- `client_email` -> `FIREBASE_CLIENT_EMAIL`
- `private_key` -> `FIREBASE_PRIVATE_KEY`

Penting:
- Di Vercel, isi `FIREBASE_PRIVATE_KEY` dengan newline escaped:

```txt
-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n
```

## 4. Deploy Backend ke Vercel

### 4.1 Import Project

1. Buka Vercel -> **Add New Project**.
2. Pilih repository project ini.
3. Root project: folder root repository (yang berisi `api/` dan `vercel.json`).

### 4.2 Environment Variables (wajib)

Tambahkan di Vercel Project Settings -> Environment Variables:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`
- `CRON_SECRET`
- `BMKG_FEED` (opsional: `autogempa` | `m5` | `dirasakan`, default `autogempa`)
- `BMKG_URL` (opsional, override langsung endpoint BMKG apa pun)
- `GEMINI_API_KEY`
- `GEMINI_MODEL` (opsional, default `gemini-1.5-flash`)

Catatan:
- Jika `BMKG_URL` diisi, nilai ini diprioritaskan dibanding `BMKG_FEED`.
- Isi `BMKG_FEED` tanpa kutip, contoh: `dirasakan`.
- Jika ingin memakai `BMKG_FEED`, kosongkan/hapus `BMKG_URL`.

### 4.3 Deploy

Lakukan deploy dari Vercel UI (atau push commit baru).

Endpoint utama setelah deploy:
- `GET /api/bmkg/latest`
- `GET /api/bmkg/list?limit=20`
- `POST /api/device/register`
- `POST /api/risk/score`
- `POST /api/chat`
- `GET /api/cron/check-bmkg`

## 5. Cron BMKG di Vercel

File `vercel.json` sudah berisi jadwal:
- `*/5 * * * *` untuk `/api/cron/check-bmkg`

Endpoint cron saat ini menerima secret dari:
- Header `x-cron-secret: <CRON_SECRET>`, atau
- Header `Authorization: Bearer <CRON_SECRET>`

Tes manual:

```bash
curl -H "x-cron-secret: <CRON_SECRET>" https://<domain-anda>/api/cron/check-bmkg
```

Tes notifikasi paksa (untuk QA, abaikan filter magnitudo/radius):

```bash
curl -H "x-cron-secret: <CRON_SECRET>" "https://<domain-anda>/api/cron/check-bmkg?force=1"
```

## 6. Struktur Data Firestore yang Dipakai

Collection/doc yang dipakai backend:

- `device_tokens/{docId}`
  - `token` (string)
  - `platform` (string)
  - `updatedAt` (timestamp)
  - `lat` (number)
  - `lng` (number)
  - `radiusKm` (number)

- `system/earthquake_state`
  - `lastProcessedDateTime` (string ISO)
  - `updatedAt` (timestamp)

## 7. Koneksi Flutter ke Backend Vercel

Jalankan app Flutter dengan base URL backend:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://<domain-backend-anda>
```

Catatan:
- Jangan hardcode API key di Flutter.
- API key LLM hanya disimpan di Vercel env.

## 8. Checklist Verifikasi Akhir

1. Buka app, izinkan lokasi + notifikasi.
2. Pastikan token masuk ke Firestore (`device_tokens`).
3. Pastikan Home memuat data dari `/api/bmkg/latest`.
4. Pastikan risk score muncul dari `/api/risk/score`.
5. Kirim pesan di AI Chat, respons tetap Bahasa Indonesia.
6. Trigger cron manual, cek notifikasi FCM terkirim ke device.
