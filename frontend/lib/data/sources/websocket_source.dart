import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../generated/reports.pb.dart';
import '../models/report.dart';
import '../../config/constants.dart';

class WebSocketService {
  late WebSocketChannel _timeBasedChannel;
  late WebSocketChannel _eventBasedChannel;
  
  final StreamController<Report> _reportStream = StreamController.broadcast();
  final StreamController<String> _eventStream = StreamController.broadcast();
  final StreamController<bool> _connectionStatus = StreamController.broadcast();

  /// Cache of last report per device for event-based report conversion
  final Map<int, Report> _lastReportsByDevice = {};

  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);

  Stream<Report> get reportStream => _reportStream.stream;
  Stream<String> get eventStream => _eventStream.stream;
  Stream<bool> get connectionStatus => _connectionStatus.stream;
  bool get isConnected => _isConnected;

  String get _baseUrl {
    if (Platform.isAndroid) {
      return AppConstants.wsBaseUrlAndroid;
    } else if (Platform.isIOS) {
      return AppConstants.wsBaseUrlIOS;
    }
    // Default to localhost for other platforms (Windows, macOS, Linux)
    return 'ws://localhost:8080';
  }

  Future<void> connect() async {
    try {
      print('[WebSocket] Attempting to connect to $_baseUrl');
      
      final timeBasedUrl = Uri.parse(
        '$_baseUrl${AppConstants.timeBasedReportsEndpoint}',
      );
      final eventBasedUrl = Uri.parse(
        '$_baseUrl${AppConstants.eventBasedReportsEndpoint}',
      );

      _timeBasedChannel = WebSocketChannel.connect(timeBasedUrl);
      _eventBasedChannel = WebSocketChannel.connect(eventBasedUrl);

      // Wait for connection to establish
      await Future.wait([
        _timeBasedChannel.ready,
        _eventBasedChannel.ready,
      ]);

      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStatus.add(true);
      print('[WebSocket] Connected successfully');

      // Listen to both streams
      _listenToTimeBasedReports();
      _listenToEventBasedReports();
    } catch (e) {
      print('[WebSocket] Connection failed: $e');
      _handleConnectionError();
    }
  }

  void _listenToTimeBasedReports() {
    _timeBasedChannel.stream.listen(
      (dynamic message) {
        try {
          Report report;
          
          if (message is String) {
            // JSON fallback for backward compatibility
            final json = jsonDecode(message) as Map<String, dynamic>;
            report = Report.fromJson(json);
          } else if (message is List<int>) {
            // Protobuf message
            final timeBasedReport = TimeBasedReport.fromBuffer(message);
            report = Report.fromTimeBasedReport(timeBasedReport);
          } else {
            print('[WebSocket] Unknown message type: ${message.runtimeType}');
            return;
          }
          
          // Cache the report for event-based report conversion
          _lastReportsByDevice[report.deviceId] = report;
          
          _reportStream.add(report);
          print('[WebSocket] Time-based report: Device ${report.deviceId}, '
                'HR: ${report.heartbeat}, BR: ${report.breath}, Distance: ${report.distanceCovered}m');
        } catch (e) {
          print('[WebSocket] Error parsing time-based report: $e');
        }
      },
      onError: (error) {
        print('[WebSocket] Time-based stream error: $error');
        _handleConnectionError();
      },
      onDone: () {
        print('[WebSocket] Time-based stream closed');
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
            _eventStream.add(message);
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
            
            _eventStream.add(eventType);
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
    _connectionStatus.add(false);

    // Attempt to reconnect
    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      print('[WebSocket] Reconnecting in ${reconnectDelay.inSeconds}s '
            '(attempt $_reconnectAttempts/$maxReconnectAttempts)');
      
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(reconnectDelay, () {
        connect();
      });
    } else {
      print('[WebSocket] Max reconnection attempts reached');
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _isConnected = false;
    _connectionStatus.add(false);

    try {
      await _timeBasedChannel.sink.close();
      await _eventBasedChannel.sink.close();
      print('[WebSocket] Disconnected');
    } catch (e) {
      print('[WebSocket] Error during disconnect: $e');
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _reportStream.close();
    _eventStream.close();
    _connectionStatus.close();
    try {
      _timeBasedChannel.sink.close();
      _eventBasedChannel.sink.close();
    } catch (_) {}
  }
}
