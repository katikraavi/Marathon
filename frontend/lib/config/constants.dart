class AppConstants {
  // Default login credentials (test req #4)
  static const String defaultUsername = 'admin';
  static const String defaultPassword = 'admin123';

  // WebSocket configuration - Platform specific
  // For Android emulator: 10.0.2.2, for iOS Simulator: localhost, for real device: actual IP
  static const String wsBaseUrlAndroid = 'ws://10.0.2.2:8080';
  static const String wsBaseUrlIOS = 'ws://localhost:8080';

  // WebSocket endpoints
  static const String timeBasedReportsEndpoint = '/time_based_reports';
  static const String eventBasedReportsEndpoint = '/event_based_reports';

  // Data caching limits (optimized for 500 runners)
  static const int maxReportsPerDevice = 60; // ~1 minute at 1 report/second (reduced from 600)
  static const int reportWindowSeconds = 60; // 1 minute (reduced from 600)

  // Notification configuration
  static const String notificationChannelId = 'marathon_safety_alerts';
  static const String notificationChannelName = 'Marathon Safety Alerts';
  static const String notificationChannelDescription = 'Alerts for runner health warnings';

  // UI constants
  static const double chartHeightPx = 250;
  static const int chartDataPointsMax = 100; // Max points on chart (10 mins at 1 pt/sec)
}
