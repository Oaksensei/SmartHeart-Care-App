import 'package:flutter/foundation.dart';

/// State management for Bluetooth connection
class BluetoothProvider extends ChangeNotifier {
  String? _connectedDevice;
  int _selectedSampleRate = 125; // Default sample rate

  String? get connectedDevice => _connectedDevice;
  int get selectedSampleRate => _selectedSampleRate;
  bool get isConnected => _connectedDevice != null;

  /// Connect to a device
  void connect(String deviceName) {
    _connectedDevice = deviceName;
    notifyListeners();
  }

  /// Disconnect from current device
  void disconnect() {
    _connectedDevice = null;
    notifyListeners();
  }

  /// Update the sampling rate
  void setSampleRate(int rate) {
    _selectedSampleRate = rate;
    notifyListeners();
  }
}
