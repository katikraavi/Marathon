class Report {
  final int deviceId;
  final int heartbeat;
  final int breath;
  final int systolicBp;
  final int diastolicBp;
  final int bloodOxygen;
  final int temperature;
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
      temperature: json['temperature'] as int,
      distanceCovered: (json['distance_covered'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
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
