import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class SignalProcessing {
  /// Extract all 13 features required by the model.
  /// [signal] is the raw ECG data (integers).
  /// [fs] is the sampling rate (e.g., 125 Hz).
  static Map<String, double> extractFeatures(List<int> signal, int fs) {
    if (signal.isEmpty) return {};

    // Convert to double for calculation
    List<double> data = signal.map((e) => e.toDouble()).toList();
    int n = data.length;

    // --- Time Domain Features ---
    double avg = _mean(data);
    double stdDev = _std(data, avg);
    double rmsVal = _rms(data);
    double ptpVal = _ptp(data);
    double diffRmsVal = _diffRms(data);
    double zcrVal = _zcr(data, avg);
    double kurtosisVal = _kurtosis(data, avg, stdDev);
    double skewnessVal = _skewness(data, avg, stdDev);
    double autocorrPeakVal = _autocorrPeak(data, fs); // First peak after 0

    // --- Frequency Domain Features (Spectral) ---
    // Prepare for FFT (pad to next power of 2)
    List<double> psd = _computePSD(data, fs);
    // PSD resolution = fs / n_fft
    // We used padding, so n_fft is next power of 2.
    int nFft = _nextPowerOf2(n);
    double freqRes = fs / nFft;

    // Band Ratios
    double baselineRatio = _bandPowerRatio(
      psd,
      freqRes,
      0,
      2,
    ); // Baseline wander
    double emgRatio = _bandPowerRatio(
      psd,
      freqRes,
      20,
      fs / 2,
    ); // Muscle noise (20Hz+)
    double powerlineRatio = _bandPowerRatio(
      psd,
      freqRes,
      48,
      52,
    ); // 50Hz noise (approx)
    double midbandRatio = _bandPowerRatio(
      psd,
      freqRes,
      5,
      20,
    ); // Good QRS energy usually here
    double spectralEntropy = _spectralEntropy(psd);

    return {
      "std": stdDev,
      "rms": rmsVal,
      "ptp": ptpVal,
      "diff_rms": diffRmsVal,
      "zcr": zcrVal,
      "kurtosis": kurtosisVal,
      "skewness": skewnessVal,
      "baseline_ratio": baselineRatio,
      "emg_ratio": emgRatio,
      "powerline_ratio": powerlineRatio,
      "midband_ratio": midbandRatio,
      "spectral_entropy": spectralEntropy,
      "autocorr_peak": autocorrPeakVal,
    };
  }

  // --- HRV Analysis ---

  /// Calculate HRV metrics from visual R-peaks.
  /// Returns a map with keys: 'hr_avg', 'rr_mean', 'rr_std', 'rmssd', 'cv_rr'.
  static Map<String, double> calculateHRV(List<int> signal, int fs) {
    debugPrint("SignalProcessing: Start HRV Calc on ${signal.length} samples");
    if (signal.length < fs * 2) {
      debugPrint("SignalProcessing: Signal too short (<2s)");
      return {
        'hr_avg': 0.0,
        'rr_mean': 0.0,
        'rr_std': 0.0,
        'rmssd': 0.0,
        'cv_rr': 0.0,
      };
    }

    // 1. Detect R-peaks indices
    List<int> rPeaks = _detectRPeaks(signal, fs);
    debugPrint("SignalProcessing: Detected ${rPeaks.length} R-peaks");

    if (rPeaks.length < 2) {
      debugPrint(
        "SignalProcessing: Not enough peaks (<2). Max Val in signal: ${signal.reduce(math.max)}",
      );
      return {
        'hr_avg': 0.0,
        'rr_mean': 0.0,
        'rr_std': 0.0,
        'rmssd': 0.0,
        'cv_rr': 0.0,
      };
    }

    // 2. Calculate RR intervals (in seconds)
    List<double> rrIntervals = [];
    for (int i = 0; i < rPeaks.length - 1; i++) {
      // Diff in samples / fs = seconds
      double rr = (rPeaks[i + 1] - rPeaks[i]) / fs;
      // Filter unrealistic RR intervals (physical limits: 240BPM to 30BPM)
      // 0.25s to 2.0s
      if (rr > 0.25 && rr < 2.0) {
        rrIntervals.add(rr);
      }
    }

    debugPrint(
      "SignalProcessing: Valid RR Intervals: ${rrIntervals.length} (from ${rPeaks.length} peaks)",
    );

    if (rrIntervals.isEmpty) {
      return {
        'hr_avg': 0.0,
        'rr_mean': 0.0,
        'rr_std': 0.0,
        'rmssd': 0.0,
        'cv_rr': 0.0,
      };
    }

    // 3. Calculate Metrics

    // RR Mean
    double rrMean = _mean(rrIntervals);

    // HR Avg (bpm)
    // 60 / mean_RR
    double hrAvg = (rrMean > 0) ? (60.0 / rrMean) : 0.0;

    // RR Std (SDNN)
    double rrStd = _std(rrIntervals, rrMean);

    // RMSSD (Root Mean Square of Successive Differences)
    double rmssd = _diffRms(rrIntervals);

    // CV_RR (Coefficient of Variation)
    // ratio of std to mean
    double cvRr = (rrMean > 0) ? (rrStd / rrMean) : 0.0;

    debugPrint("SignalProcessing: Result -> HR: $hrAvg, RMSSD: $rmssd");

    return {
      'hr_avg': hrAvg,
      'rr_mean': rrMean,
      'rr_std': rrStd, // SDNN
      'rmssd': rmssd,
      'cv_rr': cvRr,
    };
  }

  /// Simplified Pan-Tompkins-like R-peak detector
  static List<int> _detectRPeaks(List<int> signal, int fs) {
    List<double> data = signal.map((e) => e.toDouble()).toList();

    // [NEW] Normalization (Signal Booster)
    // Scale signal to 0..1000 range to ensure derivatives and thresholds work well
    if (data.isNotEmpty) {
      double minVal = data.reduce(math.min);
      double maxVal = data.reduce(math.max);
      double range = maxVal - minVal;

      debugPrint(
        "SignalProcessing: Raw Range: $minVal to $maxVal (Diff: $range)",
      );

      if (range > 0) {
        for (int i = 0; i < data.length; i++) {
          // Min-Max Normalization -> 0..1000
          data[i] = ((data[i] - minVal) / range) * 1000.0;
        }
        debugPrint("SignalProcessing: Signal Normalized to 0-1000");
      }
    }

    // 1. Differentiation (Highlight slopes)
    // y[n] = x[n] - x[n-1]
    List<double> diff = List.filled(data.length, 0.0);
    for (int i = 1; i < data.length; i++) {
      diff[i] = data[i] - data[i - 1];
    }

    // 2. Squaring (Enhance large values)
    List<double> squared = diff.map((e) => e * e).toList();

    // 3. Moving Window Integration (Smooth out feature)
    // Window size ~150ms => 0.15 * fs
    int windowSize = (0.15 * fs).round();
    List<double> integrated = List.filled(data.length, 0.0);

    double sum = 0.0;
    for (int i = 0; i < data.length; i++) {
      sum += squared[i];
      if (i >= windowSize) {
        sum -= squared[i - windowSize];
      }
      integrated[i] = sum;
    }

    // 4. Thresholding & Peak Finding
    // Find local maxima that exceed threshold

    // Robust max:
    if (integrated.isEmpty) return [];
    double globalMax = integrated.reduce(math.max);

    // Lower threshold to 20% to catch smaller pulses
    double threshold = globalMax * 0.20;

    // Safety: If signal is flat (all 0), threshold 0
    if (globalMax < 10) threshold = 1.0;

    debugPrint(
      "Peak Detection: Max Integrated=$globalMax, Threshold=$threshold",
    );

    List<int> qrsIndices = [];
    int refractoryPeriod = (0.25 * fs).round(); // 250ms refractory

    int lastPeakLoc = -refractoryPeriod;

    for (int i = 1; i < integrated.length - 1; i++) {
      // Check if local max
      if (integrated[i] > integrated[i - 1] &&
          integrated[i] > integrated[i + 1]) {
        if (integrated[i] > threshold) {
          if (i - lastPeakLoc > refractoryPeriod) {
            // Initial candidate found in integrated signal
            // Now find the *actual* R-peak in the raw signal nearby
            // (usually slightly before the integration wave)
            // Look back ~ windowSize
            int searchStart = (i - windowSize).clamp(0, data.length);
            int searchEnd = i;

            // Find max in raw data (bandpassed or even raw is usually fine if baseline isn't crazy)
            // Using raw data for simplicity as we don't have a clean bandpass filter here
            // Ideally we find max absolute value or max value.

            // Simple search for max value in raw 'data'
            int bestLoc = i;
            double maxRaw = -999999.0;

            for (int k = searchStart; k <= searchEnd; k++) {
              if (data[k] > maxRaw) {
                maxRaw = data[k];
                bestLoc = k;
              }
            }

            qrsIndices.add(bestLoc);
            lastPeakLoc = i;
          }
        }
      }
    }

    return qrsIndices;
  }

  // --- Helper Math Functions ---

  static double _mean(List<double> data) {
    if (data.isEmpty) return 0.0;
    return data.reduce((a, b) => a + b) / data.length;
  }

  static double _std(List<double> data, double meanVal) {
    if (data.length < 2) return 0.0;
    double sumSqDiff = 0.0;
    for (var x in data) {
      sumSqDiff += math.pow(x - meanVal, 2);
    }
    return math.sqrt(sumSqDiff / (data.length - 1));
  }

  static double _rms(List<double> data) {
    if (data.isEmpty) return 0.0;
    double sumSq = 0.0;
    for (var x in data) {
      sumSq += x * x;
    }
    return math.sqrt(sumSq / data.length);
  }

  static double _ptp(List<double> data) {
    if (data.isEmpty) return 0.0;
    double minVal = data.reduce(math.min);
    double maxVal = data.reduce(math.max);
    return maxVal - minVal;
  }

  static double _diffRms(List<double> data) {
    if (data.length < 2) return 0.0;
    List<double> diffs = [];
    for (int i = 0; i < data.length - 1; i++) {
      diffs.add(data[i + 1] - data[i]);
    }
    return _rms(diffs);
  }

  static double _zcr(List<double> data, double meanVal) {
    if (data.length < 2) return 0.0;
    int crossings = 0;
    for (int i = 0; i < data.length - 1; i++) {
      double c1 = data[i] - meanVal;
      double c2 = data[i + 1] - meanVal;
      if (c1 * c2 < 0) {
        crossings++;
      }
    }
    return crossings / (data.length - 1);
  }

  static double _kurtosis(List<double> data, double meanVal, double stdVal) {
    if (stdVal == 0 || data.isEmpty) return 0.0;
    double sumPow4 = 0.0;
    for (var x in data) {
      sumPow4 += math.pow((x - meanVal) / stdVal, 4);
    }
    return sumPow4 / data.length;
  }

  static double _skewness(List<double> data, double meanVal, double stdVal) {
    if (stdVal == 0 || data.isEmpty) return 0.0;
    double sumPow3 = 0.0;
    for (var x in data) {
      sumPow3 += math.pow((x - meanVal) / stdVal, 3);
    }
    return sumPow3 / data.length;
  }

  static int _nextPowerOf2(int n) {
    int count = 0;
    if (n > 0 && (n & (n - 1)) == 0) return n;
    while (n != 0) {
      n >>= 1;
      count += 1;
    }
    return 1 << count;
  }

  // Placeholder for proper FFT implementation or use a package like 'scidart'
  // For now, we simulate PSD with naive method or skip frequency features if critical
  static List<double> _computePSD(List<double> data, int fs) {
    // This is a placeholder as full FFT in Dart without package is verbose
    // We will return dummy PSD or simple transform
    return List.filled(data.length, 0.0);
  }

  static double _bandPowerRatio(
    List<double> psd,
    double freqRes,
    double low,
    double high,
  ) {
    // Placeholder
    return 0.0;
  }

  static double _spectralEntropy(List<double> psd) {
    // Placeholder
    return 0.0;
  }

  static double _autocorrPeak(List<double> data, int fs) {
    // Placeholder
    return 0.0;
  }
}
