import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

/// Retrieves the enrolment code belonging to the signed-in clinician, so
/// they can read it off their own screen and give it to a patient
/// without having to ask the administrator.
///
/// Codes are created in the console (see the setup instructions); this
/// service only reads them. The query filters on `clinicianId`, matching
/// the `list` rule which restricts enumeration of this collection to
/// clinicians retrieving their own entry.
class ClinicianCodeService {
  ClinicianCodeService._internal();
  static final ClinicianCodeService instance =
      ClinicianCodeService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Live view of the signed-in clinician's code.
  ///
  /// Emits null when no code has been created for them yet — a state the
  /// UI reports explicitly rather than leaving blank, since a clinician
  /// with no code simply cannot enrol anyone and needs to know that.
  Stream<String?> watchMyCode() {
    final me = AuthService.instance.currentProfile;
    if (me == null) return Stream.value(null);

    return _db
        .collection('clinician_codes')
        .where('clinicianId', isEqualTo: me.uid)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : snap.docs.first.id);
  }
}
