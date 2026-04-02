import 'package:frontend/generated/reports.pb.dart' as pb;

class Report {
  final int deviceId;
  final int heartbeat;
  final int breath;
  final int systolicBp;
  final int diastolicBp;
  final int bloodOxygen;
  final double temperature;
  final double distanceCovered;
  final DateTime timestamp;

  Report({
    required this.deviceId,
    required this.heartbeat,
    required this.breath,
    required this.systolicBp,
    required this.diastolicBp,
    required this.bloodOxygen,
    required this.temperature,
    required this.distanceCovered,
    required this.timestamp,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      deviceId: json['device_id'] as int,
      heartbeat: json['heartbeat'] as int,
      breath: json['breath'] as int,
      systolicBp: json['systolic_bp'] as int,
      diastolicBp: json['diastolic_bp'] as int,
      bloodOxygen: json['blood_oxygen'] as int,
      temperature: (json['temperature'] as num).toDouble(),
      distanceCovered: (json['distance_covered'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Convert from protobuf TimeBasedReport
  /// Calculates heartbeats/breaths per minute from timestamp arrays
  factory Report.fromTimeBasedReport(pb.TimeBasedReport proto, {
    int systolicBp = 120,
    int diastolicBp = 80,
    int bloodOxygen = 98,
    double temperature = 37.0,
  }) {
    final heartbeat = proto.heartbeats.length;
    final breath = proto.breaths.length;
    final distanceCm = proto.distance;
    final distanceM = distanceCm / 100.0; // Convert cm to meters
    
    return Report(
      deviceId: proto.deviceId,
      heartbeat: heartbeat,
      breath: breath,
      systolicBp: systolicBp,
      diastolicBp: diastolicBp,
      bloodOxygen: bloodOxygen,
      temperature: temperature,
      distanceCovered: distanceM,
      timestamp: DateTime.fromMillisecondsSinceEpoch(proto.timestamp.toInt()),
    );
  }

  /// Convert from protobuf EventBasedReport (vital changes)
  /// Event ID: 1 = BP, 2 = O2, 3 = Temperature
  factory Report.fromEventBasedReport(pb.EventBasedReport proto, Report lastReport) {
    Report result = Report(
      deviceId: proto.deviceId,
      heartbeat: lastReport.heartbeat,
      breath: lastReport.breath,
      systolicBp: lastReport.systolicBp,
      diastolicBp: lastReport.diastolicBp,
      bloodOxygen: lastReport.bloodOxygen,
      temperature: lastReport.temperature,
      distanceCovered: lastReport.distanceCovered,
      timestamp: DateTime.fromMillisecondsSinceEpoch(proto.timestamp.toInt()),
    );

    // Update based on event type
    if (proto.eventId == 1 && proto.eventData.length == 2) {
      // Blood Pressure: [systolic, diastolic]
      result = Report(
        deviceId: result.deviceId,
        heartbeat: result.heartbeat,
        breath: result.breath,
        systolicBp: proto.eventData[0],
        diastolicBp: proto.eventData[1],
        bloodOxygen: result.bloodOxygen,
        temperature: result.temperature,
        distanceCovered: result.distanceCovered,
        timestamp: result.timestamp,
      );
    } else if (proto.eventId == 2 && proto.eventData.length >= 1) {
      // Blood Oxygen
      result = Report(
        deviceId: result.deviceId,
        heartbeat: result.heartbeat,
        breath: result.breath,
        systolicBp: result.systolicBp,
        diastolicBp: result.diastolicBp,
        bloodOxygen: proto.eventData[0],
        temperature: result.temperature,
        distanceCovered: result.distanceCovered,
        timestamp: result.timestamp,
      );
    } else if (proto.eventId == 3 && proto.eventData.length >= 1) {
      // Temperature (stored as tenths of degree, e.g., 375 = 37.5°C)
      final tempTenths = proto.eventData[0];
      result = Report(
        deviceId: result.deviceId,
        heartbeat: result.heartbeat,
        breath: result.breath,
        systolicBp: result.systolicBp,
        diastolicBp: result.diastolicBp,
        bloodOxygen: result.bloodOxygen,
        temperature: tempTenths / 10.0,
        distanceCovered: result.distanceCovered,
        timestamp: result.timestamp,
      );
    }

    return result;
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'heartbeat': heartbeat,
    'breath': breath,
    'systolic_bp': systolicBp,
    'diastolic_bp': diastolicBp,
    'blood_oxygen': bloodOxygen,
    'temperature': temperature,
    'distance_covered': distanceCovered,
    'timestamp': timestamp.toIso8601String(),
  };
}
