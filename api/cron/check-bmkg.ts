import type { VercelRequest, VercelResponse } from "@vercel/node";
import { FieldValue } from "firebase-admin/firestore";

import type { LatestEarthquakeEvent } from "../_lib/bmkg";
import { fetchLatestEarthquake } from "../_lib/bmkg";
import { sendPushToToken } from "../_lib/fcm";
import { db } from "../_lib/firestore";
import { calculateRisk } from "../_lib/risk";

interface DeviceRecord {
  token: string;
  lat: number;
  lng: number;
}

const NOTIFICATION_RADIUS_KM = 200;

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return res.status(405).json({ error: "Metode tidak diizinkan." });
  }

  if (!isAuthorized(req)) {
    return res.status(401).json({ error: "Akses cron tidak sah." });
  }

  try {
    const isForceTest = parseBooleanQuery(req.query.force);
    const isDummyEvent = parseBooleanQuery(req.query.dummy);
    const event = isDummyEvent
      ? buildDummyEvent(req.query)
      : await fetchLatestEarthquake();

    const firestore = db();
    const stateRef = firestore.collection("system").doc("earthquake_state");
    const stateSnapshot = await stateRef.get();
    const lastProcessedDateTime = stateSnapshot.data()
      ?.lastProcessedDateTime as string | undefined;

    if (
      !isForceTest &&
      !isDummyEvent &&
      lastProcessedDateTime &&
      lastProcessedDateTime === event.dateTime
    ) {
      return res.status(200).json({
        success: true,
        status: "tidak_ada_event_baru",
        eventDateTime: event.dateTime,
        force: false,
        dummy: false,
      });
    }

    const devicesSnapshot = await firestore.collection("device_tokens").get();
    const devices: DeviceRecord[] = devicesSnapshot.docs
      .map((doc) => doc.data() as Partial<DeviceRecord>)
      .map((item) => ({
        token: `${item.token ?? ""}`.trim(),
        lat: toNumber(item.lat),
        lng: toNumber(item.lng),
      }));

    let scanned = 0;
    let sent = 0;
    let skipped = 0;
    let failed = 0;

    const tasks = devices.map(async (device) => {
      scanned += 1;
      if (!device.token) {
        skipped += 1;
        return;
      }

      const risk = calculateRisk({
        userLat: device.lat,
        userLng: device.lng,
        eqLat: event.eqLat,
        eqLng: event.eqLng,
        magnitude: event.magnitude,
        depthKm: event.depthKm,
      });

      // Send notification if:
      // 1. Earthquake is within 200 km from user location (any magnitude)
      // 2. OR magnitude >= 5.0 (any distance)
      const isWithinNearbyRadius = risk.distanceKm <= NOTIFICATION_RADIUS_KM;
      const isStrongEarthquake = event.magnitude >= 5.0;

      if (!isForceTest && !isDummyEvent && !isWithinNearbyRadius && !isStrongEarthquake) {
        skipped += 1;
        return;
      }

      const title =
        isForceTest || isDummyEvent
          ? "TEST Peringatan Gempa"
          : "Peringatan Gempa";
      const body = isForceTest || isDummyEvent
        ? `Uji notifikasi bencana. M${event.magnitude.toFixed(1)} - ${event.wilayah}.`
        : `M${event.magnitude.toFixed(1)} - ${event.depthKm.toFixed(0)} km - ` +
          `~${risk.distanceKm.toFixed(0)} km dari Anda. Buka aplikasi untuk panduan.`;

      try {
        await sendPushToToken({
          token: device.token,
          title,
          body,
          data: {
            magnitude: event.magnitude.toString(),
            depth: event.depthKm.toString(),
            eqLat: event.eqLat.toString(),
            eqLng: event.eqLng.toString(),
            distanceKm: risk.distanceKm.toFixed(2),
            riskLevel: risk.riskLevel,
            riskScore: risk.riskScore.toString(),
            time: event.dateTime,
            wilayah: event.wilayah,
          },
        });
        sent += 1;
      } catch (error: any) {
        // If token is invalid/expired, delete it from database
        const errorCode = error?.code || error?.errorInfo?.code || "";
        if (
          errorCode === "messaging/invalid-registration-token" ||
          errorCode === "messaging/registration-token-not-registered"
        ) {
          // Token is invalid, remove from database
          const docId = Buffer.from(device.token)
            .toString("base64url")
            .slice(0, 240);
          await firestore.collection("device_tokens").doc(docId).delete();
          console.log(`Deleted invalid token: ${docId}`);
        }
        failed += 1;
      }
    });

    await Promise.all(tasks);

    if (!isForceTest && !isDummyEvent) {
      await stateRef.set(
        {
          lastProcessedDateTime: event.dateTime,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    return res.status(200).json({
      success: true,
      status: isForceTest || isDummyEvent ? "test_terkirim" : "selesai",
      scanned,
      sent,
      skipped,
      failed,
      force: isForceTest,
      dummy: isDummyEvent,
      eventDateTime: event.dateTime,
      magnitude: event.magnitude,
      eqLat: event.eqLat,
      eqLng: event.eqLng,
      wilayah: event.wilayah,
    });
  } catch (error) {
    return res.status(500).json({
      error: "Cron gagal memproses data BMKG.",
      detail: `${error}`,
    });
  }
}

function isAuthorized(req: VercelRequest): boolean {
  const expectedSecret = process.env.CRON_SECRET;
  if (!expectedSecret) {
    return true;
  }

  const headerSecret = normalizeHeader(req.headers["x-cron-secret"]);
  const authHeader = normalizeHeader(req.headers.authorization);
  const bearerSecret = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7)
    : "";

  return headerSecret === expectedSecret || bearerSecret === expectedSecret;
}

function normalizeHeader(value: string | string[] | undefined): string {
  if (!value) {
    return "";
  }
  return Array.isArray(value) ? value[0] : value;
}

function toNumber(value: unknown): number {
  if (typeof value === "number") {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function parseBooleanQuery(value: string | string[] | undefined): boolean {
  if (!value) {
    return false;
  }
  const raw = Array.isArray(value) ? value[0] : value;
  const normalized = raw.trim().toLowerCase();
  return (
    normalized === "1" ||
    normalized === "true" ||
    normalized === "yes" ||
    normalized === "y"
  );
}

function buildDummyEvent(
  query: VercelRequest["query"],
): LatestEarthquakeEvent {
  const magnitude = Math.max(
    0,
    Math.min(10, readNumberQuery(query.magnitude ?? query.mag, 6.0)),
  );
  const depthKm = Math.max(0, readNumberQuery(query.depthKm ?? query.depth, 10));
  const eqLat = readNumberQuery(query.eqLat ?? query.lat, -6.2088);
  const eqLng = readNumberQuery(query.eqLng ?? query.lng, 106.8456);
  const wilayah =
    readStringQuery(query.wilayah ?? query.area) || "Simulasi Dummy Event";
  const dateTime = readDateTimeQuery(query.time ?? query.dateTime);

  return {
    dateTime,
    magnitude,
    depthKm,
    wilayah,
    eqLat,
    eqLng,
    potensi: "SIMULASI",
    dirasakan: "SIMULASI",
  };
}

function readNumberQuery(
  value: string | string[] | undefined,
  fallback: number,
): number {
  if (!value) {
    return fallback;
  }
  const raw = Array.isArray(value) ? value[0] : value;
  const parsed = Number.parseFloat(raw);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function readStringQuery(value: string | string[] | undefined): string {
  if (!value) {
    return "";
  }
  const raw = Array.isArray(value) ? value[0] : value;
  return raw.trim();
}

function readDateTimeQuery(value: string | string[] | undefined): string {
  const raw = readStringQuery(value);
  if (!raw) {
    return new Date().toISOString();
  }
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? new Date().toISOString() : parsed.toISOString();
}
