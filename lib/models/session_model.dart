class SessionModel {
  final String sessionId;
  final String userId;
  final String timestamp; // ISO8601
  final int durationSeconds;
  final int averageHeartRate;
  final int samplingRate;
  final List<int> ecgSamples;
  final String signalQuality; // 'Good' or 'Bad'
  final bool exported;
  final List<bool> windowResults; // [NEW] True = Good, False = Bad
  final String? healthNote; // Optional health note from user
  final List<int> hrHistory; // [NEW] Recorded 1Hz HR values from device

  // HRV Metrics
  final double? hrvHrAvg;
  final double? hrvRmssd;
  final double? hrvSdnn; // rr_std
  final double? hrvMeanRr;
  final double? hrvCvRr;

  SessionModel({
    required this.sessionId,
    required this.userId,
    required this.timestamp,
    required this.durationSeconds,
    required this.averageHeartRate,
    required this.samplingRate,
    required this.ecgSamples,
    required this.signalQuality,
    this.exported = false,
    this.windowResults = const [],
    this.healthNote,
    this.hrHistory = const [], // Default empty
    this.hrvHrAvg,
    this.hrvRmssd,
    this.hrvSdnn,
    this.hrvMeanRr,
    this.hrvCvRr,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'timestamp': timestamp,
      'durationSeconds': durationSeconds,
      'averageHeartRate': averageHeartRate,
      'samplingRate': samplingRate,
      'ecgSamples': ecgSamples,
      'exported': exported,
      'signalQuality': signalQuality,
      'windowResults': windowResults,
      'healthNote': healthNote,
      'hrHistory': hrHistory,
      'hrvHrAvg': hrvHrAvg,
      'hrvRmssd': hrvRmssd,
      'hrvSdnn': hrvSdnn,
      'hrvMeanRr': hrvMeanRr,
      'hrvCvRr': hrvCvRr,
    };
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      sessionId: json['sessionId'] as String,
      userId: json['userId'] as String,
      timestamp: json['timestamp'] as String,
      durationSeconds: json['durationSeconds'] as int,
      averageHeartRate: json['averageHeartRate'] as int,
      samplingRate: json['samplingRate'] as int,
      ecgSamples: List<int>.from(json['ecgSamples']),
      signalQuality:
          json['signalQuality'] as String? ?? 'Good', // Default for legacy
      exported: json['exported'] as bool? ?? false,
      windowResults:
          (json['windowResults'] as List<dynamic>?)
              ?.map((e) => e as bool)
              .toList() ??
          [],
      healthNote: json['healthNote'] as String?,
      hrHistory: (json['hrHistory'] as List?)?.cast<int>() ?? [],
      hrvHrAvg: (json['hrvHrAvg'] as num?)?.toDouble(),
      hrvRmssd: (json['hrvRmssd'] as num?)?.toDouble(),
      hrvSdnn: (json['hrvSdnn'] as num?)?.toDouble(),
      hrvMeanRr: (json['hrvMeanRr'] as num?)?.toDouble(),
      hrvCvRr: (json['hrvCvRr'] as num?)?.toDouble(),
    );
  }
}
