import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/reading.dart';
import '../services/queue_logic.dart' show trendWindow;
import '../theme/app_theme.dart';

/// Systolic pressure over the last fourteen days with the home target band
/// behind the series (thesis ch.4 §Trends and what the patient sees). The
/// same chart is shown to the patient and, for the same window, to the
/// clinician (§Clinician dashboard: "show the same window as the patient's
/// application"). Rendered from local data, so it stays when offline.
class TrendChart extends StatefulWidget {
  final List<Reading> readings;

  /// The patient's version explains the band and the routine below it.
  final bool explain;

  const TrendChart({super.key, required this.readings, this.explain = true});

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  /// Readings carrying a BP value in the fourteen-day window shown to the
  /// patient (ch.4 §Trends), oldest first.
  List<Reading> get _bpHistory {
    final start = _windowStart;
    return widget.readings
        .where((r) => r.hasBP && r.timestamp.isAfter(start))
        .toList()
        .reversed
        .toList();
  }

  DateTime get _windowStart => DateTime.now().subtract(trendWindow);

  /// x = days since the start of the window, so gaps between readings show.
  List<FlSpot> get bpTrendData => [
        for (final r in _bpHistory)
          FlSpot(r.timestamp.difference(_windowStart).inMinutes / (60 * 24),
              r.sbp!.toDouble()),
      ];

  String _dayLabel(double x) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = _windowStart.add(Duration(days: x.round()));
    return '${d.day} ${months[d.month - 1]}';
  }

  /// Green systolic range of the home triage (HomeProtocol): from 110 to
  /// below 135 mmHg; below 110 is red, like the high side.
  static const double _homeTargetSbp = 135;
  static const double _homeLowSbp = 110;

  /// Chart bounds follow the data rather than being fixed, so a reading
  /// outside a preset range is not clipped off the chart.
  double get _minY {
    if (_bpHistory.isEmpty) return 100;
    final lowest = _bpHistory
        .map((r) => r.sbp!)
        .reduce((a, b) => a < b ? a : b);
    return (lowest - 15).clamp(40, _homeLowSbp - 10).toDouble();
  }

  double get _maxY {
    if (_bpHistory.isEmpty) return 170;
    final highest = _bpHistory
        .map((r) => r.sbp!)
        .reduce((a, b) => a > b ? a : b);
    return (highest + 15).clamp(_homeTargetSbp + 10, 320).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Systolic trend — last 14 days',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // the green band of the chart: an objective, not an alarm
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successBg(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Home target < 135/85',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.successText(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (bpTrendData.isEmpty)
            SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'No blood pressure reading in the last 14 days',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 10,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.border(context),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 20,
                        // round values only, not the chart's own bounds
                        getTitlesWidget: (value, meta) => value % 20 != 0
                            ? const SizedBox.shrink()
                            : Text(
                                value.toInt().toString(),
                                style: TextStyle(fontSize: 9, color: AppColors.textMuted(context)),
                              ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 7,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _dayLabel(value),
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textMuted(context),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  // Target band behind the series: the patient sees their
                  // position relative to the home target.
                  rangeAnnotations: RangeAnnotations(
                    horizontalRangeAnnotations: [
                      HorizontalRangeAnnotation(
                        y1: _homeLowSbp,
                        y2: _homeTargetSbp,
                        color: AppColors.successBg(context),
                      ),
                    ],
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: bpTrendData,
                      isCurved: false,
                      color: AppColors.primaryText(context),
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius: 3,
                              color: AppColors.card(context),
                              strokeWidth: 2,
                              strokeColor: AppColors.primaryText(context),
                            ),
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  minX: 0,
                  maxX: trendWindow.inDays.toDouble(),
                  minY: _minY,
                  maxY: _maxY,
                ),
              ),
            ),
          // what the band means and the routine behind it (thesis ch.4, Table
          // "Behaviour change techniques": explanation of the target band, a
          // fixed measurement schedule)
          if (widget.explain) ...[
            const SizedBox(height: 12),
            Text(
              'Green band: your home target for the upper number, from 110 to 134 mmHg (with the lower '
              'number below 85). Keeping your blood pressure there lowers the risk of stroke and heart '
              'disease.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              'Usual routine: blood pressure twice a week, morning and evening, two readings each time; '
              'glucose once a week, fasting and 90 minutes after lunch. Measure more often when the app '
              'asks for a check.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

}
