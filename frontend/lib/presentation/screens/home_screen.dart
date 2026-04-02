import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/providers/auth_provider.dart';
import 'login_screen.dart';
import 'race_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isLoggedIn) {
          return const LoginScreen();
        }

        return const RaceListScreen();
      },
    );
  }
}
