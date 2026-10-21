import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'log_reading_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'chat_screen.dart';
import '../../services/clinical_levels.dart';
import '../../models/reading.dart';
import '../../services/auth_service.dart';
import '../../services/queue_logic.dart' show trendWindow;
import '../../services/readings_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/evolution_card.dart';
import '../../widgets/level_style.dart';
import '../../widgets/clinician_link_card.dart';
import '../../widgets/risk_card.dart';
import '../../widgets/find_care_card.dart';
import '../../widgets/assistant_card.dart';
import '../../widgets/assistant_bubble.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Rebuild whenever a reading is added anywhere in the app, so the
    // dashboard updates without needing to be reopened.
    ReadingsRepository.instance.addListener(_onReadingsChanged);
  }

  @override
  void dispose() {
    ReadingsRepository.instance.removeListener(_onReadingsChanged);
    super.dispose();
  }

  void _onReadingsChanged() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------
  // Derived state
  // ---------------------------------------------------------------

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning,' : (h < 18 ? 'Good afternoon,' : 'Good evening,');
  }

  String get _patientName =>
      AuthService.instance.currentProfile?.displayName ?? '';

  String get _initials {
    final parts = _patientName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  List<Reading> get _readings => ReadingsRepository.instance.readings;

  Reading? get _latest => _readings.isEmpty ? null : _readings.first;

  /// Threshold-based banner. This is deliberately NOT the model — it
  /// reacts to the single most recent reading, whereas the risk card
  /// below reasons over the last four days. Both are shown because they
  /// answer different questions: "is this reading alarming right now?"
  /// versus "where is this patient trending?"
  bool get _hasAlert {
    final r = _latest;
    if (r == null) return false;
    return r.isAlert;
  }

  String get _alertMessage {
    final r = _latest;
    if (r == null) return '';
    // Critical levels first, then high (thesis label, ClinicalLevels).
    if (r.haemodynamicLevel == 3) {
      return 'Blood pressure or pulse critical — seek care immediately';
    }
    if (r.glycaemicLevel == 3) {
      return 'Blood glucose critical — seek care immediately';
    }
    if (r.haemodynamicLevel == 2) {
      return 'Blood pressure high — contact your health centre';
    }
    if (r.glycaemicLevel == 2) {
      return 'Blood glucose out of range — monitor closely';
    }
    return '';
  }

  /// Readings carrying a BP value in the fourteen-day window shown to the
  /// patient (ch.4 §Trends), oldest first.
  List<Reading> get _bpHistory {
    final start = _windowStart;
    return _readings
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

  /// Home systolic target (ESH 2023 home threshold 135/85 mmHg).
  static const double _homeTargetSbp = 135;

  /// Chart bounds follow the data rather than being fixed, so a reading
  /// outside a preset range is not clipped off the chart.
  double get _minY {
    if (_bpHistory.isEmpty) return 110;
    final lowest = _bpHistory
        .map((r) => r.sbp!)
        .reduce((a, b) => a < b ? a : b);
    return (lowest - 15).clamp(40, _homeTargetSbp - 20).toDouble();
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
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  const ClinicianLinkCard(),
                  if (_hasAlert) _buildAlertBanner(),
                  if (_hasAlert) const SizedBox(height: 16),

                  // Risk tier: guideline rule on the last four days, raised by the online model.
                  RiskCard(
                    readings: _readings,
                    age: AuthService.instance.currentProfile?.age,
                    sex: AuthService.instance.currentProfile?.sex,
                    raiseEvents: true,
                  ),
                  const SizedBox(height: 20),
                  EvolutionCard(readings: _readings),
                  const SizedBox(height: 20),

                  _buildMetricCards(),
                  const SizedBox(height: 20),
                  _buildTrendChart(),
                  const SizedBox(height: 20),
                  _buildRecentReadings(),
                  const AssistantCard(),
                  const SizedBox(height: 20),
                  const FindCareCard(),
                ],
              ),
            ),
          ),
          const AssistantBubble(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(context),
                ),
              ),
              Text(
                _patientName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText(context),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              _initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Banner colour follows the level: critical in red, high in amber, the
  /// same colours as the risk tier the level maps to.
  Widget _buildAlertBanner() {
    final level = _latest?.level;
    final style = LevelStyle.of(context, level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.fg.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            level == 3 ? Icons.error_outline : Icons.warning_amber_rounded,
            color: style.fg,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _alertMessage,
              style: TextStyle(
                fontSize: 13,
                color: style.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Latest reading carrying a value of the channel, so a glucose-only entry
  /// does not blank the blood pressure card.
  Reading? _latestWith(bool Function(Reading) has) {
    for (final r in _readings) {
      if (has(r)) return r;
    }
    return null;
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes.clamp(0, 59)} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  Widget _buildMetricCards() {
    final bp = _latestWith((r) => r.hasBP);
    final glu = _latestWith((r) => r.hasGlucose);
    final hr = _latestWith((r) => r.hr != null);
    final last = _latest;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _metricCard(
          label: 'Blood pressure',
          value: bp == null ? '—' : '${bp.sbp}/${bp.dbp}',
          unit: bp == null ? 'mmHg' : 'mmHg · ${_ago(bp.timestamp)}',
          icon: Icons.favorite_outline,
          level: bp?.haemodynamicLevel,
        ),
        _metricCard(
          label: 'Blood glucose',
          value: glu == null ? '—' : '${glu.glucose}',
          unit: glu == null ? 'mmol/L' : 'mmol/L · ${_ago(glu.timestamp)}',
          icon: Icons.water_drop_outlined,
          level: glu?.glycaemicLevel,
        ),
        _metricCard(
          label: 'Pulse',
          value: hr == null ? '—' : '${hr.hr}',
          unit: hr == null ? 'bpm' : 'bpm · ${_ago(hr.timestamp)}',
          icon: Icons.monitor_heart_outlined,
          level: hr == null ? null : ClinicalLevels.pulse(hr.hr),
        ),
        _metricCard(
          label: 'Last reading',
          value: last == null
              ? '—'
              : '${last.timestamp.hour.toString().padLeft(2, '0')}:${last.timestamp.minute.toString().padLeft(2, '0')}',
          unit: last == null ? 'none yet' : _ago(last.timestamp),
          icon: Icons.schedule,
          level: null,
        ),
      ],
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required int? level,
  }) {
    final alert = (level ?? 0) >= ClinicalLevels.alertLevel;
    final style = LevelStyle.of(context, level);
    final fg = alert ? style.fg : AppColors.primaryText(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alert ? style.bg : AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert ? style.fg.withValues(alpha: 0.35) : AppColors.border(context),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: alert ? style.fg : AppColors.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(icon, size: 16, color: fg),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
              Text(
                unit,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: alert ? style.fg : AppColors.textMuted(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
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
                        y1: _minY,
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
        ],
      ),
    );
  }

  Widget _buildRecentReadings() {
    final recent = _readings.take(3).toList();

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
          Text(
            'Recent Readings',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText(context),
            ),
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Text(
              'No readings logged yet',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted(context),
              ),
            )
          else
            ...recent.map((r) => _readingRow(r)),
        ],
      ),
    );
  }

  String _rowDateTime(DateTime ts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(ts.year, ts.month, ts.day);
    final diff = today.difference(that).inDays;
    final time =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Today, $time';
    if (diff == 1) return 'Yesterday, $time';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${ts.day} ${months[ts.month - 1]}, $time';
  }

  Widget _readingRow(Reading reading) {
    // Badge from the thesis label: worst condition level of the reading.
    final style = LevelStyle.of(context, reading.level);

    final valueText = reading.hasBP && reading.hasGlucose
        ? '${reading.sbp}/${reading.dbp} · ${reading.glucose} mmol/L'
        : reading.hasBP
        ? '${reading.sbp}/${reading.dbp} mmHg'
        : reading.hasGlucose
        ? '${reading.glucose} mmol/L'
        : 'No values recorded';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valueText,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText(context),
                  ),
                ),
                Text(
                  _rowDateTime(reading.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          style.badge(),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    // Colours come from bottomNavigationBarTheme in AppTheme, so this
    // adapts without per-item styling here.
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) {
        if (i == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LogReadingScreen()),
          );
        } else if (i == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HistoryScreen()),
          );
        } else if (i == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        } else if (i == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
        } else {
          setState(() => _currentIndex = i);
        }
      },
      selectedFontSize: 11,
      unselectedFontSize: 11,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          activeIcon: Icon(Icons.add_circle),
          label: 'Log',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          activeIcon: Icon(Icons.history),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
