import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';
import '../models/user_model.dart';

class StorageService {
  static const String _userKeyPrefix = 'user_';

  // --- User Management (Shared Preferences) ---

  /// Register a new user. Returns true if successful.
  static Future<void> registerUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = jsonEncode(user.toJson());
    // Store user by phone (simple key)
    await prefs.setString(_userKeyPrefix + user.phone, userJson);
  }

  /// Login user by phone number and password. Returns User if found and password matches.
  static Future<User?> loginUser(String phone, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(_userKeyPrefix + phone);
    if (userString != null) {
      final user = User.fromJson(jsonDecode(userString));
      // Verify password
      if (user.password == password) {
        return user;
      }
    }
    return null;
  }

  // --- Session Management (File System) ---

  static Future<Directory> _getUserSessionDir(String userId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final sessionDir = Directory('${appDir.path}/sessions/$userId');
    if (!await sessionDir.exists()) {
      await sessionDir.create(recursive: true);
    }
    return sessionDir;
  }

  /// Save a session to a JSON file
  static Future<void> saveSession(SessionModel session) async {
    debugPrint(
      "StorageService: Saving session ${session.sessionId} for user ${session.userId}",
    );
    try {
      final dir = await _getUserSessionDir(session.userId);
      final file = File('${dir.path}/${session.sessionId}.json');
      final jsonStr = jsonEncode(session.toJson());
      await file.writeAsString(jsonStr);
      debugPrint("StorageService: File written to ${file.path}");
    } catch (e) {
      debugPrint("StorageService: Error saving session file - $e");
      rethrow;
    }
  }

  /// Update an existing session
  static Future<void> updateSession(SessionModel session) async {
    // Same as saveSession - overwrites the file
    await saveSession(session);
  }

  /// Get all sessions for a user, sorted by date (newest first)
  static Future<List<SessionModel>> getSessions(String userId) async {
    final dir = await _getUserSessionDir(userId);
    final List<SessionModel> sessions = [];

    final entities = dir.listSync();
    for (var entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final session = SessionModel.fromJson(jsonDecode(content));
          sessions.add(session);
        } catch (e) {
          print('Error reading session file: ${entity.path}, $e');
        }
      }
    }

    // Sort: Newest first
    sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sessions;
  }
}
