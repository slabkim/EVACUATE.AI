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
    "dBeDDbUoTWi0aDyzKyI-YW:APA91bFmCWafOi-vCvSu9XBLPiBHubGKJUA7d_VMwwdayaji6GNIR4wQyRmtt3PWU7YdZfeYjfoMcFrtv13OPrFug_b4dtgtkpFaz1LlIgfVECsNC2SgzWQ";

const message = {
    // Hybrid payload:
    // - notification: more reliable for background/terminated app
    // - data: still used for in-app payload parsing
    notification: {
        title: "Peringatan Kritis (REAL FCM)",
        body: "Gempa Terdeteksi! Cari perlindungan sekarang!",
    },
    data: {
        title: "Peringatan Kritis (REAL FCM)",
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
        notification: {
            channelId: "evacuate_alert_channel_v4",
            sound: "sirene",
        },
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
