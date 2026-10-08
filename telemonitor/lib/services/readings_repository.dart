import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/reading.dart';

/// Shared source of truth for a patient's readings — now backed by
/// Firestore instead of an in-memory list.
///
/// The public contract is deliberately unchanged from the in-memory
/// version: `readings`, `isEmpty`, `addReading()`, and
/// `lastNCompleteReadings()` behave the same, and the class is still a
/// ChangeNotifier. That is why PatientDashboard and HistoryScreen need
/// no modification for this step — they keep reading a synchronous
/// cached list, which this class now keeps in sync with Firestore.
///
/// Data lives at: users/{patientId}/readings/{readingId}
class ReadingsRepository extends ChangeNotifier {
  ReadingsRepository._internal();
  static final ReadingsRepository instance = ReadingsRepository._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  /// All readings for the bound patient, most recent first.
  List<Reading> get readings => List.unmodifiable(_cache);

  bool get isEmpty => _cache.isEmpty;

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

  /// Write a new reading for the bound patient.
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
    await _db
        .collection('users')
        .doc(id)
        .collection('readings')
        .add(reading.toFirestore());
  }

  /// The most recent [n] readings that have BOTH BP and glucose,
  /// oldest first — the shape SlidingWindowFeatures expects. Returns
  /// null when there isn't enough complete history yet.
  List<Reading>? lastNCompleteReadings(int n) {
    final complete = _cache.where((r) => r.hasBP && r.hasGlucose).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (complete.length < n) return null;
    return complete.sublist(complete.length - n);
  }
}
