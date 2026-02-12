import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';

/// State management for authentication
class AuthProvider extends ChangeNotifier {
  final UserRepository _userRepository;
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._userRepository);

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  /// Register a new user
  Future<bool> register(User user) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate phone format (10 digits)
      if (!_isValidPhone(user.phone)) {
        _error = 'Invalid phone number format. Must be 10 digits.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Validate email format
      if (!_isValidEmail(user.email)) {
        _error = 'Invalid email format.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check if phone already exists
      final phoneExists = await _userRepository.isPhoneExists(user.phone);
      if (phoneExists) {
        _error = 'This phone number is already registered.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check if email already exists
      final emailExists = await _userRepository.isEmailExists(user.email);
      if (emailExists) {
        _error = 'This email is already registered.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _userRepository.registerUser(user);
      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Validate phone number (10 digits, Thai format)
  bool _isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^0[0-9]{9}$');
    return phoneRegex.hasMatch(phone);
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Login user by phone and password
  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _userRepository.loginUser(phone, password);
      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Invalid phone number or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout current user
  void logout() {
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
