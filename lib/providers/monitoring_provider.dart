import 'package:flutter/foundation.dart';

/// State management for monitoring configuration
class MonitoringProvider extends ChangeNotifier {
  int _selectedSampleRate = 125;
  bool _isMonitoring = false;

  int get selectedSampleRate => _selectedSampleRate;
  bool get isMonitoring => _isMonitoring;

  void setSampleRate(int rate) {
    _selectedSampleRate = rate;
    notifyListeners();
  }

  void setMonitoring(bool monitoring) {
    _isMonitoring = monitoring;
    notifyListeners();
  }
}
