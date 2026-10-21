import '../models/reading.dart';
import '../models/risk_assessment.dart';
import 'clinical_levels.dart';
import 'risk_api_client.dart';

/// Turns a patient's readings into a risk assessment — thesis ch.3
/// §Thresholds and the three levels.
///
/// Two engines:
///  * offline, always available: the guideline rule applied to the last value
///    of each channel within four days (the persistence baseline of the
///    thesis), mapped to a tier;
///  * online, when RISK_API_URL is set: the model selected by the benchmark,
///    served by the research backend.
/// The final tier is the worst of the two: the model may raise the rule's
/// tier, never lower it. Without connection the rule alone is shown, and the
/// card says so.
class RiskAssessmentService {
  RiskAssessmentService._internal({RiskApiClient? client}) : _api = client ?? RiskApiClient();
  static final RiskAssessmentService instance = RiskAssessmentService._internal();

  /// For tests.
  factory RiskAssessmentService.withClient(RiskApiClient client) =>
      RiskAssessmentService._internal(client: client);

  final RiskApiClient _api;

  /// Window of the rule floor and of the readings sent online (hours) — the
  /// longest window of the benchmark (configs/benchmark.yaml).
  static const Duration window = Duration(hours: 96);

  /// Rule level -> tier (configs/serve.yaml, rule_floor).
  static RiskTier tierOfLevel(int? level) => switch (level) {
        3 => RiskTier.red,
        2 => RiskTier.yellow,
        _ => RiskTier.green,
      };

  /// Readings of the last four days, oldest first.
  static List<Reading> recent(List<Reading> readings) {
    if (readings.isEmpty) return const [];
    final sorted = [...readings]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final cutoff = sorted.last.timestamp.subtract(window);
    return sorted.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }

  /// Guideline level of the last value of each channel within the window.
  static int? ruleLevel(List<Reading> readings) {
    num? sbp, dbp, hr, glucose;
    // last value of each channel, as the service does (serve/app.py)
    for (final r in recent(readings)) {
      sbp = r.sbp ?? sbp;
      dbp = r.dbp ?? dbp;
      hr = r.hr ?? hr;
      glucose = r.glucose ?? glucose;
    }
    return ClinicalLevels.overall(sbp: sbp, dbp: dbp, hr: hr, glucoseMmol: glucose);
  }

  Future<RiskAssessment> assess(List<Reading> readings, {int? age, String? sex}) async {
    final level = ruleLevel(readings);
    final ruleTier = tierOfLevel(level);
    final offline = RiskAssessment(
      tier: ruleTier,
      source: RiskSource.rule,
      ruleLevel: level,
      ruleTier: ruleTier,
      offlineReason: _api.isConfigured ? null : 'risk service not configured',
    );
    if (!_api.isConfigured || readings.isEmpty) return offline;
    try {
      final online = await _api.assess(recent(readings), age: age, sex: sex);
      return RiskAssessment(
        tier: worstTier(ruleTier, online.tier),
        source: RiskSource.online,
        ruleLevel: level,
        ruleTier: ruleTier,
        conditions: online.conditions,
        provisionalThresholds: online.provisionalThresholds,
        stateChange: online.stateChange,
        stateChangeMeasure: online.stateChangeMeasure,
      );
    } catch (e) {
      return RiskAssessment(
        tier: ruleTier,
        source: RiskSource.rule,
        ruleLevel: level,
        ruleTier: ruleTier,
        offlineReason: e is RiskApiException ? e.message : 'risk service unreachable',
      );
    }
  }
}
