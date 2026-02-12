import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../main.dart'; // Import to access global ecgQualityModel
import '../models/session_model.dart';
import '../providers/auth_provider.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/session_provider.dart';
import '../providers/monitoring_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/ecg_waveform_animated.dart';
import '../services/ecg_service.dart';
import '../services/bluetooth_native_service.dart';
import '../utils/signal_processing.dart';

// [NEW] Enum for UI State
enum SignalQuality { good, bad, unknown }

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  bool isMonitoring = false;
  int heartRate = 0; // Default 0 for real data
  StreamSubscription<int>? _hrSubscription;
  Timer? _recordingTimer; // Only for session duration

  final _ecgService = ECGService(); // For Data Stream
  final _nativeService = BluetoothNativeService(); // For Control commands

  // Sample Rate
  // int _selectedSampleRate = 125; // Moved to AppMockState
  final List<int> _sampleRates = [125, 250, 500];

  // Recording State
  bool isRecordingSession = false;
  // Timer? _recordingTimer; // This was duplicated, keeping the one above
  int _recordingSeconds = 0;
  List<int> _recordedECGData = []; // Buffer for playback data
  List<int> _recordedHRData = []; // [NEW] HR History
  StreamSubscription<int>? _ecgSubscription;
  // StreamSubscription<int>? _hrSubscription; // Removed duplicate

  SignalQuality _signalQuality = SignalQuality.unknown; // [NEW] State

  // [NEW] Session Logic
  final List<int> _tenSecBuffer = [];
  final List<bool> _sessionWindowResults = []; // true = Good, false = Bad
  int _consecutiveBadWindows = 0;
  bool _hasWarnedUnstable = false;
  Timer? _btCheckTimer; // [NEW] Periodically check BT connection
  StreamSubscription<BluetoothAdapterState>?
  _adapterStateSubscription; // [NEW] BT adapter listener

  void _startRecordingSession() {
    debugPrint("STARTING RECORDING SESSION...");
    setState(() {
      isRecordingSession = true;
      _recordingSeconds = 0;
      _recordedECGData.clear();
      // Reset Session Logic
      _sessionWindowResults.clear();
      _tenSecBuffer.clear();
      _consecutiveBadWindows = 0;
      _hasWarnedUnstable = false;
    });
    debugPrint("Session Started. isRecordingSession: $isRecordingSession");

    // [REMOVE] BT check timer already started in _startMonitoring()

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingSeconds++;
        });
        if (_recordingSeconds >= 300) {
          debugPrint("Max duration (5 mins) reached. Stopping session.");
          _stopRecordingSession();
        }

        if (_recordingSeconds % 5 == 0) {
          debugPrint(
            "Recording Timer: $_recordingSeconds s. Data Count: ${_recordedECGData.length}",
          );
        }
      }
    });
  }

  void _stopRecordingSession() async {
    debugPrint("STOPPING RECORDING SESSION...");
    _recordingTimer?.cancel();
    _stopBluetoothCheckTimer(); // [NEW] Stop BT check

    // Capture state BEFORE resetting (though _recordedECGData should persist)
    int capturedDuration = _recordingSeconds;
    int capturedDataCount = _recordedECGData.length;
    debugPrint(
      "Stop Record Triggered. Duration: $capturedDuration, Data: $capturedDataCount",
    );

    setState(() {
      isRecordingSession = false;
    });

    // Calculate Session Quality
    // Calculate Session Quality
    // Rule: >= 95% GOOD windows = GOOD session
    // If no windows recorded (very short session), assume GOOD (benefit of doubt) or handle edge case.
    String finalQuality = 'Good';
    if (_sessionWindowResults.isNotEmpty) {
      int goodCount = _sessionWindowResults.where((r) => r).length;
      double goodRatio = goodCount / _sessionWindowResults.length;
      if (goodRatio < 0.95) {
        finalQuality = 'Bad';
      }
      debugPrint(
        "Session Finished. Total Windows: ${_sessionWindowResults.length}, Good: $goodCount, Ratio: $goodRatio, Result: $finalQuality",
      );
    }

    // [NEW] Calculate HRV Metrics
    Map<String, double> hrvMetrics = {
      'hr_avg': 0.0,
      'rr_mean': 0.0,
      'rr_std': 0.0,
      'rmssd': 0.0,
      'cv_rr': 0.0,
    };

    // [FIX] Calculate Duration from samples if Timer failed or was too short
    int finalDuration = _recordingSeconds;
    if (finalDuration == 0 && _recordedECGData.isNotEmpty) {
      final sampleRate = Provider.of<MonitoringProvider>(
        context,
        listen: false,
      ).selectedSampleRate;
      finalDuration = (_recordedECGData.length / sampleRate).round();
      if (finalDuration == 0)
        finalDuration = 1; // Minimum 1s if valid data exists
    }
    debugPrint(
      "Session Stopping. Timer States: $_recordingSeconds s. Calculated: $finalDuration s. Samples: ${_recordedECGData.length}",
    );

    try {
      if (_recordedECGData.isNotEmpty) {
        final sampleRate = Provider.of<MonitoringProvider>(
          context,
          listen: false,
        ).selectedSampleRate;
        debugPrint(
          "Calculating HRV for ${_recordedECGData.length} samples at ${sampleRate}Hz",
        );
        hrvMetrics = SignalProcessing.calculateHRV(
          _recordedECGData,
          sampleRate,
        );
        debugPrint("HRV Result: $hrvMetrics");
      } else {
        debugPrint("HRV Skipped: No ECG data recorded.");
      }
    } catch (e) {
      debugPrint("Error calculating HRV: $e");
    }

    // Save Session Locally
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sessionProvider = Provider.of<SessionProvider>(
      context,
      listen: false,
    );
    final monitoringProvider = Provider.of<MonitoringProvider>(
      context,
      listen: false,
    );

    if (authProvider.currentUser != null) {
      try {
        // Calculate true average HR
        int avgHr = 0;
        if (_recordedHRData.isNotEmpty) {
          avgHr =
              (_recordedHRData.reduce((a, b) => a + b) / _recordedHRData.length)
                  .round();
        } else {
          avgHr = heartRate; // Fallback
        }

        final session = SessionModel(
          sessionId: const Uuid().v4(),
          userId: authProvider.currentUser!.id,
          timestamp: DateTime.now().toIso8601String(),
          durationSeconds: finalDuration,
          averageHeartRate: avgHr, // [FIX] Use calculated average
          samplingRate: monitoringProvider.selectedSampleRate,
          ecgSamples: List<int>.from(_recordedECGData),
          signalQuality: finalQuality,
          windowResults: List<bool>.from(_sessionWindowResults),
          hrHistory: List<int>.from(_recordedHRData), // [NEW] Pass HR history
          // [NEW] HRV Fields
          hrvHrAvg: hrvMetrics['hr_avg'],
          hrvMeanRr: hrvMetrics['rr_mean'],
          hrvSdnn: hrvMetrics['rr_std'],
          hrvRmssd: hrvMetrics['rmssd'],
          hrvCvRr: hrvMetrics['cv_rr'],
        );

        await sessionProvider.saveSession(session);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session saved to History'),
              backgroundColor: Colors.green,
            ),
          );

          // Auto navigate to History Screen to view result
          Navigator.pushReplacementNamed(context, AppRoutes.history);
        }
      } catch (e) {
        debugPrint("Error saving session: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save session: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      debugPrint("Cannot save session: No active user logged in.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Session NOT saved: Please Login first!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainSeconds.toString().padLeft(2, '0')}';
  }

  void _startMonitoring() async {
    final bluetoothProvider = Provider.of<BluetoothProvider>(
      context,
      listen: false,
    );
    final monitoringProvider = Provider.of<MonitoringProvider>(
      context,
      listen: false,
    );

    if (bluetoothProvider.connectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect a device before monitoring'),
        ),
      );
      return;
    }

    try {
      // [NEW] Start BT check timer immediately when monitoring starts
      _startBluetoothCheckTimer();

      // [NEW] Call Native Control
      await _nativeService.startECG(
        sampleRate: monitoringProvider.selectedSampleRate,
      );

      // Ensure listener is active
      _ecgService.init();

      // Subscribe to Real ECG Data for Recording
      _ecgSubscription?.cancel();
      _ecgSubscription = _ecgService.ecgStream.listen(
        (sample) {
          try {
            // --- Unified Logic: 10s Window for UI & Recording ---

            // 1. Always fill the 10s Analysis Buffer
            _tenSecBuffer.add(sample);

            // 2. If Recording, also fill the raw data list
            if (isRecordingSession) {
              _recordedECGData.add(sample);
            }

            // 3. Check Full 10s Window
            final sampleRate = Provider.of<MonitoringProvider>(
              context,
              listen: false,
            ).selectedSampleRate;
            int tenSecSize = sampleRate * 10;

            if (_tenSecBuffer.length >= tenSecSize) {
              // Analyze this 10s chunk
              debugPrint("Monitoring: 10s Window Full. Analyzing Quality...");

              // Sanity Check
              final isValid = ecgQualityModel.isSignalPhysicallyValid(
                _tenSecBuffer,
              );

              bool isGood = false;
              if (!isValid) {
                isGood = false;
              } else {
                isGood = ecgQualityModel.isGood(_tenSecBuffer);
              }

              // A. Update UI (Always)
              if (mounted) {
                setState(() {
                  _signalQuality = isGood
                      ? SignalQuality.good
                      : SignalQuality.bad;
                });
              }

              // B. If Recording, Save Result
              if (isRecordingSession) {
                _sessionWindowResults.add(isGood);
                debugPrint(
                  "Session: Saved Window Result = ${isGood ? 'Good' : 'Bad'}",
                );

                // Consecutive Bad Check
                if (!isGood) {
                  _consecutiveBadWindows++;
                } else {
                  _consecutiveBadWindows = 0;
                }

                if (_consecutiveBadWindows >= 3 && !_hasWarnedUnstable) {
                  _hasWarnedUnstable = true;
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Signal quality is unstable. Please check electrode placement.",
                        ),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                }
              }

              // Clear buffer for NEXT 10s
              _tenSecBuffer.clear();
            }
          } catch (e) {
            debugPrint("Error in ECG stream processing: $e");
            _tenSecBuffer.clear();
          }
        },
        onError: (error) {
          // [NEW] Handle stream errors (e.g., Bluetooth disconnected)
          debugPrint("[ERROR] ECG Stream Error: $error");
          if (isRecordingSession) {
            _cancelRecordingSessionDueToDisconnection();
          } else {
            _exitMonitoringDueToDisconnection();
          }
        },
        onDone: () {
          // [NEW] Handle stream closed
          debugPrint("[WARNING] ECG Stream ended unexpectedly");
          if (isRecordingSession) {
            _cancelRecordingSessionDueToDisconnection();
          } else {
            _exitMonitoringDueToDisconnection();
          }
        },
      );

      // [NEW] Subscribe to Heart Rate Stream
      _hrSubscription?.cancel();
      _hrSubscription = _ecgService.hrStream.listen(
        (hr) {
          if (mounted) {
            setState(() {
              heartRate = hr;
            });

            if (isRecordingSession) {
              _recordedHRData.add(hr);
              debugPrint("Recording HR: $hr");
            }
          }
        },
        onError: (error) {
          // [NEW] Handle HR stream errors
          debugPrint("[ERROR] HR Stream Error: $error");
          if (isRecordingSession) {
            _cancelRecordingSessionDueToDisconnection();
          } else {
            _exitMonitoringDueToDisconnection();
          }
        },
      );

      setState(() {
        isMonitoring = true;
        Provider.of<MonitoringProvider>(
          context,
          listen: false,
        ).setMonitoring(true);
        heartRate = 0;
        _signalQuality = SignalQuality.unknown; // Reset state
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start: $e')));
    }
  }

  void _pauseMonitoring() async {
    // [NEW] Pause only - keep BT connected for resume
    try {
      await _nativeService.stopECG();
    } catch (e) {
      print("Pause Error: $e");
    }

    _hrSubscription?.cancel();
    _ecgSubscription?.cancel();

    if (mounted) {
      setState(() {
        isMonitoring = false;
        Provider.of<MonitoringProvider>(
          context,
          listen: false,
        ).setMonitoring(false);
      });
      // [IMPORTANT] DO NOT disconnect BT - user can resume!
      debugPrint("[INFO] Monitoring paused. BT still connected.");
    }
  }

  void _stopMonitoringAndDisconnect() async {
    // [NEW] Stop and disconnect BT (for disconnection events)
    try {
      await _nativeService.stopECG();
    } catch (e) {
      print("Stop Error: $e");
    }

    _hrSubscription?.cancel();
    _ecgSubscription?.cancel();
    _stopBluetoothCheckTimer();

    if (mounted) {
      setState(() {
        isMonitoring = false;
        Provider.of<MonitoringProvider>(
          context,
          listen: false,
        ).setMonitoring(false);
      });

      // [NEW] Disconnect Bluetooth when connection is lost
      final bluetoothProvider = Provider.of<BluetoothProvider>(
        context,
        listen: false,
      );
      bluetoothProvider.disconnect();
      debugPrint("[INFO] Monitoring stopped. BT disconnected.");
    }
  }

  void _stopMonitoring() async {
    // [LEGACY] Redirect to pause (for normal stop button)
    _pauseMonitoring();
  }

  @override
  void initState() {
    super.initState();
    // [NEW] Listen to actual Bluetooth adapter state changes
    _setupBluetoothAdapterListener();
  }

  /// [NEW] Setup Bluetooth adapter state listener
  void _setupBluetoothAdapterListener() {
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      debugPrint("[BT ADAPTER] State changed: $state");

      // If Bluetooth turns OFF while monitoring or recording
      if (state == BluetoothAdapterState.off) {
        if (isRecordingSession) {
          debugPrint("[CRITICAL] BT turned OFF during recording!");
          _cancelRecordingSessionDueToDisconnection();
        } else if (isMonitoring) {
          debugPrint("[CRITICAL] BT turned OFF during monitoring!");
          _exitMonitoringDueToDisconnection();
        }
      }
    });
  }

  /// [NEW] Start periodic check for Bluetooth connection
  void _startBluetoothCheckTimer() {
    _btCheckTimer?.cancel();
    _btCheckTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      final bluetoothProvider = Provider.of<BluetoothProvider>(
        context,
        listen: false,
      );

      // [NEW] Check during BOTH monitoring and recording
      if ((isMonitoring || isRecordingSession) &&
          bluetoothProvider.connectedDevice == null) {
        debugPrint(
          "[CRITICAL] BT disconnected during ${isRecordingSession ? 'recording' : 'monitoring'}",
        );

        if (isRecordingSession) {
          _cancelRecordingSessionDueToDisconnection();
        } else if (isMonitoring) {
          // [NEW] Stop monitoring immediately if BT disconnected
          _exitMonitoringDueToDisconnection();
        }

        _btCheckTimer?.cancel();
      }
    });
  }

  /// [NEW] Stop BT check timer
  void _stopBluetoothCheckTimer() {
    _btCheckTimer?.cancel();
  }

  /// [NEW] Exit monitoring (not recording) when BT disconnects
  void _exitMonitoringDueToDisconnection() {
    debugPrint("Exiting monitoring due to Bluetooth disconnection");
    _stopMonitoringAndDisconnect(); // [NEW] Use disconnect version

    if (mounted) {
      // Navigate to home screen
      Navigator.pushReplacementNamed(context, AppRoutes.home);

      // Show message on home screen
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Bluetooth is not connected"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      });
    }
  }

  /// [NEW] Cancel recording without saving (due to BT disconnection)
  void _cancelRecordingSessionDueToDisconnection() {
    debugPrint("Session CANCELLED due to Bluetooth disconnection");
    _recordingTimer?.cancel();

    setState(() {
      isRecordingSession = false;
    });

    // Clear all buffers (don't save)
    _recordedECGData.clear();
    _recordedHRData.clear();
    _sessionWindowResults.clear();
    _tenSecBuffer.clear();
    _recordingSeconds = 0;

    // [NEW] Stop monitoring stream AND disconnect
    _stopMonitoringAndDisconnect();

    if (mounted) {
      // [NEW] Navigate to home screen
      Navigator.pushReplacementNamed(context, AppRoutes.home);

      // [NEW] Show message on home screen
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Bluetooth is not connected"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      });
    }
  }

  void dispose() {
    _btCheckTimer?.cancel();
    _adapterStateSubscription?.cancel(); // [NEW] Cancel BT adapter listener
    _hrSubscription?.cancel();
    _ecgSubscription?.cancel();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BluetoothProvider, MonitoringProvider>(
      builder: (context, bluetoothProvider, monitoringProvider, child) {
        final connectedDevice = bluetoothProvider.connectedDevice;
        final selectedSampleRate = monitoringProvider.selectedSampleRate;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white,
            title: const Text(
              'ECG Monitoring',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          bottomNavigationBar: const BottomNav(currentIndex: 0),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Device Status (Compact)
                  _buildDeviceStatus(connectedDevice, selectedSampleRate),

                  const SizedBox(height: 12),

                  // 2. ECG Waveform (Primary Visual - Expanded)
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A202C),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.cyan.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: [
                            AnimatedECG(
                              isRunning: isMonitoring,
                              dataStream: isMonitoring
                                  ? _ecgService.ecgStream
                                  : null,
                            ),
                            if (!isMonitoring)
                              Center(
                                child: Text(
                                  "Press Start to Monitor",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. Info Row: Heart Rate & Signal Quality (Equal Height & 2 Columns)
                  Expanded(
                    flex: 2,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Heart Rate (Compact)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.favorite,
                                          color: Colors.red.shade400,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "HEART RATE",
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            heartRate == 0
                                                ? '--'
                                                : '$heartRate',
                                            style: const TextStyle(
                                              fontSize: 42,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'bpm',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Signal Quality (Placeholder UI)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.graphic_eq,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "SIGNAL",
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // Placeholder Visuals
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildSignalDot(
                                      active:
                                          isMonitoring &&
                                          _signalQuality == SignalQuality.good,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 6),
                                    // Removed Yellow as requested
                                    _buildSignalDot(
                                      active:
                                          isMonitoring &&
                                          _signalQuality == SignalQuality.bad,
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (isMonitoring)
                                  if (_signalQuality == SignalQuality.good)
                                    Text(
                                      "Good",
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    )
                                  else if (_signalQuality == SignalQuality.bad)
                                    Text(
                                      "Bad",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    )
                                  else
                                    const Text(
                                      "Checking...",
                                      style: TextStyle(
                                        color: Colors.blueGrey,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                else
                                  const Text(
                                    "--",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Action Area: Control or Recording
                  // Fixed height to ensure buttons are always consistent
                  SizedBox(
                    height: 72,
                    child: isRecordingSession
                        // Recording Active State
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.fiber_manual_record,
                                            color: Colors.red.shade400,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatTime(_recordingSeconds),
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Monospace',
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade400,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(Icons.stop_circle, size: 28),
                                  label: const Text(
                                    "STOP",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: _stopRecordingSession,
                                ),
                              ),
                            ],
                          )
                        // Normal Monitoring / Idle State
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Monitor Toggle Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isMonitoring
                                        ? Colors.orange.shade50
                                        : Colors.green.shade600,
                                    foregroundColor: isMonitoring
                                        ? Colors.orange.shade800
                                        : Colors.white,
                                    elevation: isMonitoring ? 0 : 4,
                                    side: isMonitoring
                                        ? BorderSide(
                                            color: Colors.orange.shade200,
                                          )
                                        : BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: Icon(
                                    isMonitoring
                                        ? Icons.pause_circle
                                        : Icons.play_circle_fill,
                                    size: 32,
                                  ),
                                  label: Text(
                                    isMonitoring
                                        ? "PAUSE VIEW"
                                        : "START MONITOR",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: isMonitoring
                                      ? _stopMonitoring
                                      : _startMonitoring,
                                ),
                              ),
                              // Record Button (Only visible if monitoring)
                              if (isMonitoring) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.red.shade400,
                                      elevation: 0,
                                      side: BorderSide(
                                        color: Colors.red.shade400,
                                        width: 2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: _startRecordingSession,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.fiber_manual_record,
                                          color: Colors.red.shade400,
                                          size: 24,
                                        ),
                                        const Text(
                                          "REC",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceStatus(String? connectedDevice, int selectedSampleRate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: connectedDevice == null
            ? Colors.grey.shade100
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connectedDevice == null
              ? Colors.grey.shade300
              : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            connectedDevice == null
                ? Icons.bluetooth_disabled
                : Icons.bluetooth_connected,
            color: connectedDevice == null
                ? Colors.grey
                : Colors.green.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connectedDevice == null
                      ? "No Device Connected"
                      : connectedDevice,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: connectedDevice == null
                        ? Colors.grey.shade600
                        : Colors.green.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (connectedDevice != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    "Sample Rate: $selectedSampleRate Hz",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (connectedDevice != null && !isMonitoring)
            Consumer<MonitoringProvider>(
              builder: (context, monProvider, child) => PopupMenuButton<int>(
                icon: Icon(Icons.settings, color: Colors.green.shade700),
                initialValue: selectedSampleRate,
                onSelected: (val) => monProvider.setSampleRate(val),
                itemBuilder: (context) => _sampleRates
                    .map((r) => PopupMenuItem(value: r, child: Text("$r Hz")))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSignalDot({required bool active, required Color color}) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: active ? color : color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
    );
  }
}
