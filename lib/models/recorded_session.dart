// lib/models/recorded_session.dart
import 'package:fl_chart/fl_chart.dart';

class RecordedSession {
  final String id;
  final DateTime timestamp;
  // Her bir verici için bileşke (resultant) verisini tutacağız.
  final List<FlSpot> v1Data;
  final List<FlSpot> v2Data;
  final List<FlSpot> v3Data;
  final List<FlSpot> v4Data;

  RecordedSession({
    required this.id,
    required this.timestamp,
    required this.v1Data,
    required this.v2Data,
    required this.v3Data,
    required this.v4Data,
  });

  Map<String, dynamic> toJson() {
    List<Map<String, double>> spotsToJson(List<FlSpot> spots) {
      return spots.map((spot) => {'x': spot.x, 'y': spot.y}).toList();
    }

    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'v1Data': spotsToJson(v1Data),
      'v2Data': spotsToJson(v2Data),
      'v3Data': spotsToJson(v3Data),
      'v4Data': spotsToJson(v4Data),
    };
  }

  factory RecordedSession.fromJson(Map<String, dynamic> json) {
    List<FlSpot> jsonToSpots(List<dynamic> jsonList) {
      return jsonList.map((item) {
        final pointMap = item as Map<String, dynamic>;
        final x = (pointMap['x'] as num).toDouble();
        final y = (pointMap['y'] as num).toDouble();
        return FlSpot(x, y);
      }).toList();
    }

    return RecordedSession(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      v1Data: jsonToSpots(json['v1Data'] as List? ?? []),
      v2Data: jsonToSpots(json['v2Data'] as List? ?? []),
      v3Data: jsonToSpots(json['v3Data'] as List? ?? []),
      v4Data: jsonToSpots(json['v4Data'] as List? ?? []),
    );
  }
}
