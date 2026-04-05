import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:web_socket_channel/io.dart';
import '../../generated/reports.pb.dart';
import '../models/report.dart';
import '../../config/constants.dart';

class WebSocketService {
  late IOWebSocketChannel _timeBasedChannel;
  late IOWebSocketChannel _eventBasedChannel;
  
  final StreamController<Report> _reportStream = StreamController.broadcast();
  final StreamController<String> _eventStream = StreamController.broadcast();
  final StreamController<bool> _connectionStatus = StreamController.broadcast();

  /// Cache of last report per device for event-based report conversion
  final Map<int, Report> _lastReportsByDevice = {};

  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _keepAliveTimer;  // NEW: Keep-alive heartbeat
  Timer? _stalenessCheckTimer;  // NEW: Staleness detection
  int _reconnectAttempts = 0;
  DateTime _lastMessageTime = DateTime.now();  // NEW: Track last message
  
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const Duration keepAliveInterval = Duration(seconds: 30);  // Ping every 30s
  static const Duration stalenessThreshold = Duration(seconds: 10);  // Reconnect if no message for 10s (was 90s)

  Stream<Report> get reportStream => _reportStream.stream;
  Stream<String> get eventStream => _eventStream.stream;
  Stream<bool> get connectionStatus => _connectionStatus.stream;
  bool get isConnected => _isConnected;

  String get _baseUrl {
    if (Platform.isAndroid) {
      return AppConstants.wsBaseUrlAndroid;
    } else if (Platform.isIOS) {
      return AppConstants.wsBaseUrlIOS;
    } else if (Platform.isLinux) {
      return AppConstants.wsBaseUrlLinux;
    } else if (Platform.isMacOS) {
      return AppConstants.wsBaseUrlMac;
    } else if (Platform.isWindows) {
      return AppConstants.wsBaseUrlWindows;
    }
    // Default to localhost for web and other platforms
    return 'ws://localhost:8080';
  }

  Future<void> connect() async {
    try {
      // Clean up old channels before reconnecting
      try {
        _timeBasedChannel.sink.close();
      } catch (_) {}
      try {
        _eventBasedChannel.sink.close();
      } catch (_) {}
      
      if (_reconnectAttempts > 0) {
        print('[WebSocket] 🔄 Attempting reconnection (attempt ${_reconnectAttempts + 1})...');
      } else {
        print('[WebSocket] 🔗 Initial connection attempt...');
      }
      
      // Construct full WebSocket URLs
      final timeBasedUrl = '$_baseUrl${AppConstants.timeBasedReportsEndpoint}';
      final eventBasedUrl = '$_baseUrl${AppConstants.eventBasedReportsEndpoint}';

      // Connect time-based reports FIRST (primary data source)
      try {
        _timeBasedChannel = IOWebSocketChannel.connect(timeBasedUrl, headers: {
          'Connection': 'Upgrade',
          'Upgrade': 'websocket',
          'Sec-WebSocket-Version': '13',
        });
        await _timeBasedChannel.ready;
      } catch (e) {
        rethrow;
      }

      // Try event-based connection (secondary, non-critical)
      try {
        _eventBasedChannel = IOWebSocketChannel.connect(eventBasedUrl);
        await _timeBasedChannel.ready.timeout(Duration(seconds: 5));
      } catch (e) {
        // Don't fail if event-based fails - time-based is sufficient
      }

      _isConnected = true;
      _reconnectAttempts = 0;
      _lastMessageTime = DateTime.now();
      _connectionStatus.add(true);
      print('[WebSocket] ✅ Connected successfully');

      _startKeepAlive();
      _startStalenessCheck();
      _listenToTimeBasedReports();
      _listenToEventBasedReports();
    } catch (e) {
      print('[WebSocket] ❌ Connection failed: $e');
      _handleConnectionError();
    }
  }

  void _listenToTimeBasedReports() {
    print('[WebSocket] 📊 Listening for time-based reports...');
    _timeBasedChannel.stream.listen(
      (dynamic message) {
        try {
          Report report;
          
          // Try JSON first (most common format from data generator)
          if (message is String) {
            try {
              final json = jsonDecode(message) as Map<String, dynamic>;
              report = Report.fromJson(json);
            } catch (e) {
              rethrow;
            }
          } else if (message is List<int>) {
            try {
              // Try protobuf first
              final timeBasedReport = TimeBasedReport.fromBuffer(message);
              report = Report.fromTimeBasedReport(timeBasedReport);
            } catch (e) {
              // If binary fails, try decoding as UTF-8 string then JSON
              try {
                final jsonString = utf8.decode(message);
                final json = jsonDecode(jsonString) as Map<String, dynamic>;
                report = Report.fromJson(json);
              } catch (e2) {
                rethrow;
              }
            }
          } else {
            return;
          }
          
          // Cache the report for event-based report conversion
          _lastReportsByDevice[report.deviceId] = report;
          
          // Update last message time for staleness detection
          _lastMessageTime = DateTime.now();
          
          if (!_reportStream.isClosed) {
            _reportStream.add(report);
          }
          
        } catch (e) {
          // Silently skip malformed messages
        }
      },
      onError: (error) {
        print('[WebSocket] ❌ Stream error: $error');
        _handleConnectionError();
      },
      onDone: () {
        print('[WebSocket] 🔌 Time-based stream closed');
        _handleConnectionError();
      },
    );
  }

