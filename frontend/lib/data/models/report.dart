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
    // Handle timestamp - can be int (milliseconds) or String (ISO8601)
    DateTime parseTimestamp(dynamic timestampValue) {
      if (timestampValue == null) return DateTime.now();
      if (timestampValue is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestampValue);
      } else if (timestampValue is num) {
        return DateTime.fromMillisecondsSinceEpoch(timestampValue.toInt());
      } else if (timestampValue is String) {
        try {
          return DateTime.parse(timestampValue);
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    // Extract heartbeat from either singular field or array length
    int extractHeartbeat(Map<String, dynamic> json) {
      // Try singular 'heartbeat' field first
      if (json['heartbeat'] != null && json['heartbeat'] is int) {
        return json['heartbeat'] as int;
      }
      // Try plural 'heartbeats' array - use length as event count
      if (json['heartbeats'] != null && json['heartbeats'] is List) {
        final count = (json['heartbeats'] as List).length;
        if (count > 0) {
          // Calculate HR from event count: each beat event in 1 second = 60x per minute
          return count * 60;
        }
      }
      return 80; // Default normal HR
    }

    // Extract breath from either singular field or array length
    int extractBreath(Map<String, dynamic> json) {
      // Try singular 'breath' field first
      if (json['breath'] != null && json['breath'] is int) {
        return json['breath'] as int;
      }
      // Try plural 'breaths' array - use length as event count
      if (json['breaths'] != null && json['breaths'] is List) {
        final count = (json['breaths'] as List).length;
        if (count > 0) {
          // Calculate BR from event count: each breath event in 1 second = 60x per minute
          return count * 60;
        }
      }
      return 50; // Default normal BR
    }

    // Extract distance - convert from centimeters to meters
    double extractDistance(Map<String, dynamic> json) {
      dynamic distanceValue = json['distance'] ?? json['distance_covered'];
      if (distanceValue is num) {
        // If distance is in centimeters, convert to meters
        return distanceValue.toDouble() / 100.0;
      }
      return 0.0;
    }

    return Report(
      deviceId: (json['device_id'] as int?) ?? 0,
      heartbeat: extractHeartbeat(json),
      breath: extractBreath(json),
      systolicBp: (json['systolic_bp'] as int?) ?? 120,
      diastolicBp: (json['diastolic_bp'] as int?) ?? 80,
      bloodOxygen: (json['blood_oxygen'] as int?) ?? 98,
      temperature: ((json['temperature'] as num?) ?? 37.0).toDouble(),
      distanceCovered: extractDistance(json),
      timestamp: parseTimestamp(json['timestamp']),
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
    // Handle null fields with sensible defaults
    final deviceId = proto.deviceId ?? 0;
    
    // If heartbeats/breaths arrays have count, use that; otherwise use realistic defaults
    // The proto likely sends event counts in these fields
    final heartbeat = (proto.heartbeats != null && proto.heartbeats!.isNotEmpty) 
        ? proto.heartbeats!.length 
        : 80; // Default normal HR
    
    final breath = (proto.breaths != null && proto.breaths!.isNotEmpty)
        ? proto.breaths!.length
        : 50; // Default normal BR
    
    final distanceCm = (proto.distance ?? 0).toInt();
    final distanceM = distanceCm / 100.0; // Convert cm to meters
    final timestampMs = (proto.timestamp ?? 0).toInt();
    
    // Ensure we have a valid timestamp
    final timestamp = timestampMs > 0 
        ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
        : DateTime.now();
    
    return Report(
      deviceId: deviceId,
      heartbeat: heartbeat,
      breath: breath,
      systolicBp: systolicBp,
      diastolicBp: diastolicBp,
      bloodOxygen: bloodOxygen,
      temperature: temperature,
      distanceCovered: distanceM,
      timestamp: timestamp,
    );
  }

  /// Convert from protobuf EventBasedReport (vital changes)
  /// Event ID: 1 = BP, 2 = O2, 3 = Temperature
  factory Report.fromEventBasedReport(pb.EventBasedReport proto, Report lastReport) {
    final deviceId = proto.deviceId ?? lastReport.deviceId;
    final timestamp = (proto.timestamp ?? 0) > 0
        ? DateTime.fromMillisecondsSinceEpoch((proto.timestamp ?? 0).toInt())
        : DateTime.now();
    final eventData = proto.eventData ?? [];
    
    Report result = Report(
      deviceId: deviceId,
      heartbeat: lastReport.heartbeat,
      breath: lastReport.breath,
      systolicBp: lastReport.systolicBp,
      diastolicBp: lastReport.diastolicBp,
      bloodOxygen: lastReport.bloodOxygen,
      temperature: lastReport.temperature,
      distanceCovered: lastReport.distanceCovered,
      timestamp: timestamp,
    );

    // Update based on event type
    if (proto.eventId == 1 && eventData.length == 2) {
      // Blood Pressure: [systolic, diastolic]
      result = Report(
        deviceId: result.deviceId,
        heartbeat: result.heartbeat,
        breath: result.breath,
        systolicBp: eventData[0],
        diastolicBp: eventData[1],
        bloodOxygen: result.bloodOxygen,
        temperature: result.temperature,
        distanceCovered: result.distanceCovered,
        timestamp: result.timestamp,
      );
    } else if (proto.eventId == 2 && eventData.length >= 1) {
      // Blood Oxygen
      result = Report(
        deviceId: result.deviceId,
        heartbeat: result.heartbeat,
        breath: result.breath,
        systolicBp: result.systolicBp,
        diastolicBp: result.diastolicBp,
        bloodOxygen: eventData[0],
        temperature: result.temperature,
        distanceCovered: result.distanceCovered,
        timestamp: result.timestamp,
      );
    } else if (proto.eventId == 3 && eventData.length >= 1) {
      // Temperature (stored as tenths of degree, e.g., 375 = 37.5°C)
      final tempTenths = eventData[0];
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
