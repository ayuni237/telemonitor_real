import '../models/reading.dart';
import '../models/risk_assessment.dart';
import 'home_protocol.dart';
import 'risk_api_client.dart';

/// Turns a patient's readings into a risk assessment — thesis ch.3
/// §Thresholds and the three levels, ch.4 §triage.
///
/// Two engines:
///  * offline, always available: the home triage (HomeProtocol, the
///    out-of-office thresholds of a home deployment) applied to the last value
///    of each channel within four days, and the outcome of a verification
///    profile (off target: red);
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

  /// Home level -> tier, one to one (green, yellow, red).
  static RiskTier tierOfLevel(int? level) => switch (level) {
        HomeProtocol.red => RiskTier.red,
        HomeProtocol.yellow => RiskTier.yellow,
        _ => RiskTier.green,
      };

  /// Readings of the last four days, oldest first.
  static List<Reading> recent(List<Reading> readings) {
    if (readings.isEmpty) return const [];
    final sorted = [...readings]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final cutoff = sorted.last.timestamp.subtract(window);
    return sorted.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }

  /// Home level of the last value of each channel within the window; a
  /// glucose is judged in the context it was measured in.
  static int? ruleLevel(List<Reading> readings) {
    num? sbp, dbp, hr, glucose;
    var context = '';
    // last value of each channel, as the service does (serve/app.py)
    for (final r in recent(readings)) {
      sbp = r.sbp ?? sbp;
      dbp = r.dbp ?? dbp;
      hr = r.hr ?? hr;
      if (r.glucose != null) {
        glucose = r.glucose;
        context = r.context;
      }
    }
    return HomeProtocol.level(sbp: sbp, dbp: dbp, hr: hr, glucoseMmol: glucose, context: context);
  }

  /// Red when a verification profile finished in the last week is off target
  /// (Table "tab:thresholds": teleconsultation).
  static RiskTier profileTier(List<ProfileResult> profiles) =>
      profiles.any((p) => p.status == ProfileStatus.complete && p.offTarget == true) ? RiskTier.red : RiskTier.green;

  Future<RiskAssessment> assess(List<Reading> readings, {int? age, String? sex, DateTime? now}) async {
    final level = ruleLevel(readings);
    final profiles = VerificationProfile.active(readings, now ?? DateTime.now());
    final ruleTier = worstTier(tierOfLevel(level), profileTier(profiles));
    final offline = RiskAssessment(
      tier: ruleTier,
      source: RiskSource.rule,
      ruleLevel: level,
      ruleTier: ruleTier,
      profiles: profiles,
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
        profiles: profiles,
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
        profiles: profiles,
        offlineReason: e is RiskApiException ? e.message : 'risk service unreachable',
      );
    }
  }
}