  void _listenToEventBasedReports() {
    _eventBasedChannel.stream.listen(
      (dynamic message) {
        try {
          if (message is String) {
            // JSON fallback for backward compatibility
            if (!_eventStream.isClosed) {
              _eventStream.add(message);
            }
          } else if (message is List<int>) {
            // Protobuf EventBasedReport
            final eventReport = EventBasedReport.fromBuffer(message);
            
            // Get last report for this device or create default
            final lastReport = _lastReportsByDevice[eventReport.deviceId] ??
                Report(
                  deviceId: eventReport.deviceId,
                  heartbeat: 0,
                  breath: 0,
                  systolicBp: 120,
                  diastolicBp: 80,
                  bloodOxygen: 98,
                  temperature: 37.0,
                  distanceCovered: 0,
                  timestamp: DateTime.now(),
                );
            
            // Convert event to report and cache it
            final report = Report.fromEventBasedReport(eventReport, lastReport);
            _lastReportsByDevice[report.deviceId] = report;
            
            // Emit as event stream for special handling
            String eventType = '';
            switch (eventReport.eventId) {
              case 1:
                eventType = 'Blood Pressure: ${eventReport.eventData.join('/')}';
                break;
              case 2:
                eventType = 'Blood Oxygen: ${eventReport.eventData.firstOrNull}%';
                break;
              case 3:
                eventType = 'Temperature: ${(eventReport.eventData.firstOrNull ?? 0) / 10.0}°C';
                break;
            }
            
            if (!_eventStream.isClosed) {
              _eventStream.add(eventType);
            }
            print('[WebSocket] Event-based report: Device ${eventReport.deviceId}, '
                  'Event: $eventType');
          }
        } catch (e) {
          print('[WebSocket] Error parsing event-based report: $e');
        }
      },
      onError: (error) {
        print('[WebSocket] Event stream error: $error');
        _handleConnectionError();
      },
      onDone: () {
        print('[WebSocket] Event stream closed');
        _handleConnectionError();
      },
    );
  }

  void _handleConnectionError() {
    _isConnected = false;
    
    // Only add to connection status if the stream is still open
    if (!_connectionStatus.isClosed) {
      _connectionStatus.add(false);
    }

    // Attempt to reconnect with adaptive backoff
    _reconnectAttempts++;
    
    // Adaptive backoff: 
    // - First 5 attempts: 3s, 6s, 9s, 12s, 15s (exponential)
    // - After 5: stay at 5s for faster recovery when service restarts
    late int backoffSeconds;
    if (_reconnectAttempts <= 5) {
      backoffSeconds = 3 * _reconnectAttempts;
    } else {
      // After trying hard, retry every 5s so we catch service recovery faster
      backoffSeconds = 5;
    }
    
    final nextDelay = Duration(seconds: backoffSeconds);
    
    print('[WebSocket] ⚠️ Connection error - will retry in ${backoffSeconds}s (attempt $_reconnectAttempts)');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(nextDelay, () {
      if (!_reportStream.isClosed) {
        connect();
      }
    });
  }

  /// Start WebSocket keep-alive heartbeat to prevent idle timeouts
  /// Sends periodic ping frames to keep connection alive
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(keepAliveInterval, (_) {
      try {
        if (_isConnected && _timeBasedChannel.closeCode == null) {
          _timeBasedChannel.sink.add('ping');
          
          if (_eventBasedChannel.closeCode == null) {
            _eventBasedChannel.sink.add('ping');
          }
        }
      } catch (e) {
        // Keep-alive error, will be handled by staleness check
      }
    });
  }

  /// Start staleness detection to identify broken connections early
  /// If no message received for 10s, force reconnect
  void _startStalenessCheck() {
    _stalenessCheckTimer?.cancel();
    _stalenessCheckTimer = Timer.periodic(Duration(seconds: 5), (_) {
      if (!_isConnected) return;
      
      final timeSinceLastMessage = DateTime.now().difference(_lastMessageTime);
      
      if (timeSinceLastMessage > stalenessThreshold) {
        print('[WebSocket] ⏱️ Connection stale (no data for ${timeSinceLastMessage.inSeconds}s), '
              'forcing reconnect');
        _handleConnectionError();
      } else if (timeSinceLastMessage.inSeconds > 5) {
        print('[WebSocket] 📈 Receiving data (${timeSinceLastMessage.inSeconds}s since last message)');
      }
    });
  }

  /// Stop keep-alive and staleness monitors
  void _stopKeepaliveMonitors() {
    _keepAliveTimer?.cancel();
    _stalenessCheckTimer?.cancel();
  }

  Future<void> disconnect() async {
    _stopKeepaliveMonitors();  // Stop monitoring threads
    _reconnectTimer?.cancel();
    _isConnected = false;
    _connectionStatus.add(false);

    try {
      await _timeBasedChannel.sink.close();
      await _eventBasedChannel.sink.close();
    } catch (e) {
      // Disconnect error, connection may already be closed
    }
  }

  void dispose() {
    _stopKeepaliveMonitors();  // Stop monitoring
    _reconnectTimer?.cancel();
    // Don't close stream controllers - they may be reused on reconnect
    // Only close web socket channels
    try {
      _timeBasedChannel.sink.close();
      _eventBasedChannel.sink.close();
    } catch (_) {}
  }
}
