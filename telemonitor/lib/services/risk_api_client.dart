import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/reading.dart';
import '../models/risk_assessment.dart';
import 'clinical_levels.dart';

/// Client of the online risk service (telemonitor-research, FastAPI,
/// POST /v1/risk). The service runs the research pipeline itself — quality
/// controls, features, the model chosen by the benchmark and the rule floor —
/// so the phone never re-implements the model.
///
/// The address is set at build time:
///   flutter run --dart-define=RISK_API_URL=http://10.0.2.2:8000
/// (10.0.2.2 is the host machine seen from the Android emulator). Without it,
/// the app uses the guideline rule only.
class RiskApiClient {
  RiskApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? const String.fromEnvironment('RISK_API_URL');

  final http.Client _client;
  final String baseUrl;

  static const Duration timeout = Duration(seconds: 6);

  bool get isConfigured => baseUrl.isNotEmpty;

  /// Readings are sent without any identifier: time and values only, plus
  /// age and sex, the two covariates of the model.
  Future<OnlineRisk> assess(List<Reading> readings, {int? age, String? sex}) async {
    final body = {
      'readings': [
        for (final r in readings)
          {
            'time': r.timestamp.toIso8601String(),
            'sbp': r.sbp,
            'dbp': r.dbp,
            'hr': r.hr,
            'glucose': r.glucose,
          }
      ],
      'age': age,
      'sex': _sexCode(sex),
    };
    final res = await _client
        .post(Uri.parse('$baseUrl/v1/risk'),
            headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(timeout);
    if (res.statusCode != 200) {
      throw RiskApiException('service answered ${res.statusCode}');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['threshold_version'] != ClinicalLevels.version) {
      throw RiskApiException(
          'service thresholds ${j['threshold_version']} differ from the app (${ClinicalLevels.version})');
    }
    final conds = (j['conditions'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, ConditionRisk.fromJson(v as Map<String, dynamic>)));
    return OnlineRisk(
      tier: (j['tier'] as String).toRiskTier(),
      conditions: conds,
      provisionalThresholds: j['thresholds_status'] == 'provisional',
    );
  }
}

/// Profile values ("Male", "Female", "Other") to the model's M / F; unknown otherwise.
String? _sexCode(String? sex) => switch (sex) {
      'M' || 'Male' => 'M',
      'F' || 'Female' => 'F',
      _ => null,
    };

class OnlineRisk {
  final RiskTier tier;
  final Map<String, ConditionRisk> conditions;
  final bool provisionalThresholds;

  const OnlineRisk({required this.tier, required this.conditions, required this.provisionalThresholds});
}

class RiskApiException implements Exception {
  final String message;
  RiskApiException(this.message);
  @override
  String toString() => message;
}
