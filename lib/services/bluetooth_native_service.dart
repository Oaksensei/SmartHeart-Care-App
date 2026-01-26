import 'package:flutter/services.dart';

class BluetoothNativeService {
  static final BluetoothNativeService _instance =
      BluetoothNativeService._internal();
  factory BluetoothNativeService() => _instance;
  BluetoothNativeService._internal();

  static const platform = MethodChannel('ecg_channel');

  /// Connects to a Movesense device by MAC address
  Future<void> connect(String macAddress) async {
    try {
      await platform.invokeMethod('connect', {'address': macAddress});
    } on PlatformException catch (e) {
      throw 'Failed to connect: ${e.message}';
    }
  }

  /// Disconnects from the device
  Future<void> disconnect(String macAddress) async {
    try {
      await platform.invokeMethod('disconnect', {'address': macAddress});
    } on PlatformException catch (e) {
      print("Warning: Failed to disconnect cleanly: ${e.message}");
    }
  }

  /// Start ECG stream at specific sample rate
  Future<void> startECG({int sampleRate = 125}) async {
    try {
      await platform.invokeMethod('startECG', {'sampleRate': sampleRate});
    } on PlatformException catch (e) {
      throw 'Failed to start ECG: ${e.message}';
    }
  }

  /// Stop ECG stream
  Future<void> stopECG() async {
    try {
      await platform.invokeMethod('stopECG');
    } on PlatformException catch (e) {
      print("Warning: Failed to stop ECG: ${e.message}");
    }
  }
}
