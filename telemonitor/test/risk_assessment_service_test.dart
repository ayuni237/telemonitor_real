import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:telemonitor/models/reading.dart';
import 'package:telemonitor/models/risk_assessment.dart';
import 'package:telemonitor/services/clinical_levels.dart';
import 'package:telemonitor/services/risk_api_client.dart';
import 'package:telemonitor/services/risk_assessment_service.dart';

final t0 = DateTime(2026, 7, 1, 8);

Reading at(int hours, {int? sbp, int? dbp, int? hr, double? glucose}) => Reading(
    timestamp: t0.add(Duration(hours: hours)), sbp: sbp, dbp: dbp, hr: hr, glucose: glucose);

RiskAssessmentService serviceWith(http.Client client, {String url = 'http://risk'}) =>
    RiskAssessmentService.withClient(RiskApiClient(client: client, baseUrl: url));

Map<String, dynamic> response({String tier = 'green', String version = ClinicalLevels.version}) => {
      'threshold_version': version,
      'thresholds_status': 'provisional',
      'rule': {'level': 0, 'tier': 'green'},
      'tier': tier,
      'conditions': {
        'haemodynamic': {
          'model': 'haemodynamic-catboost-abc',
          'probabilities': [0.5, 0.2, 0.2, 0.1],
          'alert_probability': 0.3,
          'tier': tier,
        }
      },
    };

void main() {
  test('rule floor uses the last value of each channel within four days', () {
    final readings = [
      at(0, glucose: 2.5),                 // older than 96 h before the last reading: ignored
      at(100, sbp: 120, dbp: 80, hr: 80),
      at(112, sbp: 125, dbp: 82),
    ];
    expect(RiskAssessmentService.ruleLevel(readings), 0);
    expect(RiskAssessmentService.ruleLevel([...readings, at(120, glucose: 2.9)]), 3);   // < 3.0 mmol/L
    expect(RiskAssessmentService.ruleLevel([at(0, sbp: 88, dbp: 60)]), 3);              // SBP <= 90
  });

  test('without a configured service the rule alone is used', () async {
    final s = serviceWith(MockClient((_) async => throw StateError('no call expected')), url: '');
    final a = await s.assess([at(0, sbp: 165, dbp: 95)]);
    expect(a.source, RiskSource.rule);
    expect(a.tier, RiskTier.yellow);                                                    // level 2 -> yellow
  });

  test('online model can raise the tier but never lower it', () async {
    final raise = serviceWith(MockClient((_) async => http.Response(jsonEncode(response(tier: 'red')), 200)));
    final a = await raise.assess([at(0, sbp: 120, dbp: 80)]);
    expect(a.source, RiskSource.online);
    expect(a.tier, RiskTier.red);
    expect(a.conditions['haemodynamic']!.alertProbability, 0.3);

    final lower = serviceWith(MockClient((_) async => http.Response(jsonEncode(response(tier: 'green')), 200)));
    final b = await lower.assess([at(0, sbp: 185, dbp: 100)]);
    expect(b.tier, RiskTier.red);                                                       // rule says critical
  });

  test('an unreachable service or a threshold mismatch falls back to the rule', () async {
    final down = serviceWith(MockClient((_) async => http.Response('error', 500)));
    expect((await down.assess([at(0, sbp: 120, dbp: 80)])).source, RiskSource.rule);
    final mismatch = serviceWith(
        MockClient((_) async => http.Response(jsonEncode(response(version: '1999-01-01')), 200)));
    final m = await mismatch.assess([at(0, sbp: 120, dbp: 80)]);
    expect(m.source, RiskSource.rule);
    expect(m.offlineReason, contains('thresholds'));
  });

  test('only the last four days are sent, with no identifier', () async {
    late Map<String, dynamic> sent;
    final s = serviceWith(MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(jsonEncode(response()), 200);
    }));
    await s.assess([at(0, sbp: 120, dbp: 80), at(200, sbp: 130, dbp: 85)], age: 60, sex: 'Female');
    expect((sent['readings'] as List).length, 1);
    expect(sent.keys.toSet(), {'readings', 'age', 'sex'});
    expect(sent['sex'], 'F');
  });
}
