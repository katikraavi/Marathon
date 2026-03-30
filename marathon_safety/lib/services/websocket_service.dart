import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/report.dart';
import '../utils/constants.dart';

class WebSocketService {
  late WebSocketChannel _timeBasedChannel;
  late WebSocketChannel _eventBasedChannel;
  
  final StreamController<Report> _reportStream = StreamController.broadcast();
  final StreamController<String> _eventStream = StreamController.broadcast();
  final StreamController<bool> _connectionStatus = StreamController.broadcast();

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
          if (message is String) {
            final json = jsonDecode(message) as Map<String, dynamic>;
            final report = Report.fromJson(json);
            _reportStream.add(report);
          }
        } catch (e) {
          print('[WebSocket] Error parsing report: $e');
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
            _eventStream.add(message);
          }
        } catch (e) {
          print('[WebSocket] Error parsing event: $e');
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
