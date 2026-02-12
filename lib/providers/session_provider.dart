import 'package:flutter/foundation.dart';
import '../models/session_model.dart';
import '../repositories/session_repository.dart';

/// State management for sessions
class SessionProvider extends ChangeNotifier {
  final SessionRepository _sessionRepository;
  List<SessionModel> _sessions = [];
  bool _isLoading = false;
  String? _error;

  SessionProvider(this._sessionRepository);

  List<SessionModel> get sessions => _sessions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load sessions for a user
  Future<void> loadSessions(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sessions = await _sessionRepository.getSessions(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save a new session
  Future<bool> saveSession(SessionModel session) async {
    try {
      await _sessionRepository.saveSession(session);
      // Add to local list
      _sessions.insert(0, session);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update an existing session
  Future<bool> updateSession(SessionModel session) async {
    try {
      await _sessionRepository.updateSession(session);
      // Update in local list
      final index = _sessions.indexWhere(
        (s) => s.sessionId == session.sessionId,
      );
      if (index != -1) {
        _sessions[index] = session;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get session by ID
  Future<SessionModel?> getSessionById(String userId, String sessionId) async {
    try {
      return await _sessionRepository.getSessionById(userId, sessionId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
