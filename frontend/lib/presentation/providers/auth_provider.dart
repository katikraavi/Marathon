import 'package:flutter/material.dart';
import '../../config/constants.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _username;
  String? _errorMessage;

  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String username, String password) async {
    _errorMessage = null;
    
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Validate against fixed credentials (test req #4)
    if (username == AppConstants.defaultUsername &&
        password == AppConstants.defaultPassword) {
      _isLoggedIn = true;
      _username = username;
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Invalid username or password';
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _isLoggedIn = false;
    _username = null;
    _errorMessage = null;
    notifyListeners();
  }
}
