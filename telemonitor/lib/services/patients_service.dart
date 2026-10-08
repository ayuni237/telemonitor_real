import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import 'auth_service.dart';

/// Reads the roster of patients assigned to the signed-in clinician,
/// and looks up individual user profiles.
class PatientsService {
  PatientsService._internal();
  static final PatientsService instance = PatientsService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Patients assigned to the currently signed-in clinician.
  ///
  /// The query filters on assignedClinicianId only, not also on role.
  /// One equality filter needs no composite index, and only patients
  /// carry this field, so the extra clause would buy nothing.
  ///
  /// This filter must mirror the security rule: Firestore evaluates
  /// rules against the QUERY, not the results, so a broader query
  /// (e.g. all patients) is rejected outright rather than silently
  /// trimmed. Query and rule have to agree.
  Stream<List<AppUser>> watchMyPatients() {
    final me = AuthService.instance.currentProfile;
    if (me == null) return Stream.value(const []);

    return _db
        .collection('users')
        .where('assignedClinicianId', isEqualTo: me.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppUser.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// Most recent reading for a patient, for the at-a-glance status on
  /// the roster.
  Stream<QuerySnapshot> watchLatestReading(String patientId) {
    return _db
        .collection('users')
        .doc(patientId)
        .collection('readings')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }

  /// Fetches any single user profile by uid — used by the patient's
  /// chat screen to name their assigned clinician. Returns null if the
  /// document is missing or unreadable under the security rules.
  Future<AppUser?> fetchUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc.id, doc.data()!);
    } catch (_) {
      return null;
    }
  }
}
