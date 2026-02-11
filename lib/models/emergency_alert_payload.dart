import 'earthquake_event.dart';
import 'risk_result.dart';

class EmergencyAlertPayload {
  EmergencyAlertPayload({
    required this.event,
    required this.risk,
    required this.distanceKm,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  final EarthquakeEvent event;
  final RiskResult risk;
  final double distanceKm;
  final DateTime receivedAt;
}
