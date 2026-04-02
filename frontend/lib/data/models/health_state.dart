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

class HealthStatus {
  final HealthState state;
  final String reason;

  HealthStatus({required this.state, required this.reason});

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

    // Check heartbeat
    if (heartbeat < VitalsThresholds.heartbeatWarningMin ||
        heartbeat > VitalsThresholds.heartbeatWarningMax) {
      emergencies.add('Heartbeat abnormal: $heartbeat BPM');
    } else if (heartbeat < VitalsThresholds.heartbeatNormalMin ||
        heartbeat > VitalsThresholds.heartbeatNormalMax) {
      warnings.add('Heartbeat warning: $heartbeat BPM');
    }

    // Check breath rate
    if (breath < VitalsThresholds.breathWarningMin ||
        breath > VitalsThresholds.breathWarningMax) {
      emergencies.add('Breath rate abnormal: $breath /min');
    } else if (breath < VitalsThresholds.breathNormalMin ||
        breath > VitalsThresholds.breathNormalMax) {
      warnings.add('Breath rate warning: $breath /min');
    }

    // Check Systolic BP
    if (systolicBp > VitalsThresholds.systolicWarningMax) {
      emergencies.add('Systolic BP critical: $systolicBp mmHg');
    } else if (systolicBp > VitalsThresholds.systolicNormalMax) {
      warnings.add('Systolic BP elevated: $systolicBp mmHg');
    }

    // Check Diastolic BP
    if (diastolicBp > VitalsThresholds.diastolicWarningMax) {
      emergencies.add('Diastolic BP critical: $diastolicBp mmHg');
    } else if (diastolicBp > VitalsThresholds.diastolicNormalMax) {
      warnings.add('Diastolic BP elevated: $diastolicBp mmHg');
    }

    // Check blood oxygen
    if (bloodOxygen < VitalsThresholds.bloodOxygenWarningMin) {
      emergencies.add('Blood oxygen critical: $bloodOxygen%');
    } else if (bloodOxygen < VitalsThresholds.bloodOxygenNormalMin) {
      warnings.add('Blood oxygen warning: $bloodOxygen%');
    }

    // Check temperature
    if (temperature > VitalsThresholds.temperatureWarningMax) {
      emergencies.add('Temperature critical: ${temperature / 10}°C');
    } else if (temperature > VitalsThresholds.temperatureNormalMax ||
        temperature < VitalsThresholds.temperatureNormalMin) {
      warnings.add('Temperature warning: ${temperature / 10}°C');
    }

    // Determine final state (test req #11)
    if (emergencies.isNotEmpty) {
      return HealthStatus(
        state: HealthState.emergency,
        reason: emergencies.first,
      );
    } else if (warnings.length >= 2) {
      return HealthStatus(
        state: HealthState.emergency,
        reason: '${warnings.length} warnings detected',
      );
    } else if (warnings.isNotEmpty) {
      return HealthStatus(
        state: HealthState.warning,
        reason: warnings.first,
      );
    } else {
      return HealthStatus(
        state: HealthState.normal,
        reason: 'All vitals normal',
      );
    }
  }
}
