import 'package:flutter/material.dart';

// import screens
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/bluetooth_screen.dart';
import '../screens/monitoring_screen.dart';
import '../screens/history_screen.dart';
import '../screens/session_detail_screen.dart';
import '../screens/register_screen.dart';
import '../screens/settings_screen.dart';

class AppRoutes {
  // Route names (ใช้เรียกแบบมาตรฐาน)
  static const String login = '/login';
  static const String home = '/home';
  static const String bluetooth = '/bluetooth';
  static const String monitoring = '/monitoring';
  static const String recording = '/recording';
  static const String history = '/history';
  static const String sessionDetail = '/session-detail';
  static const register = '/register';
  static const settings = '/settings';

  // Route map
  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginScreen(),
    home: (context) => const HomeScreen(),
    bluetooth: (context) => const BluetoothScreen(),
    monitoring: (context) => const MonitoringScreen(),
    history: (context) => const HistoryScreen(),
    sessionDetail: (context) => const SessionDetailScreen(),
    register: (context) => const RegisterScreen(),
    settings: (context) => const SettingsScreen(),
  };
}
