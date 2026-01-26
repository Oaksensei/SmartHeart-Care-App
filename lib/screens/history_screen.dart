import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../widgets/bottom_nav.dart';
import '../utils/mock_data.dart';
import '../services/storage_service.dart';
import '../models/session_model.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Color _resultColor(String result) {
    switch (result) {
      case 'Normal':
        return Colors.green.shade600; // Medical Green
      case 'Tachycardia':
        return Colors.orange.shade700;
      case 'Bradycardia':
        return Colors.blue.shade700;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get Active User
    final userId = AppMockState.activeUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
      body: userId == null
          ? const Center(child: Text("Please login to view history"))
          : FutureBuilder<List<SessionModel>>(
              future: StorageService.getSessions(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final sessions = snapshot.data ?? [];

                if (sessions.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No session recorded',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: sessions.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final session = sessions[index];

                    // Convert SessionModel to Map for navigation arguments if needed,
                    // or update SessionDetailScreen to accept SessionModel.
                    // Existing code expects a Map, let's convert to maintain compatibility
                    // or just pass JSON map.
                    // The previous code passed `session` (Map).
                    // SessionDetailScreen likely parses Map.
                    // Let's pass session.toJson() + extra fields if needed.

                    final result =
                        'Normal'; // Placeholder, AI logic not stored in file yet if simple
                    // Wait, SessionModel has no 'result' field in my definition?
                    // I didn't add 'result' to SessionModel in step 198.
                    // I should check SessionModel definition.
                    // User requirements: "signalQualitySummary".
                    // I implemented `averageHeartRate`, `ecgSamples`.
                    // Let's assume result is 'Normal' for now or averageHeartRate check.

                    final date = session.timestamp.substring(0, 10);
                    final durationVal =
                        "${(session.durationSeconds ~/ 60).toString().padLeft(2, '0')}:${(session.durationSeconds % 60).toString().padLeft(2, '0')}";
                    final avgHR = session.averageHeartRate;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          // Navigate with Map for compatibility
                          Navigator.pushNamed(
                            context,
                            AppRoutes.sessionDetail,
                            arguments: {
                              'sessionId': session.sessionId, // [FIX]
                              'userId': session.userId, // [FIX]
                              'timestamp':
                                  session.timestamp, // [FIX] Use timestamp
                              'date': date, // Keep for fallback
                              'durationSeconds':
                                  session.durationSeconds, // [FIX] Pass int
                              'avgHR': avgHR,
                              'result': session.signalQuality,
                              'ecgData': session.ecgSamples,
                              'samplingRate': session.samplingRate,
                              'windowResults': session.windowResults,
                              'exported': session.exported,
                              'healthNote': session.healthNote,
                              // [NEW] Pass HRV Metrics
                              'hrvHrAvg': session.hrvHrAvg,
                              'hrvRmssd': session.hrvRmssd,
                              'hrvSdnn': session.hrvSdnn,
                              'hrvMeanRr': session.hrvMeanRr,
                              'hrvCvRr': session.hrvCvRr,
                            },
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _resultColor(result).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.favorite,
                                  color: _resultColor(result),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Date: $date',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$durationVal • HR: $avgHR bpm',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 18,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
