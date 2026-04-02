import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notifications service
  await NotificationService().initialize();
  
  runApp(const MarathonSafetyApp());
}

class MarathonSafetyApp extends StatelessWidget {
  const MarathonSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Marathon Safety',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        routes: {
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
