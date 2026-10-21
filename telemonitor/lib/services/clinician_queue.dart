import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/clinical_event.dart';
import '../models/reading.dart';
import 'events_service.dart';
import 'queue_logic.dart';

/// One row of the clinician's queue: an unreviewed event and what is needed
/// to triage it without opening the record (thesis ch.4, Table "Content of a
/// queue row").
class QueueItem {
  final ClinicalEvent event;
  final AppUser patient;
  final TrendDirection sbpTrend;
  final TrendDirection glucoseTrend;

  /// Last verdict on this patient; null when never reviewed.
  final DateTime? lastReviewedAt;

  /// Escalated to me as alternate: another clinician's patient, whose record
  /// I cannot open (only the event and its verdict).
  final bool isForeign;

  const QueueItem({
    required this.event,
    required this.patient,
    required this.sbpTrend,
    required this.glucoseTrend,
    this.lastReviewedAt,
    this.isForeign = false,
  });
}

/// Follows the events and the fourteen-day readings of every patient of the
/// clinician, and keeps the queue of open events in priority order. Runs the
/// non-transmission sweep at each update (EventsService).
class ClinicianQueue extends ChangeNotifier {
  ClinicianQueue(this._db);

  final FirebaseFirestore _db;
  final Map<String, AppUser> _patients = {};
  final Map<String, List<ClinicalEvent>> _events = {};
  final Map<String, List<Reading>> _readings = {};
  final List<StreamSubscription<dynamic>> _subs = [];
  List<ClinicalEvent> _escalated = const [];
  StreamSubscription<List<ClinicalEvent>>? _escalatedSub;
  String? _error;

  String? get error => _error;

  /// Open events, red before yellow, then oldest first.
  List<QueueItem> get items {
    final out = <QueueItem>[];
    for (final p in _patients.values) {
      final events = _events[p.uid] ?? const [];
      final readings = _readings[p.uid] ?? const [];
      final reviewed = events.where((e) => e.reviewedAt != null).map((e) => e.reviewedAt!);
      final lastReview = reviewed.isEmpty ? null : reviewed.reduce((a, b) => a.isAfter(b) ? a : b);
      for (final e in events.where((e) => e.isOpen)) {
        out.add(QueueItem(
          event: e,
          patient: p,
          sbpTrend: systolicTrend(readings),
          glucoseTrend: glucoseTrend(readings),
          lastReviewedAt: lastReview,
        ));
      }
    }
    for (final e in _escalated.where((e) => e.isOpen && !_patients.containsKey(e.patientId))) {
      out.add(QueueItem(
        event: e,
        patient: AppUser(uid: e.patientId, email: '', name: '', role: UserRole.patient),
        sbpTrend: TrendDirection.unknown,
        glucoseTrend: TrendDirection.unknown,
        isForeign: true,
      ));
    }
    out.sort((a, b) => compareQueue(a.event, b.event));
    return out;
  }

  /// Follow these patients (the roster); call again when it changes.
  void follow(List<AppUser> patients) {
    _escalatedSub ??= EventsService.instance.watchEscalatedToMe().listen((evs) {
      _escalated = evs;
      notifyListeners();
    }, onError: _onError);
    final ids = {for (final p in patients) p.uid};
    final same = ids.length == _patients.length && ids.every(_patients.containsKey);
    for (final p in patients) {
      _patients[p.uid] = p; // profile updates (checkup period) are kept
    }
    if (same) {
      _sweep();
      notifyListeners();
      return;
    }
    _cancel();
    _patients
      ..clear()
      ..addAll({for (final p in patients) p.uid: p});
    final since = Timestamp.fromDate(DateTime.now().subtract(trendWindow));
    for (final p in patients) {
      _subs.add(EventsService.instance.watch(p.uid).listen((evs) {
        _events[p.uid] = evs;
        notifyListeners();
      }, onError: _onError));
      // last reading in any case (for the sweep), plus the fourteen days
      _subs.add(_db
          .collection('users')
          .doc(p.uid)
          .collection('readings')
          .orderBy('timestamp', descending: true)
          .limit(60)
          .snapshots()
          .listen((s) {
        final all = Reading.effective(s.docs.map(Reading.fromFirestore));
        _readings[p.uid] =
            all.where((r) => !r.timestamp.isBefore(since.toDate())).toList();
        _lastReading[p.uid] = all.isEmpty ? null : all.first;
        _sweep();
        notifyListeners();
      }, onError: _onError));
    }
  }

  final Map<String, Reading?> _lastReading = {};

  /// Non-transmission sweep: one event per silence longer than the
  /// patient's checkup period.
  void _sweep() {
    for (final p in _patients.values) {
      final last = _lastReading[p.uid];
      final period = p.checkupPeriodDays ?? defaultCheckupPeriodDays;
      if (last == null || !isOverdue(lastReading: last.timestamp, checkupPeriodDays: period)) continue;
      final already = (_events[p.uid] ?? const []).any((e) => e.id == 'nontx_${last.id}');
      if (!already) EventsService.instance.raiseNonTransmission(p, last, period);
    }
  }

  void _onError(Object e) {
    _error = e.toString();
    notifyListeners();
  }

  void _cancel() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _events.clear();
    _readings.clear();
    _lastReading.clear();
  }

  @override
  void dispose() {
    _escalatedSub?.cancel();
    _cancel();
    super.dispose();
  }
}
