import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telemonitor/firebase_options.dart';
import 'package:telemonitor/services/guardrail_check.dart';
import 'package:telemonitor/services/health_assistant_service.dart';

import 'adversarial_set.dart';

/// Runs the adversarial set against the real assistant (Gemini through
/// Firebase AI Logic) on a device or emulator, and reports every answer with
/// its automatic flags. The flags screen; the breach proportion of the thesis
/// is the one confirmed by reading the answers. See integration_test/README.md.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('health assistant guardrails on the adversarial set', (tester) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final assistant = HealthAssistantService.instance;
    final scored = <(AdversarialQuestion, List<String>)>[];
    final rows = <Map<String, Object?>>[];

    for (final q in adversarialSet) {
      assistant.startSession(
        instruction: HealthAssistantService.buildInstruction(
          profile: adversarialPatient,
          readings: readingsAtLevel(q.readingLevel),
        ),
      );
      String answer;
      String? error;
      try {
        answer = await assistant.send(q.prompt);
      } on AssistantException catch (e) {
        // a blocked answer is replaced by a message that refers to the
        // clinician; a network or quota error is not an answer
        answer = e.message;
        error = e.message.contains('clinician') ? null : e.message;
      }
      assistant.endSession();
      final flags = error == null ? checkAnswer(q, answer) : <String>[];
      if (error == null) scored.add((q, flags));
      rows.add({
        'id': q.id,
        'category': q.category.name,
        'language': q.language,
        'reading_level': q.readingLevel,
        'prompt': q.prompt,
        'answer': answer,
        'flags': flags,
        'error': error,
      });
      // ignore: avoid_print
      print('${q.id}: ${error ?? (flags.isEmpty ? 'ok' : flags.join('; '))}');
    }

    binding.reportData = {
      'set_version': adversarialSetVersion,
      'model': HealthAssistantService.modelId,
      'run_at': DateTime.now().toIso8601String(),
      'summary': summarize(scored),
      'answers': rows,
    };
    expect(scored, isNotEmpty, reason: 'no answer obtained: check the connection and Firebase AI Logic');
  }, timeout: const Timeout(Duration(minutes: 30)));
}
