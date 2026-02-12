import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../widgets/bottom_nav.dart';
import '../models/session_model.dart';
import '../services/storage_service.dart';
import '../utils/signal_processing.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _isEditingNote = false;
  final TextEditingController _noteController = TextEditingController();
  SessionModel? _currentSession;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Color _resultColor(String result) {
    switch (result) {
      case 'Good': // New standard
      case 'Normal': // Legacy
        return Colors.green;
      case 'Bad': // New standard
        return Colors.red;
      case 'Tachycardia':
        return Colors.orange;
      case 'Bradycardia':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  late SessionModel _session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null) {
      // Use existing _currentSession if available (rebuilds), otherwise init from args
      if (_currentSession == null) {
        _session = SessionModel(
          sessionId: args['sessionId'] as String? ?? 'UNKNOWN',
          userId: args['userId'] as String? ?? 'UNKNOWN',
          timestamp: args['timestamp'] as String? ?? args['date'] ?? '',
          durationSeconds: args['durationSeconds'] as int? ?? 0,
          averageHeartRate: args['avgHR'] as int? ?? 0,
          samplingRate: args['samplingRate'] as int? ?? 125,
          ecgSamples: (args['ecgData'] as List?)?.cast<int>() ?? [],
          signalQuality: args['result'] as String? ?? 'Good',
          exported: args['exported'] as bool? ?? false,
          windowResults: (args['windowResults'] as List?)?.cast<bool>() ?? [],
          healthNote: args['healthNote'] as String?,
          hrvHrAvg: (args['hrvHrAvg'] as num?)?.toDouble(),
          hrvRmssd: (args['hrvRmssd'] as num?)?.toDouble(),
          hrvSdnn: (args['hrvSdnn'] as num?)?.toDouble(),
          hrvMeanRr: (args['hrvMeanRr'] as num?)?.toDouble(),
          hrvCvRr: (args['hrvCvRr'] as num?)?.toDouble(),
        );
        _currentSession = _session; // Sync
      } else {
        _session = _currentSession!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentSession == null) {
      return const Scaffold(
        body: Center(child: Text('Error: No session data')),
      );
    }

    // Use local _session for cleaner access
    final session = _session;
    final result = session.signalQuality;

    // Helper formatting
    final dateStr = session.timestamp.length > 10
        ? session.timestamp.substring(0, 10)
        : session.timestamp;

    final durationStr =
        "${(session.durationSeconds ~/ 60).toString().padLeft(2, '0')}:${(session.durationSeconds % 60).toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(title: const Text('Session Detail')),

      bottomNavigationBar: const BottomNav(currentIndex: 1),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Result Card (Visual Anchor)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _resultColor(result).withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _resultColor(result).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'SIGNAL QUALITY RESULT',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    result == 'Normal' ? 'Good' : result,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: _resultColor(result),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Overall signal quality during this session",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 1. Quality Breakdown (Moved to Top)
            if (session.windowResults.isNotEmpty) ...[
              Text(
                "Quality Breakdown (10s Windows)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      "Total",
                      session.windowResults.length.toString(),
                      Colors.black87,
                    ),
                    _buildStatItem(
                      "Good",
                      session.windowResults
                          .where((e) => e == true)
                          .length
                          .toString(),
                      Colors.green,
                    ),
                    _buildStatItem(
                      "Bad",
                      session.windowResults
                          .where((e) => e == false)
                          .length
                          .toString(),
                      Colors.red,
                    ),
                    _buildStatItem(
                      "Pass %",
                      session.windowResults.isEmpty
                          ? "0.0%"
                          : "${((session.windowResults.where((e) => e == true).length / session.windowResults.length) * 100).toStringAsFixed(1)}%",
                      result == 'Good' || result == 'Normal'
                          ? Colors.green
                          : Colors.red,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // 2. Session Info (Moved Below)
            Text(
              "Session Details",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade100,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDetailRow(Icons.calendar_today, 'Date', dateStr),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  _buildDetailRow(Icons.timer, 'Duration', durationStr),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  _buildDetailRow(
                    Icons.favorite,
                    'Avg Heart Rate',
                    '${session.averageHeartRate} bpm',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // [NEW] HRV Metrics Section
            // Force display even if null (show 0 or N/A)
            if (true) ...[
              Text(
                "HRV Analysis",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple.shade100),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          "HR Avg",
                          "${(session.hrvHrAvg ?? 0).toStringAsFixed(1)}",
                          Colors.purple.shade700,
                        ),
                        _buildStatItem(
                          "RMSSD",
                          "${(session.hrvRmssd ?? 0).toStringAsFixed(1)}",
                          Colors.purple.shade700,
                        ),
                        _buildStatItem(
                          "SDNN (std)",
                          "${(session.hrvSdnn ?? 0).toStringAsFixed(1)}",
                          Colors.purple.shade700,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          "Mean RR",
                          "${((session.hrvMeanRr ?? 0) * 1000).toStringAsFixed(0)} ms",
                          Colors.black87,
                        ),
                        _buildStatItem(
                          "CV_RR",
                          "${(session.hrvCvRr ?? 0).toStringAsFixed(2)}",
                          Colors.black87,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // [NEW] Health Note Section (Only for Good Sessions)
            if (result == 'Good' || result == 'Normal') ...[
              Text(
                "Health Note",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: _isEditingNote
                    ? _buildNoteEditMode()
                    : _buildNoteDisplayMode(session),
              ),
              const SizedBox(height: 32),
            ],

            // ECG Playback / Recorded Signal
            Text(
              "Recorded Signal",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),

            // Playback widget with time scrubbing
            _ECGPlaybackWidget(
              ecgData: session.ecgSamples,
              samplingRate: session.samplingRate,
            ),

            // Manual Export Button
            const SizedBox(height: 32),
            if (result == 'Good' || result == 'Normal')
              Center(
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        side: BorderSide(color: Colors.blue.shade200),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () => _exportSession(context, session),
                      icon: const Icon(
                        Icons.copy,
                      ), // Icon changed to reflect Clipboard action
                      label: const Text(
                        "Export Session Data (JSON)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Export manually to avoid uploading low-quality signal sessions.\n(Copies JSON to Clipboard)",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: Column(
                  children: [
                    Icon(Icons.block, color: Colors.red.shade300, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      "Export Unavailable",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Session quality is too poor for export (Need >95% Good).\nPlease record a new session with better signal.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildNoteDisplayMode(SessionModel session) {
    final currentNote = session.healthNote;
    final hasNote = currentNote != null && currentNote.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                hasNote ? currentNote : "No health note added",
                style: TextStyle(
                  fontSize: 16,
                  color: hasNote ? Colors.black87 : Colors.grey.shade500,
                  fontStyle: hasNote ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue.shade700),
                  onPressed: () {
                    setState(() {
                      _noteController.text = currentNote ?? '';
                      _isEditingNote = true;
                    });
                  },
                  tooltip: "Edit Note",
                ),
                if (hasNote)
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red.shade400),
                    onPressed: () => _deleteNote(session),
                    tooltip: "Delete Note",
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoteEditMode() {
    return Column(
      children: [
        TextField(
          controller: _noteController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                "Enter your health observations (symptoms, conditions, etc.)",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                debugPrint("SessionDetail: Cancel button pressed");
                setState(() {
                  _isEditingNote = false;
                  _noteController.clear();
                });
              },
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                debugPrint("SessionDetail: Save button pressed");
                _saveNote();
              },
              icon: const Icon(Icons.save),
              label: const Text("Save"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                // Override global infinite width
                minimumSize: const Size(100, 48),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveNote() async {
    debugPrint("SessionDetail: _saveNote called");
    if (_currentSession == null) {
      debugPrint("SessionDetail: Error - _currentSession is null");
      return;
    }

    try {
      final updatedSession = SessionModel(
        sessionId: _currentSession!.sessionId,
        userId: _currentSession!.userId,
        timestamp: _currentSession!.timestamp,
        durationSeconds: _currentSession!.durationSeconds,
        averageHeartRate: _currentSession!.averageHeartRate,
        samplingRate: _currentSession!.samplingRate,
        ecgSamples: _currentSession!.ecgSamples,
        signalQuality: _currentSession!.signalQuality,
        exported: _currentSession!.exported,
        windowResults: _currentSession!.windowResults,
        healthNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      debugPrint("SessionDetail: Updating session in storage...");
      await StorageService.updateSession(updatedSession);
      debugPrint("SessionDetail: Session updated successfully");

      if (mounted) {
        setState(() {
          _currentSession = updatedSession;
          _session = updatedSession;
          _isEditingNote = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Health note saved successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("SessionDetail: Error saving note - $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving note: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNote(SessionModel session) async {
    if (_currentSession == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Note"),
        content: const Text(
          "Are you sure you want to delete this health note?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updatedSession = SessionModel(
        sessionId: _currentSession!.sessionId,
        userId: _currentSession!.userId,
        timestamp: _currentSession!.timestamp,
        durationSeconds: _currentSession!.durationSeconds,
        averageHeartRate: _currentSession!.averageHeartRate,
        samplingRate: _currentSession!.samplingRate,
        ecgSamples: _currentSession!.ecgSamples,
        signalQuality: _currentSession!.signalQuality,
        exported: _currentSession!.exported,
        windowResults: _currentSession!.windowResults,
        healthNote: null,
      );

      await StorageService.updateSession(updatedSession);

      if (mounted) {
        setState(() {
          _currentSession = updatedSession;
          _session = updatedSession;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Health note deleted"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _exportSession(BuildContext context, SessionModel session) {
    // 1. Construct Export Map
    final ecgData = session.ecgSamples;
    final windowResults = session.windowResults;

    // Build Windows List for JSON
    List<Map<String, dynamic>> windowsJson = [];
    int windowSize = session.samplingRate * 10; // 10s per window

    // [NEW] Robust fallback: Re-calculate OVERALL HRV if stored stats are null
    // This ensures export works even for legacy sessions or if save failed.
    Map<String, double> overallMetrics = {
      'hr_avg': session.hrvHrAvg ?? 0.0,
      'rr_mean': session.hrvMeanRr ?? 0.0,
      'rr_std': session.hrvSdnn ?? 0.0,
      'rmssd': session.hrvRmssd ?? 0.0,
      'cv_rr': session.hrvCvRr ?? 0.0,
    };

    // Check if re-calc is needed (if hr_avg is missing/zero but we have data)
    bool needRecalc =
        (session.hrvHrAvg == null || session.hrvHrAvg == 0) &&
        session.ecgSamples.isNotEmpty;
    if (needRecalc) {
      try {
        debugPrint("Export: Re-calculating Overall HRV on-the-fly...");
        overallMetrics = SignalProcessing.calculateHRV(
          session.ecgSamples,
          session.samplingRate,
        );
      } catch (e) {
        debugPrint("Export: Overall Re-calc Error: $e");
      }
    }

    for (int i = 0; i < windowResults.length; i++) {
      int startIdx = i * windowSize;
      int endIdx = startIdx + windowSize;

      // Safety clamp
      if (startIdx >= ecgData.length) break;
      if (endIdx > ecgData.length) endIdx = ecgData.length;

      List<int> windowSamples = ecgData.sublist(startIdx, endIdx);

      // [NEW] Calculate per-window metrics
      Map<String, double> metrics = {};
      try {
        metrics = SignalProcessing.calculateHRV(
          windowSamples,
          session.samplingRate,
        );
      } catch (e) {
        debugPrint("Export: Calc error for window $i: $e");
      }

      windowsJson.add({
        "id": i + 1,
        "status": windowResults[i] ? "Good" : "Bad",
        "duration_seconds": 10,
        "hr_avg": metrics['hr_avg'] ?? 0.0,
        "hrv_metrics": metrics, // detailed HRV
        "sample_count": windowSamples.length,
        "samples": windowSamples,
      });
    }

    final exportData = {
      "session_id": session.sessionId, // Use actual ID
      "device_id": "Movesense_MD", // Mock ID
      "timestamp": session.timestamp,
      "duration_seconds": session.durationSeconds, // Use int seconds
      "sampling_rate": session.samplingRate,
      "signal_quality": session.signalQuality,
      "heart_rate": {"average": session.averageHeartRate, "unit": "bpm"},
      "healthNote": session.healthNote, // [NEW] Export Note
      "quality_stats": {
        "total_windows": windowResults.length,
        "good_windows": windowResults.where((x) => x).length,
        "pass_rate_percent": windowResults.isNotEmpty
            ? (windowResults.where((x) => x).length /
                      windowResults.length *
                      100)
                  .toStringAsFixed(1)
            : "0",
      },
      "hrv_analysis": {
        "hr_avg": overallMetrics['hr_avg'],
        "rr_mean_s": overallMetrics['rr_mean'],
        "rr_std_sdnn": overallMetrics['rr_std'],
        "rmssd": overallMetrics['rmssd'],
        "cv_rr": overallMetrics['cv_rr'],
      },
      "windows": windowsJson,
      "ecg": {"count": ecgData.length, "samples": ecgData},
    };

    // 2. Convert to JSON String
    String jsonString = "";
    try {
      jsonString = jsonEncode(exportData);
    } catch (e) {
      jsonString = "Error encoding JSON: $e";
    }

    // 3. Copy to Clipboard
    Clipboard.setData(ClipboardData(text: jsonString)).then((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Exported ${ecgData.length} samples to Clipboard! (JSON)",
            ),
            backgroundColor: Colors.blue.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    // Note: In a real app with file permission, we would write to a file here.
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 24),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private Playback Widget (Enhanced)
// ---------------------------------------------------------------------------
class _ECGPlaybackWidget extends StatefulWidget {
  final List<int> ecgData;
  final int samplingRate;
  const _ECGPlaybackWidget({required this.ecgData, required this.samplingRate});

  @override
  State<_ECGPlaybackWidget> createState() => _ECGPlaybackWidgetState();
}

class _ECGPlaybackWidgetState extends State<_ECGPlaybackWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late int _windowSize;
  late int _windowDuration;

  // Current Playback Position (Index of the LEFT side of window)
  int _currentIndex = 0;
  bool _isPlaying = false;

  // Fixed Scale Factors
  double _minVal = -2000;
  double _maxVal = 2000;

  @override
  void initState() {
    super.initState();
    // Fixed Clinical Window: 3 Seconds
    _windowDuration = 3;
    _windowSize = widget.samplingRate * _windowDuration;

    // Fixed Clinical Scale: +/- 2000 uV (Total 4000 uV range)
    _minVal = -2000;
    _maxVal = 2000;

    // Controller drives the automatic scrolling
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100), // Fast tick for smooth UI
    );

    _controller.addListener(() {
      if (_isPlaying) {
        setState(() {
          // Advance index
          // samples per second = widget.samplingRate
          // update every 100ms (0.1s) -> move 0.1 * samplingRate samples
          int step = (widget.samplingRate * 0.1).round();
          if (step < 1) step = 1;

          _currentIndex += step;

          if (_currentIndex >= widget.ecgData.length - _windowSize) {
            _currentIndex = 0; // Loop
            // Optional: Pause at end
            // _isPlaying = false;
            // _controller.stop();
          }
        });
      }
    });
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    });
  }

  void _onSeek(double value) {
    setState(() {
      _currentIndex = value.toInt();
    });
  }

  String _formatTimestamp(int sampleIndex) {
    final double seconds = sampleIndex / widget.samplingRate.toDouble();
    final int m = seconds ~/ 60;
    final int s = seconds.toInt() % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ecgData.isEmpty) {
      return Container(
        height: 240, // consistent height
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.signal_cellular_off, color: Colors.grey, size: 48),
              SizedBox(height: 16),
              Text(
                "No recorded ECG available for this session",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Bounds Check
    int start = _currentIndex;
    int end = start + _windowSize;
    if (end > widget.ecgData.length) {
      end = widget.ecgData.length;
    }

    // Safely extract sublist
    final windowData = widget.ecgData.sublist(
      start.clamp(0, widget.ecgData.length),
      end.clamp(0, widget.ecgData.length),
    );

    final maxIndex = (widget.ecgData.length - _windowSize)
        .clamp(0, widget.ecgData.length)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monitor_heart,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  "Recorded ECG (Raw Signal)",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              "${widget.samplingRate} Hz • $_windowDuration sec window",
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 1. Waveform Window
        Container(
          height: 240, // Tall enough for good resolution
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Dark medical background
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                // Grid Background
                CustomPaint(
                  size: Size.infinite,
                  painter: _GridPainter(
                    windowDuration: _windowDuration,
                    voltageRange: _maxVal - _minVal,
                  ),
                ),
                // Signal
                CustomPaint(
                  size: Size.infinite,
                  painter: _PlaybackPainter(
                    data: windowData,
                    minVal: _minVal,
                    maxVal: _maxVal,
                  ),
                ),
                // Gradient Overlay (Edges) for depth perception
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                        stops: const [0.0, 0.05, 0.95, 1.0],
                      ),
                    ),
                  ),
                ),
                // Time Label Overlay
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatTimestamp(_currentIndex),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Timeline Controls
        Row(
          children: [
            IconButton(
              onPressed: _togglePlay,
              icon: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                size: 48,
                color: _isPlaying ? Colors.orange : Colors.teal.shade400,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8.0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16.0,
                  ),
                ),
                child: Slider(
                  value: _currentIndex.toDouble().clamp(0, maxIndex),
                  min: 0,
                  max: maxIndex,
                  activeColor: Colors.teal.shade600,
                  inactiveColor: Colors.teal.shade100,
                  onChanged: _onSeek,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final int windowDuration; // in seconds
  final double voltageRange; // in uV (e.g. 4000)

  _GridPainter({required this.windowDuration, required this.voltageRange});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF151515); // Dark Gray
    // Alternative: Pinkish paper color -> Color(0xFFFFF0F5) but user asked for dark style previously.
    // Sticking to dark mode clinical style.

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final majorGridPaint = Paint()
      ..color = const Color.fromARGB(255, 30, 100, 40).withOpacity(0.5)
      ..strokeWidth = 1.0; // Major Lines

    final minorGridPaint = Paint()
      ..color = const Color.fromARGB(255, 30, 100, 40).withOpacity(0.2)
      ..strokeWidth = 0.5; // Minor Lines

    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.0;

    // -------------------------
    // VERTICAL (TIME) GRID
    // -------------------------
    // Major: Every 1 second
    // Minor: Every 0.2 second (Standard ECG box = 200ms large, 40ms small)
    // Let's stick to user request: Major 1s, Minor 0.2s

    double pixelsPerSecond = size.width / windowDuration;
    double minorStepX = pixelsPerSecond * 0.2; // 0.2s

    // Draw Vertical
    int totalMinorStepsX = (windowDuration / 0.2).round();
    for (int i = 0; i <= totalMinorStepsX; i++) {
      double x = i * minorStepX;
      bool isMajor = (i % 5) == 0; // Every 5 minor steps (5 * 0.2 = 1.0s)
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMajor ? majorGridPaint : minorGridPaint,
      );
    }

    // -------------------------
    // HORIZONTAL (VOLTAGE) GRID
    // -------------------------
    // Range: 4000 uV (-2000 to +2000)
    // Major: 500 uV
    // Minor: 100 uV
    // Zero line in center

    double pixelsPerUV = size.height / voltageRange;
    double zeroY = size.height / 2;
    double minorStepY = 100 * pixelsPerUV;

    int halfSteps = (voltageRange / 2 / 100)
        .round(); // steps from 0 to top/bottom

    // Draw from center outwards to ensure alignment
    for (int i = 0; i <= halfSteps; i++) {
      double offset = i * minorStepY;
      bool isMajor = (i % 5) == 0; // Every 500uV

      Paint p = isMajor ? majorGridPaint : minorGridPaint;
      if (i == 0) p = axisPaint; // Center line

      // Up from center
      canvas.drawLine(
        Offset(0, zeroY - offset),
        Offset(size.width, zeroY - offset),
        p,
      );
      // Down from center
      if (i != 0) {
        canvas.drawLine(
          Offset(0, zeroY + offset),
          Offset(size.width, zeroY + offset),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.windowDuration != windowDuration ||
        oldDelegate.voltageRange != voltageRange;
  }
}

class _PlaybackPainter extends CustomPainter {
  final List<int> data;
  final double minVal;
  final double maxVal;

  _PlaybackPainter({
    required this.data,
    required this.minVal,
    required this.maxVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color =
          const Color(0xFF00FF88) // Bright Medical Green
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    // Scale X: Fit window width
    final double stepX = size.width / (data.length - 1);

    // Scale Y: Map minVal..maxVal to height..0 (inverted Y)
    final double range = maxVal - minVal;

    double normalizeY(int val) {
      // Avoid division by zero
      if (range == 0) return size.height / 2;

      double normalized = (val - minVal) / range;
      // Flip Y because canvas 0 is top
      return size.height - (normalized * size.height);
    }

    path.moveTo(0, normalizeY(data[0]));

    for (int i = 1; i < data.length; i++) {
      path.lineTo(i * stepX, normalizeY(data[i]));
    }

    // Optional: Shadow/Glow effect (duplicated path with blur)
    final shadowPaint = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.3)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PlaybackPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.minVal != minVal ||
        oldDelegate.maxVal != maxVal;
  }
}
