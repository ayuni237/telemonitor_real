import 'package:flutter_test/flutter_test.dart';
import 'package:telemonitor/services/push_service.dart';

void main() {
  test('a message notification opens the conversation about its patient', () {
    final t = PushTarget.fromData({'open': 'messages', 'patientId': 'k3f9a2c7'});
    expect(t?.patientId, 'k3f9a2c7');
  });

  test('alerts and malformed data open nothing in particular', () {
    expect(PushTarget.fromData({}), isNull, reason: 'an alert carries no data');
    expect(PushTarget.fromData({'open': 'messages'}), isNull);
    expect(PushTarget.fromData({'open': 'messages', 'patientId': ''}), isNull);
    expect(PushTarget.fromData({'open': 'somewhere', 'patientId': 'x'}), isNull);
  });
}
