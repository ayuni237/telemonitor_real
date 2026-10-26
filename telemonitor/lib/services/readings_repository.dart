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
  Set<String> _pending = {};
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

  /// Readings saved on the phone but not yet received by the server (offline
  /// queue, thesis ch.4 §Offline operation).
  int get pendingCount => _pending.length;
  bool isPending(Reading r) => r.id != null && _pending.contains(r.id);

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
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) {
        _cache = snapshot.docs.map(Reading.fromFirestore).toList();
        _pending = {for (final d in snapshot.docs) if (d.metadata.hasPendingWrites) d.id};
        _isLoading = false;
        _error = null;
        notifyListeners();
        EventsService.instance.raiseProfileEvents(Reading.effective(_cache));
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
    _pending = {};
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
  ///
  /// Returns at once: the write is in the local cache, and the server
  /// acknowledges it only when the phone is online, possibly days later
  /// (offline-first). A write the server refuses (security rules) is
  /// reported through [onRejected]. Returns the new reading's id.
  String addReading(Reading reading, {void Function(Object error)? onRejected}) {
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
    unawaited(batch.commit().catchError((Object e) => onRejected?.call(e)));
    return ref.id;
  }
}
