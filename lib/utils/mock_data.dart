import '../models/user_model.dart';

class AppMockState {
  // Device
  static String? connectedDevice;
  static bool isMonitoring = false;
  static int selectedSampleRate = 125; // Default sample rate

  // Session
  static Map<String, dynamic>? currentSession;
  static List<Map<String, dynamic>> sessions = [];

  // User Profile
  static User? activeUser;
  // Fallbacks for display if needed are now activeUser.name / activeUser.age

  // Optional helpers
  static bool get isConnected => connectedDevice != null;

  static void reset() {
    connectedDevice = null;
    isMonitoring = false;
    currentSession = null;
    sessions.clear();
    activeUser = null;
  }
}
