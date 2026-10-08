/// Result of a TeleMonitor risk classification.
///
/// The four ordered levels match TeleMonitor_model.ipynb exactly:
/// 0 = stable, 1 = moderate, 2 = high, 3 = critical.
class RiskPrediction {
  static const List<String> levels = ['stable', 'moderate', 'high', 'critical'];

  final int levelIndex;

  /// [P(stable), P(moderate), P(high), P(critical)] — sums to ~1.0.
  final List<double> probabilities;

  const RiskPrediction(this.levelIndex, this.probabilities);

  String get levelName => levels[levelIndex];

  /// Thesis-defined risk score: R = P(high) + P(critical).
  double get riskScore => probabilities[2] + probabilities[3];

  /// Whether this reading should be flagged for clinician review
  /// (level >= high). Wire this to the alert engine / clinician dashboard sync.
  bool get needsClinicianAlert => levelIndex >= 2;

  @override
  String toString() =>
      'RiskPrediction(level: $levelName, score: ${riskScore.toStringAsFixed(3)}, '
      'probs: ${probabilities.map((p) => p.toStringAsFixed(3)).toList()})';
}
