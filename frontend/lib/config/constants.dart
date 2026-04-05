class AppConstants {
  // Default login credentials (test req #4)
  static const String defaultUsername = 'admin';
  static const String defaultPassword = 'admin123';

  // WebSocket configuration - Use local network IP for same WiFi
  // Backend runs on your PC at this IP:8080
  static const String wsBaseUrlAndroid = 'ws://172.31.195.26:8080';
  static const String wsBaseUrlIOS = 'ws://172.31.195.26:8080';
  
  // Desktop/Web: Use localhost (faster for local development)
  static const String wsBaseUrlLinux = 'ws://localhost:8080';
  static const String wsBaseUrlMac = 'ws://localhost:8080';
  static const String wsBaseUrlWindows = 'ws://localhost:8080';

  // WebSocket endpoints
  static const String timeBasedReportsEndpoint = '/time_based_reports';
  static const String eventBasedReportsEndpoint = '/event_based_reports';

  // Data caching limits (optimized for 500 runners)
  static const int maxReportsPerDevice = 600; // ~10 minutes at 1 report/second
  static const int reportWindowSeconds = 600; // 10 minutes

  // Notification configuration
  static const String notificationChannelId = 'marathon_safety_alerts';
  static const String notificationChannelName = 'Marathon Safety Alerts';
  static const String notificationChannelDescription = 'Alerts for runner health warnings';

  // UI constants
  static const double chartHeightPx = 250;
  static const int chartDataPointsMax = 100; // Max points on chart (10 mins at 1 pt/sec)
}
