import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';

/// Local implementation of UserRepository using SharedPreferences
class LocalUserRepository implements UserRepository {
  static const String _userKeyPrefix = 'user_';

  @override
  Future<void> registerUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = jsonEncode(user.toJson());
      await prefs.setString(_userKeyPrefix + user.phone, userJson);
    } catch (e) {
      throw Exception('Failed to register user: $e');
    }
  }

  @override
  Future<User?> loginUser(String phone, String password) async {
    try {
      final user = await getUserByPhone(phone);
      if (user != null && user.password == password) {
        return user;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to login user: $e');
    }
  }

  @override
  Future<User?> getUserByPhone(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString(_userKeyPrefix + phone);
      if (userString != null) {
        return User.fromJson(jsonDecode(userString));
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  @override
  Future<bool> isPhoneExists(String phone) async {
    try {
      final user = await getUserByPhone(phone);
      return user != null;
    } catch (e) {
      throw Exception('Failed to check phone: $e');
    }
  }

  @override
  Future<bool> isEmailExists(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (var key in keys) {
        if (key.startsWith(_userKeyPrefix)) {
          final userString = prefs.getString(key);
          if (userString != null) {
            final user = User.fromJson(jsonDecode(userString));
            if (user.email.toLowerCase() == email.toLowerCase()) {
              return true;
            }
          }
        }
      }
      return false;
    } catch (e) {
      throw Exception('Failed to check email: $e');
    }
  }
}
