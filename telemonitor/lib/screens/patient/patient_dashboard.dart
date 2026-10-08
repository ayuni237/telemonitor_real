import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'log_reading_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'chat_screen.dart';
import '../../models/reading.dart';
import '../../services/auth_service.dart';
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

  /// Threshold-based banner. This is deliberately NOT the ML model — it
  /// reacts to the single most recent reading, whereas the risk card
  /// below reasons over the last seven. Both are shown because they
  /// answer different questions: "is this reading alarming right now?"
  /// versus "where is this patient trending?"
  bool get _hasAlert {
    final r = _latest;
    if (r == null) return false;
    return r.bpStatus == 'critical' ||
        r.bpStatus == 'stage2' ||
        r.glucoseStatus == 'critical' ||
        r.glucoseStatus == 'high';
  }

  String get _alertMessage {
    final r = _latest;
    if (r == null) return '';
    if (r.bpStatus == 'critical') {
      return 'Blood pressure critical — seek care immediately';
    }
    if (r.bpStatus == 'stage2') {
      return 'Blood pressure elevated — clinician notified';
    }
    if (r.glucoseStatus == 'critical') {
      return 'Blood glucose critical — seek care immediately';
    }
    if (r.glucoseStatus == 'high') {
      return 'Blood glucose elevated — monitor closely';
    }
    return '';
  }

  /// Up to the last seven readings carrying a BP value, oldest first.
  List<Reading> get _bpHistory {
    final withBp = _readings.where((r) => r.hasBP).take(7).toList();
    return withBp.reversed.toList();
  }

  List<FlSpot> get bpTrendData => List.generate(
    _bpHistory.length,
    (i) => FlSpot(i.toDouble(), _bpHistory[i].sbp!.toDouble()),
  );

  /// Axis labels. Uses the date rather than the weekday name, because
  /// several readings logged on the same day would otherwise render as
  /// a row of identical labels.
  List<String> get dayLabels {
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
    return _bpHistory
        .map((r) => '${r.timestamp.day} ${months[r.timestamp.month - 1]}')
        .toList();
  }

  /// Chart bounds follow the data rather than being fixed, so a reading
  /// outside a preset range is not clipped off the chart.
  double get _minY {
    if (_bpHistory.isEmpty) return 110;
    final lowest = _bpHistory
        .map((r) => r.sbp!)
        .reduce((a, b) => a < b ? a : b);
    return (lowest - 15).clamp(40, 300).toDouble();
  }

  double get _maxY {
    if (_bpHistory.isEmpty) return 170;
    final highest = _bpHistory
        .map((r) => r.sbp!)
        .reduce((a, b) => a > b ? a : b);
    return (highest + 15).clamp(60, 320).toDouble();
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

                  // The model's assessment over the last seven readings.
                  RiskCard(readings: _readings),
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
    final bpAlert = r?.bpStatus == 'critical' || r?.bpStatus == 'stage2';
    final glucoseAlert =
        r?.glucoseStatus == 'critical' || r?.glucoseStatus == 'high';

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
                'BP Trend — Last 7 readings',
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
                  'Target < 130',
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
                  'Log a blood pressure reading to start seeing your trend',
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
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= dayLabels.length) {
                            return const SizedBox();
                          }
                          // With few points every label fits; with many,
                          // showing every other one keeps them legible.
                          if (dayLabels.length > 5 && index.isOdd) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              dayLabels[index],
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
                  lineBarsData: [
                    LineChartBarData(
                      spots: bpTrendData,
                      isCurved: true,
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

    final isHigh =
        reading.bpStatus == 'critical' || reading.bpStatus == 'stage2';
    final isWarn =
        reading.bpStatus == 'stage1' || reading.bpStatus == 'elevated';

    if (isHigh) {
      badgeBg = AppColors.dangerBg(context);
      badgeFg = AppColors.dangerText(context);
      badgeLabel = 'High BP';
    } else if (isWarn) {
      badgeBg = AppColors.warningBg(context);
      badgeFg = AppColors.warningText(context);
      badgeLabel = 'Elevated';
    } else {
      badgeBg = AppColors.successBg(context);
      badgeFg = AppColors.successText(context);
      badgeLabel = 'Normal';
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
