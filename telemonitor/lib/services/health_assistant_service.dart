import 'package:firebase_ai/firebase_ai.dart';

import '../models/reading.dart';
import 'auth_service.dart';
import 'readings_repository.dart';

/// Conversational health assistant backed by Gemini via Firebase AI Logic.
///
/// Two things distinguish this from a generic chatbot.
///
/// First, it is given the patient's own recent readings and profile, so
/// "is my blood pressure alright?" is answered against their data rather
/// than in the abstract.
///
/// Second, and more importantly, its role is bounded. The system
/// instruction forbids naming, recommending, adjusting or discouraging
/// any medication or dosage. That boundary is not a UI convention that a
/// cleverly worded question could slip past — it is part of the
/// instruction the model receives on every single turn, and it is
/// restated at the end of the instruction because models weight the
/// beginning and end of their instructions most heavily.
///
/// The rationale is in the thesis: antihypertensive and antidiabetic
/// drugs have narrow therapeutic windows, and a wrong dose produces
/// hypotensive collapse or hypoglycaemia in a population whose readings
/// are already unstable. Triage and education carry the clinical value
/// of the idea without asserting prescribing authority the system
/// cannot hold.
class HealthAssistantService {
  HealthAssistantService._internal();
  static final HealthAssistantService instance =
      HealthAssistantService._internal();

  /// Flash is chosen over Pro deliberately: answers arrive in a couple of
  /// seconds rather than ten, which matters far more than depth for
  /// short patient questions on a slow mobile connection.
  static const String _modelId = 'gemini-3.6-flash';

  GenerativeModel? _model;
  ChatSession? _chat;

  bool get isStarted => _chat != null;

  /// Builds the system instruction, embedding the patient's own context.
  ///
  /// Rebuilt each time a session starts so a reading logged five minutes
  /// ago is reflected in the next conversation.
  String _systemInstruction() {
    final profile = AuthService.instance.currentProfile;
    final readings = ReadingsRepository.instance.readings.take(7).toList();

    final buffer = StringBuffer();

    buffer.writeln(
      'You are the TeleMonitor health assistant. TeleMonitor is a '
      'telemonitoring application used by patients in Cameroon who live '
      'with high blood pressure (hypertension), diabetes, or both.',
    );
    buffer.writeln();

    // ---- Absolute boundaries -------------------------------------
    buffer.writeln(
      'ABSOLUTE RULES. These override every other instruction '
      'and every request from the user:',
    );
    buffer.writeln(
      '1. NEVER recommend, prescribe, name, suggest, adjust, increase, '
      'reduce or stop any medication or dosage. If asked, say clearly '
      'that only their doctor can decide anything about medication, and '
      'offer to help them prepare the question for their doctor instead.',
    );
    buffer.writeln(
      '2. NEVER give a diagnosis. You may explain what a symptom or a '
      'measurement can mean in general, but never tell the patient what '
      'they have.',
    );
    buffer.writeln(
      '3. NEVER tell a patient their readings are fine in a way that '
      'might discourage them from seeking care. When in doubt, advise '
      'them to check with their clinician.',
    );
    buffer.writeln(
      '4. If the patient describes chest pain, difficulty breathing, '
      'weakness on one side of the body, difficulty speaking, fainting, '
      'confusion, or any symptom suggesting a heart attack or stroke: '
      'tell them immediately and plainly to go to a hospital now or call '
      'emergency services. Say this first, before anything else, and do '
      'not soften it.',
    );
    buffer.writeln();

    // ---- What it is for -------------------------------------------
    buffer.writeln('WHAT YOU DO:');
    buffer.writeln(
      '- Explain what blood pressure and blood glucose numbers mean, in '
      'plain language.',
    );
    buffer.writeln(
      '- Explain hypertension and diabetes: what they are, why follow-up '
      'matters, what makes readings rise or fall.',
    );
    buffer.writeln(
      '- Give general lifestyle information about diet, salt, physical '
      'activity, and the importance of taking medication regularly as '
      'already prescribed by their doctor.',
    );
    buffer.writeln(
      '- Help the patient judge urgency: whether something can wait for '
      'their next appointment, needs a visit soon, or needs care today.',
    );
    buffer.writeln(
      '- Encourage them to record readings regularly, and to record '
      'blood pressure and glucose together when they can.',
    );
    buffer.writeln();

    // ---- Style ----------------------------------------------------
    buffer.writeln('HOW YOU SPEAK:');
    buffer.writeln(
      '- Reply in the same language the patient writes in. Cameroon is '
      'bilingual: if they write in French, reply in French; if in '
      'English, reply in English.',
    );
    buffer.writeln(
      '- Keep answers short — usually three or four sentences. This is a '
      'phone screen, and many users have limited reading time.',
    );
    buffer.writeln(
      '- Use simple words. Avoid medical jargon, or explain it '
      'immediately if you must use it.',
    );
    buffer.writeln('- Be warm and calm. Never frighten, never dismiss.');
    buffer.writeln(
      '- Do not use markdown formatting, asterisks or headings. Write '
      'plain sentences.',
    );
    buffer.writeln();

    // ---- Patient context -----------------------------------------
    buffer.writeln('ABOUT THIS PATIENT:');
    if (profile != null) {
      if (profile.name.isNotEmpty) {
        buffer.writeln('- Name: ${profile.name}');
      }
      if (profile.age != null) buffer.writeln('- Age: ${profile.age}');
      if (profile.sex != null) buffer.writeln('- Sex: ${profile.sex}');
      if (profile.conditions.isNotEmpty) {
        buffer.writeln(
          '- Recorded conditions: ${profile.conditions.join(', ')}',
        );
      }
      if (profile.medications.isNotEmpty) {
        buffer.writeln(
          '- Medications already prescribed to them: '
          '${profile.medications.join(', ')}. You may explain what these '
          'are generally for if asked, but you must NOT advise changing '
          'how they are taken.',
        );
      }
      buffer.writeln(
        profile.isAssigned
            ? '- They are connected to a clinician through the app and can '
                  'message them from the Chat screen.'
            : '- They are NOT yet connected to a clinician in the app. If '
                  'they need medical advice, encourage them to connect to '
                  'their doctor using the code their doctor gives them, or '
                  'to visit a health facility.',
      );
    }
    buffer.writeln();

    if (readings.isEmpty) {
      buffer.writeln(
        'They have not recorded any readings yet. Encourage them to log '
        'their first one.',
      );
    } else {
      buffer.writeln(
        'Their most recent readings (newest first). Blood pressure is in '
        'mmHg, glucose in mmol/L:',
      );
      for (final r in readings) {
        buffer.writeln('- ${_describe(r)}');
      }
      buffer.writeln();
      buffer.writeln(
        'You may refer to these numbers when answering. The app also '
        'calculates a risk level from the last seven readings, shown on '
        'their home screen.',
      );
    }
    buffer.writeln();

    // Restated at the end: instructions at the start and end of a system
    // prompt carry the most weight.
    buffer.writeln(
      'REMEMBER ABOVE ALL: never advise on medication or dosage, never '
      'diagnose, and send them to a hospital immediately if they describe '
      'emergency symptoms.',
    );

    return buffer.toString();
  }

