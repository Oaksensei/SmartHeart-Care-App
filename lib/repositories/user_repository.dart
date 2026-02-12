import '../models/user_model.dart';

/// Abstract repository for user data operations
abstract class UserRepository {
  /// Register a new user
  Future<void> registerUser(User user);

  /// Login user by phone number and password. Returns User if found and password matches, null otherwise.
  Future<User?> loginUser(String phone, String password);

  /// Get user by phone number
  Future<User?> getUserByPhone(String phone);

  /// Check if phone number already exists
  Future<bool> isPhoneExists(String phone);

  /// Check if email already exists
  Future<bool> isEmailExists(String email);
}
