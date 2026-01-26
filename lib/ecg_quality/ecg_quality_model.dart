import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/signal_processing.dart';

class EcgQualityModel {
  bool _isLoaded = false;
  Map<String, dynamic>? _modelData;

  // Model parameters from JSON
  List<String> _featureOrder = [];
  List<double> _weights = [];
  double _bias = 0.0;
  double _threshold = 0.5;
  List<double> _scalerMean = [];
  List<double> _scalerScale = [];
  int _samplingRate = 125;

  /// Load the AI model from assets.
  Future<void> load() async {
    try {
      String jsonString = await rootBundle.loadString(
        'assets/ecg_quality_model.json',
      );
      _modelData = jsonDecode(jsonString);

      if (_modelData != null) {
        _featureOrder = List<String>.from(_modelData!['feature_names']);
        _weights = List<double>.from(_modelData!['coefficients']);
        _bias = _modelData!['intercept']?.toDouble() ?? 0.0;
        _threshold = _modelData!['threshold']?.toDouble() ?? 0.5;
        _scalerMean = List<double>.from(_modelData!['scaler_mean']);
        _scalerScale = List<double>.from(_modelData!['scaler_scale']);
        _samplingRate = _modelData!['sampling_rate'] ?? 125;

        _isLoaded = true;
        debugPrint(
          "EcgQualityModel loaded successfully. Threshold: $_threshold",
        );
      }
    } catch (e) {
      debugPrint("Error loading EcgQualityModel: $e");
      _isLoaded = false;
    }
  }

  /// Check if the extracted features represent a "Good" quality signal.
  bool isGood(List<int> samples) {
    if (!_isLoaded || samples.isEmpty) {
      // Fallback or safe guard
      return false;
    }

    // 1. Extract Features
    Map<String, double> rawFeatures = SignalProcessing.extractFeatures(
      samples,
      _samplingRate,
    );

    // 2. Prepare Feature Vector (ordered)
    List<double> featureVector = [];
    for (String key in _featureOrder) {
      featureVector.add(rawFeatures[key] ?? 0.0);
    }

    // 3. Preprocess (Standard Scaler)
    // Formula: z = (x - mean) / scale
    if (featureVector.length != _scalerMean.length) {
      debugPrint(
        "Feature count mismatch! Expected ${_scalerMean.length}, got ${featureVector.length}",
      );
      return false;
    }

    List<double> scaledFeatures = [];
    for (int i = 0; i < featureVector.length; i++) {
      double val = featureVector[i];
      double mean = _scalerMean[i];
      double scale = _scalerScale[i];

      // Avoid division by zero
      if (scale == 0) scale = 1.0;

      scaledFeatures.add((val - mean) / scale);
    }

    // 4. Linear Inference (Dot Product + Bias)
    double score = 0.0;
    for (int i = 0; i < scaledFeatures.length; i++) {
      score += scaledFeatures[i] * _weights[i];
    }
    score += _bias;

    // 5. Activation (Sigmoid)
    // Note: If the model output is already a probability (0-1), use sigmoid.
    // If it's pure logits (SVM-like), check sign.
    // Based on "threshold: 0.4", likely probability output is expected.
    double probability = 1.0 / (1.0 + math.exp(-score));

    debugPrint(
      "ECG Quality Check -> Score: ${score.toStringAsFixed(4)}, Prob: ${probability.toStringAsFixed(4)}, Thresh: $_threshold",
    );

    return probability > _threshold;
  }

  /// Sanity Check: Is the signal physically valid?
  /// Prevents flatlines or low-amplitude noise from passing as "Good".
  bool isSignalPhysicallyValid(List<int> samples) {
    if (samples.isEmpty) return false;

    // 1. Amplitude Check (Max - Min)
    int minVal = samples[0];
    int maxVal = samples[0];
    int sum = 0;

    for (var s in samples) {
      if (s < minVal) minVal = s;
      if (s > maxVal) maxVal = s;
      sum += s;
    }

    // Threshold: < 50 units (tuned for typical 10-bit/12-bit ECG ADC ranges)
    // If signal is flat (e.g. disconnected), delta is usually < 10.
    if ((maxVal - minVal) < 50) {
      debugPrint("Sanity Check Fail: Signal too flat (Delta < 50)");
      return false;
    }

    // [NEW] Extremely high amplitude check (Clipping/Movement Artifacts)
    // Typical ECG shouldn't swing thousands of units instantly unless it's a huge artifact
    if ((maxVal - minVal) > 5000) {
      // Specific to Movesense scale, adjust if needed
      debugPrint(
        "Sanity Check Fail: Signal amplitude too huge (Delta > 5000), likely movement artifact",
      );
      return false;
    }

    // 2. Variance Check (Relative to Mean)
    double mean = sum / samples.length;
    double varianceSum = 0;
    for (var s in samples) {
      varianceSum += (s - mean) * (s - mean);
    }
    double variance = varianceSum / samples.length;

    // Threshold: Variance < 1.0 implies extremely constant signal
    if (variance < 1.0) {
      debugPrint("Sanity Check Fail: Variance too low");
      return false;
    }

    // [NEW] Zero Crossing Rate (ZCR) Check for High Frequency Noise
    // Rubbing fingers creates high freq noise. Real ECG is relatively smooth.
    // We calculate approximate ZCR around the mean.
    int zeroCrossings = 0;
    for (int i = 0; i < samples.length - 1; i++) {
      double val1 = samples[i] - mean;
      double val2 = samples[i + 1] - mean;
      if ((val1 > 0 && val2 < 0) || (val1 < 0 && val2 > 0)) {
        zeroCrossings++;
      }
    }
    double zcr = zeroCrossings / samples.length;

    // If signal crosses mean too often (e.g. > 30% of time), it's likely pure noise.
    // 30% of 125Hz is ~37Hz oscillation, which is too fast for continuous ECG features.
    if (zcr > 0.3) {
      debugPrint(
        "Sanity Check Fail: High Frequency Noise (ZCR=${zcr.toStringAsFixed(2)})",
      );
      return false;
    }

    return true;
  }
}
