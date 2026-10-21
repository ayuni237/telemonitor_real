/// Tiers of the decision layer — thesis ch.3 §Thresholds and the three levels.
enum RiskTier { green, yellow, red }

extension RiskTierParsing on String {
  RiskTier toRiskTier() => switch (this) {
        'red' => RiskTier.red,
        'yellow' => RiskTier.yellow,
        _ => RiskTier.green,
      };
}

RiskTier worstTier(RiskTier a, RiskTier b) => a.index >= b.index ? a : b;

/// Where the assessment came from.
enum RiskSource {
  /// Guideline rule on the last readings, computed on the phone.
  rule,

  /// Risk model of the online service, combined with the rule.
  online,
}

/// One condition scored by the online model.
class ConditionRisk {
  final String model;
  final List<double> probabilities; // stable, moderate, high, critical
  final double alertProbability;     // P(high) + P(critical)
  final RiskTier tier;

  const ConditionRisk({
    required this.model,
    required this.probabilities,
    required this.alertProbability,
    required this.tier,
  });

  factory ConditionRisk.fromJson(Map<String, dynamic> j) => ConditionRisk(
        model: j['model'] as String,
        probabilities: (j['probabilities'] as List).map((x) => (x as num).toDouble()).toList(),
        alertProbability: (j['alert_probability'] as num).toDouble(),
        tier: (j['tier'] as String).toRiskTier(),
      );
}

/// The outcome of a risk assessment.
///
/// The final tier is never lower than the tier of the guideline rule: the
/// model may raise it, never lower it (thesis equation of the rule floor).
class RiskAssessment {
  final RiskTier tier;
  final RiskSource source;

  /// Level of the guideline rule on the last readings (0..3), null when
  /// nothing was measured in the last four days.
  final int? ruleLevel;
  final RiskTier ruleTier;

  /// Online model results per condition ("haemodynamic", "glycaemic").
  final Map<String, ConditionRisk> conditions;

  /// The decision cut-points are provisional until the partner physician
  /// states the costs of errors.
  final bool provisionalThresholds;

  /// Why the online model was not used, when it was not.
  final String? offlineReason;

  /// Distance between the current state and the patient's baseline, with the
  /// measure selected by the comparison benchmark (risk service, online only).
  final double? stateChange;
  final String? stateChangeMeasure;

  const RiskAssessment({
    required this.tier,
    required this.source,
    required this.ruleLevel,
    required this.ruleTier,
    this.conditions = const {},
    this.provisionalThresholds = true,
    this.offlineReason,
    this.stateChange,
    this.stateChangeMeasure,
  });

  bool get hasData => ruleLevel != null || conditions.isNotEmpty;
}