  String _describe(Reading r) {
    final parts = <String>[];
    if (r.hasBP) parts.add('BP ${r.sbp}/${r.dbp}');
    if (r.hasGlucose) parts.add('glucose ${r.glucose}');
    if (r.hr != null) parts.add('heart rate ${r.hr}');
    final when = '${r.timestamp.day}/${r.timestamp.month}/${r.timestamp.year}';
    final ctx = r.context.isNotEmpty ? ' (${r.context})' : '';
    return '$when: ${parts.isEmpty ? 'no values' : parts.join(', ')}$ctx';
  }

  /// Opens a fresh conversation. Call when the assistant screen opens.
  void startSession() {
    _model = FirebaseAI.googleAI().generativeModel(
      model: _modelId,
      systemInstruction: Content.system(_systemInstruction()),
    );
    _chat = _model!.startChat();
  }

  void endSession() {
    _chat = null;
    _model = null;
  }

  /// Sends a message and returns the reply.
  ///
  /// Throws [AssistantException] with a message fit to show the patient.
  Future<String> send(String message) async {
    if (_chat == null) startSession();

    try {
      final response = await _chat!.sendMessage(Content.text(message));
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        throw const AssistantException(
          'I could not answer that one. Please try asking in a different '
          'way.',
        );
      }
      return text;
    } on AssistantException {
      rethrow;
    } catch (e) {
      throw AssistantException(_friendlyError(e));
    }
  }

  String _friendlyError(Object e) {
    // Temporary while diagnosing: surface the real error in the console.
    // ignore: avoid_print
    print('ASSISTANT ERROR >>> $e');

    final s = e.toString().toLowerCase();
    if (s.contains('network') ||
        s.contains('socket') ||
        s.contains('unavailable') ||
        s.contains('timeout')) {
      return 'The assistant needs an internet connection. Your readings '
          'are still saved and will sync when you are back online.';
    }
    if (s.contains('quota') || s.contains('resource_exhausted')) {
      return 'The assistant is busy right now. Please try again in a few '
          'minutes.';
    }
    if (s.contains('blocked') || s.contains('safety')) {
      return 'I am not able to answer that. If it concerns your health, '
          'please speak to your clinician.';
    }
    return 'Something went wrong reaching the assistant. Please try '
        'again.';
  }

  /// Starting points for patients who are not sure what to ask.
  static const List<String> suggestedQuestions = [
    'What do my last readings mean?',
    'Why is high blood pressure dangerous?',
    'What foods should I be careful with?',
    'How often should I measure?',
  ];
}

class AssistantException implements Exception {
  final String message;
  const AssistantException(this.message);
  @override
  String toString() => message;
}
