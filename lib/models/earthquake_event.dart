class EarthquakeEvent {
  EarthquakeEvent({
    required this.dateTime,
    required this.magnitude,
    required this.depthKm,
    required this.wilayah,
    required this.eqLat,
    required this.eqLng,
    this.potensi,
    this.dirasakan,
  });

  final DateTime dateTime;
  final double magnitude;
  final double depthKm;
  final String wilayah;
  final double eqLat;
  final double eqLng;
  final String? potensi;
  final String? dirasakan;

  factory EarthquakeEvent.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as Map<String, dynamic>?;
    final eqLat = _toDouble(
      json['eqLat'] ?? json['lat'] ?? coords?['lat'] ?? json['latitude'],
    );
    final eqLng = _toDouble(
      json['eqLng'] ?? json['lng'] ?? coords?['lng'] ?? json['longitude'],
    );

    return EarthquakeEvent(
      dateTime: DateTime.tryParse('${json['dateTime']}') ?? DateTime.now(),
      magnitude: _toDouble(json['magnitude']),
      depthKm: _toDouble(json['depthKm']),
      wilayah: '${json['wilayah'] ?? json['lokasi'] ?? 'Wilayah tidak diketahui'}',
      eqLat: eqLat,
      eqLng: eqLng,
      potensi: json['potensi']?.toString(),
      dirasakan: json['dirasakan']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'dateTime': dateTime.toIso8601String(),
      'magnitude': magnitude,
      'depthKm': depthKm,
      'wilayah': wilayah,
      'eqLat': eqLat,
      'eqLng': eqLng,
      'potensi': potensi,
      'dirasakan': dirasakan,
    };
  }

  static double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    final text = value.toString().replaceAll(',', '.');
    final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(text);
    if (match == null) {
      return 0;
    }
    return double.tryParse(match.group(0)!) ?? 0;
  }
}
