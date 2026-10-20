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
              padding: const EdgeInsets.all(20),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LogReadingScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
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
                'Good morning,',
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

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dangerBorder(context), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.dangerText(context),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _alertMessage,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.dangerText(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards() {
    final r = _latest;
    final bpAlert = r?.isHaemodynamicAlert ?? false;
    final glucoseAlert = r?.isGlycaemicAlert ?? false;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _metricCard(
          label: 'Blood Pressure',
          value: (r?.hasBP ?? false) ? '${r!.sbp}/${r.dbp}' : '—',
          unit: 'mmHg',
          icon: Icons.favorite_outline,
          isAlert: bpAlert,
        ),
        _metricCard(
          label: 'Blood Glucose',
          value: (r?.hasGlucose ?? false) ? '${r!.glucose}' : '—',
          unit: 'mmol/L',
          icon: Icons.water_drop_outlined,
          isAlert: glucoseAlert,
        ),
        _metricCard(
          label: 'Heart Rate',
          value: r?.hr != null ? '${r!.hr}' : '—',
          unit: 'bpm',
          icon: Icons.monitor_heart_outlined,
          isAlert: false,
        ),
        _metricCard(
          // Nothing in the app collects SpO2, so it is shown as
          // unavailable rather than as a fabricated value.
          label: 'SpO2',
          value: '—',
          unit: '%',
          icon: Icons.air_outlined,
          isAlert: false,
        ),
      ],
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required bool isAlert,
  }) {
    final fg = isAlert
        ? AppColors.dangerText(context)
        : AppColors.primaryText(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAlert ? AppColors.dangerBg(context) : AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert
              ? AppColors.dangerBorder(context)
              : AppColors.border(context),
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isAlert
                      ? AppColors.dangerText(context)
                      : AppColors.textSecondary(context),
                  fontWeight: FontWeight.w500,
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
                style: TextStyle(
                  fontSize: 11,
                  color: isAlert
                      ? AppColors.dangerText(context)
                      : AppColors.textMuted(context),
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
              Text(
                'Systolic trend — last 14 days',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Home target < 135/85',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.dangerText(context),
                    fontWeight: FontWeight.w500,
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
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
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
                      color: const Color(0xFFE24B4A),
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius: 3,
                              color: AppColors.card(context),
                              strokeWidth: 2,
                              strokeColor: const Color(0xFFE24B4A),
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFFE24B4A).withValues(alpha: 0.08),
                      ),
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
    Color badgeBg;
    Color badgeFg;
    String badgeLabel;

    // Badge from the thesis label: worst condition level of the reading.
    final level = reading.level;
    badgeLabel = ClinicalLevels.name(level);
    if (level != null && level >= ClinicalLevels.alertLevel) {
      badgeBg = AppColors.dangerBg(context);
      badgeFg = AppColors.dangerText(context);
    } else if (level == 1) {
      badgeBg = AppColors.warningBg(context);
      badgeFg = AppColors.warningText(context);
    } else {
      badgeBg = AppColors.successBg(context);
      badgeFg = AppColors.successText(context);
    }

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeFg,
              ),
            ),
          ),
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
