class RiskResult {
  RiskResult({
    required this.riskScore,
    required this.riskLevel,
    required this.rekomendasi,
  });

  final int riskScore;
  final String riskLevel;
  final String rekomendasi;

  factory RiskResult.fromJson(Map<String, dynamic> json) {
    final scoreRaw = json['riskScore'];
    final score = scoreRaw is num
        ? scoreRaw.toDouble()
        : double.tryParse('${scoreRaw ?? 0}') ?? 0;

    return RiskResult(
      riskScore: (score.round().clamp(0, 100) as num).toInt(),
      riskLevel: '${json['riskLevel'] ?? 'RENDAH'}',
      rekomendasi:
          '${json['rekomendasi'] ?? 'Tetap tenang dan pantau informasi resmi BMKG.'}',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'rekomendasi': rekomendasi,
    };
  }
}
