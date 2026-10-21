import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/reading.dart';
import 'auth_service.dart';
import 'events_service.dart';

/// Shared source of truth for a patient's readings — now backed by
/// Firestore instead of an in-memory list.
///
/// Screens read a synchronous cached list, which this class keeps in sync
/// with Firestore; it is a ChangeNotifier.
///
/// Data lives at: users/{patientId}/readings/{readingId}
class ReadingsRepository extends ChangeNotifier {
  ReadingsRepository._internal();
  static final ReadingsRepository instance = ReadingsRepository._internal();

  // resolved on use, so the service can be built where Firebase is not initialised (screen tests)
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  List<Reading> _cache = [];
  StreamSubscription<QuerySnapshot>? _sub;
  String? _patientId;
  bool _isLoading = false;
  String? _error;

  /// True while the first snapshot for the bound patient is still
  /// arriving. Screens can use this to distinguish "still loading" from
  /// "genuinely no readings yet" — without it, a new patient and a
  /// slow connection look identical.
  bool get isLoading => _isLoading;

  String? get error => _error;

  /// Which patient this repository is currently following, if any.
  String? get patientId => _patientId;

  /// The readings that stand for the bound patient (corrected ones hidden),
  /// most recent first.
  List<Reading> get readings => List.unmodifiable(Reading.effective(_cache));

  /// Every document, corrected ones included, for audit.
  List<Reading> get allReadings => List.unmodifiable(_cache);

  bool get isEmpty => _cache.isEmpty;

  /// Screen tests: show these readings without Firestore.
  @visibleForTesting
  void debugSetReadings(List<Reading> readings) {
    _cache = [...readings]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _isLoading = false;
    notifyListeners();
  }

  /// Point this repository at a patient and start following their
  /// readings live. Safe to call repeatedly with the same id — it only
  /// re-subscribes when the patient actually changes.
  void bindTo(String patientId) {
    if (_patientId == patientId && _sub != null) return;

    _sub?.cancel();
    _patientId = patientId;
    _cache = [];
    _isLoading = true;
    _error = null;
    notifyListeners();

    _sub = _db
        .collection('users')
        .doc(patientId)
        .collection('readings')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        _cache = snapshot.docs.map(Reading.fromFirestore).toList();
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        // Most commonly a permission-denied from security rules, or no
        // connectivity on a cold start with no cached data.
        _isLoading = false;
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  /// Stop following and clear the cache — call on sign-out so one
  /// patient's data never lingers into another account's session.
  Future<void> unbind() async {
    await _sub?.cancel();
    _sub = null;
    _patientId = null;
    _cache = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Write a new reading for the bound patient, and with it, in one
  /// batch, the rule event when its level reaches yellow or red.
  ///
  /// The record is append-only: to correct a reading, pass it as
  /// [reading.supersedes]; the old document stays, [readings] hides it.
  ///
  /// Note there is no local mutation of `_cache` here and no manual
  /// notifyListeners(): the snapshot listener above echoes the write
  /// back, including immediately from Firestore's local cache while
  /// offline. Adding it manually as well would double-insert.
  Future<void> addReading(Reading reading) async {
    final id = _patientId;
    if (id == null) {
      throw StateError(
        'ReadingsRepository.bindTo() must be called before addReading(). '
        'This normally happens automatically at sign-in.',
      );
    }
    final ref = _db.collection('users').doc(id).collection('readings').doc();
    final batch = _db.batch()..set(ref, reading.toFirestore());
    final event = EventsService.ruleEvent(
      patientId: id,
      clinicianId: AuthService.instance.currentProfile?.assignedClinicianId,
      readingId: ref.id,
      r: reading,
    );
    if (event != null) batch.set(EventsService.instance.events(id).doc(event.id), event.data);
    await batch.commit();
  }
}
