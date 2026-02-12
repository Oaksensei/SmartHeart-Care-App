import '../models/session_model.dart';

/// Abstract repository for session data operations
abstract class SessionRepository {
  /// Save a session
  Future<void> saveSession(SessionModel session);

  /// Update an existing session
  Future<void> updateSession(SessionModel session);

  /// Get all sessions for a user, sorted by date (newest first)
  Future<List<SessionModel>> getSessions(String userId);

  /// Get a specific session by ID
  Future<SessionModel?> getSessionById(String userId, String sessionId);
}
