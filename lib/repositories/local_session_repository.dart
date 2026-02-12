import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/session_model.dart';
import '../repositories/session_repository.dart';

/// Local implementation of SessionRepository using File System
class LocalSessionRepository implements SessionRepository {
  Future<Directory> _getUserSessionDir(String userId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final sessionDir = Directory('${appDir.path}/sessions/$userId');
    if (!await sessionDir.exists()) {
      await sessionDir.create(recursive: true);
    }
    return sessionDir;
  }

  @override
  Future<void> saveSession(SessionModel session) async {
    debugPrint(
      "LocalSessionRepository: Saving session ${session.sessionId} for user ${session.userId}",
    );
    try {
      final dir = await _getUserSessionDir(session.userId);
      final file = File('${dir.path}/${session.sessionId}.json');
      final jsonStr = jsonEncode(session.toJson());
      await file.writeAsString(jsonStr);
      debugPrint("LocalSessionRepository: File written to ${file.path}");
    } catch (e) {
      debugPrint("LocalSessionRepository: Error saving session file - $e");
      throw Exception('Failed to save session: $e');
    }
  }

  @override
  Future<void> updateSession(SessionModel session) async {
    // Same as saveSession - overwrites the file
    try {
      await saveSession(session);
    } catch (e) {
      throw Exception('Failed to update session: $e');
    }
  }

  @override
  Future<List<SessionModel>> getSessions(String userId) async {
    try {
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
            debugPrint('Error reading session file: ${entity.path}, $e');
          }
        }
      }

      // Sort: Newest first
      sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return sessions;
    } catch (e) {
      throw Exception('Failed to get sessions: $e');
    }
  }

  @override
  Future<SessionModel?> getSessionById(String userId, String sessionId) async {
    try {
      final dir = await _getUserSessionDir(userId);
      final file = File('${dir.path}/$sessionId.json');

      if (await file.exists()) {
        final content = await file.readAsString();
        return SessionModel.fromJson(jsonDecode(content));
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get session by id: $e');
    }
  }
}
