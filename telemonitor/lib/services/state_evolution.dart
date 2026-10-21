import '../models/reading.dart';

/// Evolution of each vital sign — thesis ch.3 §Tracking the evolution of the
/// patient's state. The current state is the mean of each channel over the
/// last 24 h before the latest reading; the baseline, its mean over the three
/// days before (24 to 96 h). Same windows as telemonitor-research
/// state.evolution, which adds, online, one distance chosen by its benchmark.
class ChannelChange {
  final String channel;
  final double current;
  final double baseline;

  const ChannelChange(this.channel, this.current, this.baseline);

  double get change => current - baseline;
}

class StateEvolution {
  StateEvolution._();

  static const Duration current = Duration(hours: 24);
  static const Duration baselineEnd = Duration(hours: 96);

  static const channels = ['sbp', 'dbp', 'hr', 'glucose'];
  static const names = {'sbp': 'Systolic', 'dbp': 'Diastolic', 'hr': 'Pulse', 'glucose': 'Glucose'};
  static const units = {'sbp': 'mmHg', 'dbp': 'mmHg', 'hr': 'bpm', 'glucose': 'mmol/L'};

  /// Display resolution: a smaller change is shown as stable.
  static const resolution = {'sbp': 1.0, 'dbp': 1.0, 'hr': 1.0, 'glucose': 0.1};

  static double? _value(Reading r, String c) => switch (c) {
        'sbp' => r.sbp?.toDouble(),
        'dbp' => r.dbp?.toDouble(),
        'hr' => r.hr?.toDouble(),
        _ => r.glucose,
      };

  /// Channels measured in both windows; empty when there is no baseline.
  static List<ChannelChange> of(List<Reading> readings) {
    final rs = Reading.effective(readings);
    if (rs.isEmpty) return const [];
    final last = rs.map((r) => r.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
    bool inCurrent(DateTime t) => t.isAfter(last.subtract(current)) && !t.isAfter(last);
    bool inBaseline(DateTime t) =>
        t.isAfter(last.subtract(baselineEnd)) && !t.isAfter(last.subtract(current));
    double? mean(Iterable<double> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
    final out = <ChannelChange>[];
    for (final c in channels) {
      final cur = mean([for (final r in rs) if (inCurrent(r.timestamp) && _value(r, c) != null) _value(r, c)!]);
      final base = mean([for (final r in rs) if (inBaseline(r.timestamp) && _value(r, c) != null) _value(r, c)!]);
      if (cur != null && base != null) out.add(ChannelChange(c, cur, base));
    }
    return out;
  }
}
