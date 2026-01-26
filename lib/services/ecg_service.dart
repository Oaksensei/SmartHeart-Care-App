import 'dart:async';
import 'package:flutter/services.dart';

class ECGService {
  // Singleton pattern
  static final ECGService _instance = ECGService._internal();
  factory ECGService() => _instance;
  ECGService._internal();

  static const platform = MethodChannel('ecg_channel');

  // Stream controller to broadcast ECG data to UI
  final _ecgStreamController = StreamController<int>.broadcast();
  Stream<int> get ecgStream => _ecgStreamController.stream;

  // Stream controller for Heart Rate
  final _hrStreamController = StreamController<int>.broadcast();
  Stream<int> get hrStream => _hrStreamController.stream;

  bool _isListening = false;

  /// Setup the MethodCallHandler to receive data from Native
  void init() {
    if (_isListening) return;

    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case "ecgSample":
          if (call.arguments is int) {
            _ecgStreamController.add(call.arguments as int);
          }
          break;
        case "hrSample":
          if (call.arguments is int) {
            _hrStreamController.add(call.arguments as int);
          }
          break;
      }
    });

    _isListening = true;
  }

  /// Call Native method to start ECG
  Future<void> startMonitoring() async {
    // Ensure we are listening before starting
    init();
    try {
      await platform.invokeMethod('startECG');
    } on PlatformException catch (e) {
      print("Failed to start ECG: '${e.message}'.");
    }
  }

  /// Dispose stream (optional, mostly for app termination)
  void dispose() {
    _ecgStreamController.close();
    _hrStreamController.close();
  }
}
