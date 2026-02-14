/**
 * TEST FCM NOTIFICATION WITH SIREN SOUND
 *
 * Prerequisites:
 * 1. Install firebase-admin: npm install firebase-admin
 * 2. Get service-account.json from Firebase Console (Settings -> Service Accounts -> Generate new private key)
 * 3. Place service-account.json in the same directory as this script
 * 4. Get FCM Token from your app (you can print it in the debug console of the app)
 */

const admin = require("firebase-admin");
const serviceAccount = require("./service-account.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// REPLACE WITH YOUR ACTUAL FCM DEVICE TOKEN
const registrationToken =
  "epV07G8sSjODC4LsL0Wbd8:APA91bEh1JWfpo0JRo360v42r14XPPbhuMHduNTEdXhZAWWFNQdFJY1GgfQsmi3f5NApxJJvNhAQw5XAXWO5KfWNPoGtMTeUWcuoBH4KjqUw24o-OIxLvY0";

const message = {
  // IMPORTANT: Remove 'notification' field to make this a DATA-ONLY message
  // This forces the app to handle notification display, ensuring custom sound works
  data: {
    // Data expected by the app to trigger EmergencyAlertScreen
    title: "🚨 PERINGATAN KRITIS (REAL FCM)",
    body: "Gempa Terdeteksi! Cari perlindungan sekarang!",
    magnitude: "6.8",
    depth: "12",
    wilayah: "Jawa Barat (Simulasi FCM)",
    riskLevel: "TINGGI",
    riskScore: "85",
    distanceKm: "25.0",
    time: new Date().toISOString(),
    eqLat: "-7.2245",
    eqLng: "107.9068",
  },
  android: {
    priority: "high",
  },
  token: registrationToken,
};

console.log("Sending message...");

admin
  .messaging()
  .send(message)
  .then((response) => {
    console.log("Successfully sent message:", response);
    process.exit(0);
  })
  .catch((error) => {
    console.log("Error sending message:", error);
    process.exit(1);
  });
