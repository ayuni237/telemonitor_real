import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import 'auth_service.dart';

/// Reads and updates the signed-in user's own profile.
///
/// Only descriptive fields are writable. `role`, `assignedClinicianId`
/// and `email` are deliberately absent from [updateOwnProfile] — and
/// the security rules reject any update that touches them, so this is
/// enforced on the server, not merely omitted here. A client cannot
/// promote itself to clinician or reassign its own doctor.
class ProfileService {
  ProfileService._internal();
  static final ProfileService instance = ProfileService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Live view of the signed-in user's own profile document.
  Stream<AppUser?> watchOwnProfile() {
    final uid = AuthService.instance.currentFirebaseUser?.uid;
    if (uid == null) return Stream.value(null);

    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc.id, doc.data()!);
    });
  }

  /// Writes the editable subset of the profile.
  ///
  /// Empty values are stored as a field delete rather than an empty
  /// string, so "no weight recorded" and "weight recorded as blank"
  /// don't become two different states that render differently.
  Future<void> updateOwnProfile({
    required String name,
    int? age,
    String? sex,
    String? phone,
    String? height,
    String? weight,
    String? bloodType,
    List<String> conditions = const [],
    List<String> medications = const [],
    String? emergencyContact,
  }) async {
    final uid = AuthService.instance.currentFirebaseUser?.uid;
    if (uid == null) {
      throw StateError('Not signed in.');
    }

    String? clean(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final data = <String, dynamic>{
      'name': name.trim(),
      'age': age ?? FieldValue.delete(),
      'sex': clean(sex) ?? FieldValue.delete(),
      'phone': clean(phone) ?? FieldValue.delete(),
      'height': clean(height) ?? FieldValue.delete(),
      'weight': clean(weight) ?? FieldValue.delete(),
      'bloodType': clean(bloodType) ?? FieldValue.delete(),
      'conditions': conditions.isEmpty ? FieldValue.delete() : conditions,
      'medications': medications.isEmpty ? FieldValue.delete() : medications,
      'emergencyContact':
          clean(emergencyContact) ?? FieldValue.delete(),
    };

    // update() rather than set(): set() would replace the whole
    // document and silently drop role and assignedClinicianId — which
    // the rules would reject anyway, but failing loudly at the wrong
    // layer is worse than not attempting it.
    await _db.collection('users').doc(uid).update(data);

    // Keep the cached profile in step, since ChatService and the
    // roster query read from it.
    await AuthService.instance.fetchCurrentUserProfile();
  }
}
