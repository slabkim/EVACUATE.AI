import { haversineKm } from './haversine';

export type RiskLevel = 'RENDAH' | 'SEDANG' | 'TINGGI' | 'EKSTREM';

export interface RiskInput {
  userLat: number;
  userLng: number;
  eqLat: number;
  eqLng: number;
  magnitude: number;
  depthKm: number;
}

export interface RiskOutput {
  riskScore: number;
  riskLevel: RiskLevel;
  rekomendasi: string;
  distanceKm: number;
}

export function calculateRisk(input: RiskInput): RiskOutput {
  const distanceKm = haversineKm(
    input.userLat,
    input.userLng,
    input.eqLat,
    input.eqLng,
  );
  const base = input.magnitude * 15;
  const distPenalty = Math.min(60, distanceKm * 0.25);
  const depthFactor = input.depthKm <= 30 ? 15 : input.depthKm <= 70 ? 8 : 3;

  const score = clamp(base + depthFactor - distPenalty, 0, 100);
  const riskScore = Math.round(score);
  const riskLevel = mapRiskLevel(riskScore);
  const rekomendasi = mapRecommendation(riskLevel);

  return {
    riskScore,
    riskLevel,
    rekomendasi,
    distanceKm,
  };
}

function mapRiskLevel(score: number): RiskLevel {
  if (score >= 85) {
    return 'EKSTREM';
  }
  if (score >= 70) {
    return 'TINGGI';
  }
  if (score >= 40) {
    return 'SEDANG';
  }
  return 'RENDAH';
}

function mapRecommendation(level: RiskLevel): string {
  switch (level) {
    case 'EKSTREM':
      return 'Segera lakukan Jatuhkan Diri, Lindungi Kepala, dan Bertahan. Jauhi kaca, jangan gunakan lift, dan siapkan evakuasi cepat.';
    case 'TINGGI':
      return 'Tetap siaga tinggi. Lindungi kepala, jauhi benda gantung, dan pantau arahan resmi BMKG.';
    case 'SEDANG':
      return 'Waspada potensi guncangan lanjutan. Pastikan jalur keluar aman dan perlengkapan darurat siap.';
    case 'RENDAH':
      return 'Risiko relatif rendah. Tetap tenang, cek kondisi sekitar, dan ikuti pembaruan resmi.';
  }
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}
