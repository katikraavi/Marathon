import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'presentation/screens/home_screen.dart';
import 'data/repositories/runner_repository.dart';
import 'data/sources/websocket_source.dart';

// Global services that start loading data immediately
late RunnerRepository _globalRepository;
late WebSocketService _globalWebSocketService;
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notifications service
  await NotificationService().initialize();
  
  // Initialize global services and start loading data BEFORE showing UI
  _globalRepository = RunnerRepository();
  _globalWebSocketService = WebSocketService();
  
  // Start connecting to WebSocket immediately (data loads while user is on login screen)
  // Wrap in try-catch to prevent app crash if WebSocket fails
  try {
    _globalWebSocketService.connect();
    
    // Listen to reports and add them to repository
    _globalWebSocketService.reportStream.listen(
      (report) {
        _globalRepository.addReport(report);
      },
      onError: (error) {
        // WebSocket stream error, connection will attempt auto-reconnect
      },
    );
  } catch (e) {
    // WebSocket connection failed, app will continue with empty data
  }
  
  runApp(const MarathonSafetyApp());
}

class MarathonSafetyApp extends StatelessWidget {
  const MarathonSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Provide global services to entire app
        ChangeNotifierProvider<RunnerRepository>.value(value: _globalRepository),
        Provider<WebSocketService>.value(value: _globalWebSocketService),
      ],
      child: MaterialApp(
        title: 'Marathon Safety',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: const HomeScreen(),
        routes: {
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
