enum UserRole { patient, clinician }

extension UserRoleParsing on String {
  UserRole toUserRole() {
    switch (this) {
      case 'clinician':
        return UserRole.clinician;
      case 'patient':
      default:
        return UserRole.patient;
    }
  }
}

/// A logged-in person's app profile — stored in Firestore at
/// users/{uid}, separate from the Firebase Auth record itself.
///
/// The clinical fields below (age, sex, conditions, medications...) are
/// all optional and default to empty. A profile created with only
/// email/name/role stays perfectly valid — the UI shows "not recorded"
/// rather than blank rows, so a sparse profile reads as incomplete
/// rather than as a patient with no conditions.
class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;

  /// For a patient: the uid of the clinician responsible for them.
  final String? assignedClinicianId;

  // --- Clinical profile (patients) -------------------------------
  final int? age;
  final String? sex;
  final String? phone;
  final String? height;
  final String? weight;
  final String? bloodType;
  final List<String> conditions;
  final List<String> medications;
  final String? emergencyContact;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.assignedClinicianId,
    this.age,
    this.sex,
    this.phone,
    this.height,
    this.weight,
    this.bloodType,
    this.conditions = const [],
    this.medications = const [],
    this.emergencyContact,
  });

  /// A patient with no assigned clinician appears on nobody's roster
  /// and their messages reach nobody. Treat this as a provisioning
  /// error to surface, not a state to tolerate silently.
  bool get isAssigned =>
      assignedClinicianId != null && assignedClinicianId!.isNotEmpty;

  /// Convenience for display — falls back to the email when no name
  /// has been recorded.
  String get displayName => name.isEmpty ? email : name;

  /// Whether any clinical detail at all has been recorded. Used to show
  /// a single honest "no clinical information recorded" state instead
  /// of a card full of dashes.
  bool get hasClinicalInfo =>
      age != null ||
      (sex != null && sex!.isNotEmpty) ||
      (phone != null && phone!.isNotEmpty) ||
      (height != null && height!.isNotEmpty) ||
      (weight != null && weight!.isNotEmpty) ||
      (bloodType != null && bloodType!.isNotEmpty) ||
      conditions.isNotEmpty ||
      medications.isNotEmpty ||
      (emergencyContact != null && emergencyContact!.isNotEmpty);

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<String> _list(dynamic v) {
    if (v is List) {
      return v
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    // Tolerates a comma-separated string, since that's an easy thing to
    // type by hand in the Firestore console.
    if (v is String && v.trim().isNotEmpty) {
      return v
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      role: (data['role'] as String? ?? 'patient').toUserRole(),
      assignedClinicianId: _str(data['assignedClinicianId']),
      age: (data['age'] as num?)?.toInt(),
      sex: _str(data['sex']),
      phone: _str(data['phone']),
      height: _str(data['height']),
      weight: _str(data['weight']),
      bloodType: _str(data['bloodType']),
      conditions: _list(data['conditions']),
      medications: _list(data['medications']),
      emergencyContact: _str(data['emergencyContact']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'name': name,
        'role': role.name, // stored as plain 'patient' or 'clinician'
        if (assignedClinicianId != null)
          'assignedClinicianId': assignedClinicianId,
        if (age != null) 'age': age,
        if (sex != null) 'sex': sex,
        if (phone != null) 'phone': phone,
        if (height != null) 'height': height,
        if (weight != null) 'weight': weight,
        if (bloodType != null) 'bloodType': bloodType,
        if (conditions.isNotEmpty) 'conditions': conditions,
        if (medications.isNotEmpty) 'medications': medications,
        if (emergencyContact != null) 'emergencyContact': emergencyContact,
      };
}
