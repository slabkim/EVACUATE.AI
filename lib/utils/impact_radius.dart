double estimateImpactRadiusKm({
  required double magnitude,
  required double depthKm,
}) {
  // Heuristic: stronger magnitude increases area, deeper quakes reduce impact.
  final raw = (magnitude * 35) - (depthKm * 0.2);
  final clamped = raw.clamp(50, 350);
  return clamped is double ? clamped : clamped.toDouble();
}
