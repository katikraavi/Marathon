enum HealthState { normal, warning, emergency }

class VitalsThresholds {
  // Heartbeat (5s rolling average)
  static const int heartbeatNormalMin = 60;
  static const int heartbeatNormalMax = 150;
  static const int heartbeatWarningMin = 40;
  static const int heartbeatWarningMax = 170;

  // Breath rate (5s rolling average)
  static const int breathNormalMin = 45;
  static const int breathNormalMax = 60;
  static const int breathWarningMin = 25;
  static const int breathWarningMax = 85;

  // Systolic BP (mmHg)
  static const int systolicNormalMax = 130;
  static const int systolicWarningMax = 140;

  // Diastolic BP (mmHg)
  static const int diastolicNormalMax = 80;
  static const int diastolicWarningMax = 90;

  // Blood Oxygen (% saturation)
  static const int bloodOxygenNormalMin = 95;
  static const int bloodOxygenWarningMin = 90;

  // Temperature (tenths of °C, e.g., 38.6 = 386)
  static const int temperatureNormalMin = 360; // 36.0°C
  static const int temperatureNormalMax = 385; // 38.5°C
  static const int temperatureWarningMax = 390; // 39.0°C
}

class VitalDetail {
  final String name;
  final String value;
  final String unit;
  final HealthState status;
  final String normalRange;

  VitalDetail({
    required this.name,
    required this.value,
    required this.unit,
    required this.status,
    required this.normalRange,
  });
}

class HealthStatus {
  final HealthState state;
  final String reason;
  final List<VitalDetail> vitalDetails;

  HealthStatus({
    required this.state,
    required this.reason,
    required this.vitalDetails,
  });

  static HealthStatus calculate({
    required int heartbeat,
    required int breath,
    required int systolicBp,
    required int diastolicBp,
    required int bloodOxygen,
    required int temperature,
  }) {
    final warnings = <String>[];
    final emergencies = <String>[];
    final vitalDetails = <VitalDetail>[];

    // Check heartbeat
    HealthState hbState = HealthState.normal;
    if (heartbeat < VitalsThresholds.heartbeatWarningMin ||
        heartbeat > VitalsThresholds.heartbeatWarningMax) {
      emergencies.add('Heartbeat abnormal: $heartbeat BPM');
      hbState = HealthState.emergency;
    } else if (heartbeat < VitalsThresholds.heartbeatNormalMin ||
        heartbeat > VitalsThresholds.heartbeatNormalMax) {
      warnings.add('Heartbeat warning: $heartbeat BPM');
      hbState = HealthState.warning;
    }
    vitalDetails.add(VitalDetail(
      name: 'Heartbeat',
      value: '$heartbeat',
      unit: 'BPM',
      status: hbState,
      normalRange: '${VitalsThresholds.heartbeatNormalMin}-${VitalsThresholds.heartbeatNormalMax}',
    ));

    // Check breath rate
    HealthState brState = HealthState.normal;
    if (breath < VitalsThresholds.breathWarningMin ||
        breath > VitalsThresholds.breathWarningMax) {
      emergencies.add('Breath rate abnormal: $breath /min');
      brState = HealthState.emergency;
    } else if (breath < VitalsThresholds.breathNormalMin ||
        breath > VitalsThresholds.breathNormalMax) {
      warnings.add('Breath rate warning: $breath /min');
      brState = HealthState.warning;
    }
    vitalDetails.add(VitalDetail(
      name: 'Breath Rate',
      value: '$breath',
      unit: '/min',
      status: brState,
      normalRange: '${VitalsThresholds.breathNormalMin}-${VitalsThresholds.breathNormalMax}',
    ));

    // Check Systolic BP
    HealthState sbpState = HealthState.normal;
    if (systolicBp > VitalsThresholds.systolicWarningMax) {
      emergencies.add('Systolic BP critical: $systolicBp mmHg');
      sbpState = HealthState.emergency;
    } else if (systolicBp > VitalsThresholds.systolicNormalMax) {
      warnings.add('Systolic BP elevated: $systolicBp mmHg');
      sbpState = HealthState.warning;
    }
    vitalDetails.add(VitalDetail(
      name: 'Systolic BP',
      value: '$systolicBp',
      unit: 'mmHg',
      status: sbpState,
      normalRange: '< ${VitalsThresholds.systolicNormalMax}',
    ));

    // Check Diastolic BP
    HealthState dbpState = HealthState.normal;
    if (diastolicBp > VitalsThresholds.diastolicWarningMax) {
      emergencies.add('Diastolic BP critical: $diastolicBp mmHg');
      dbpState = HealthState.emergency;
    } else if (diastolicBp > VitalsThresholds.diastolicNormalMax) {
      warnings.add('Diastolic BP elevated: $diastolicBp mmHg');
      dbpState = HealthState.warning;
    }
    vitalDetails.add(VitalDetail(
      name: 'Diastolic BP',
      value: '$diastolicBp',
      unit: 'mmHg',
      status: dbpState,
      normalRange: '< ${VitalsThresholds.diastolicNormalMax}',
    ));

    // Check blood oxygen
    HealthState boState = HealthState.normal;
    if (bloodOxygen < VitalsThresholds.bloodOxygenWarningMin) {
      emergencies.add('Blood oxygen critical: $bloodOxygen%');
      boState = HealthState.emergency;
    } else if (bloodOxygen < VitalsThresholds.bloodOxygenNormalMin) {
      warnings.add('Blood oxygen warning: $bloodOxygen%');
      boState = HealthState.warning;
    }
    vitalDetails.add(VitalDetail(
      name: 'Blood Oxygen',
      value: '$bloodOxygen',
      unit: '%',
      status: boState,
      normalRange: '${VitalsThresholds.bloodOxygenNormalMin}-100',
    ));

    // Check temperature
    HealthState tempState = HealthState.normal;
    double tempC = temperature / 10.0;
    if (temperature > VitalsThresholds.temperatureWarningMax) {
      emergencies.add('Temperature critical: ${tempC}°C');
      tempState = HealthState.emergency;
    } else if (temperature > VitalsThresholds.temperatureNormalMax ||
        temperature < VitalsThresholds.temperatureNormalMin) {
      warnings.add('Temperature warning: ${tempC}°C');
      tempState = HealthState.warning;
    }
    vitalDetails.add(VitalDetail(
      name: 'Temperature',
      value: '${tempC.toStringAsFixed(1)}',
      unit: '°C',
      status: tempState,
      normalRange: '36.0-38.5',
    ));

    // Determine final state
    if (emergencies.isNotEmpty) {
      return HealthStatus(
        state: HealthState.emergency,
        reason: emergencies.first,
        vitalDetails: vitalDetails,
      );
    } else if (warnings.length >= 2) {
      return HealthStatus(
        state: HealthState.emergency,
        reason: '${warnings.length} warnings detected',
        vitalDetails: vitalDetails,
      );
    } else if (warnings.isNotEmpty) {
      return HealthStatus(
        state: HealthState.warning,
        reason: warnings.first,
        vitalDetails: vitalDetails,
      );
    } else {
      return HealthStatus(
        state: HealthState.normal,
        reason: 'All vitals normal',
        vitalDetails: vitalDetails,
      );
    }
  }
}
