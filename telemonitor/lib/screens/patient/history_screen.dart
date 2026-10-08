import 'package:flutter/material.dart';

import '../../models/reading.dart';
import '../../services/readings_repository.dart';
import '../../theme/app_theme.dart';

/// The patient's full reading history, with a filterable list and a
/// summary tab.
///
/// Every value on this screen comes from [ReadingsRepository] — the
/// signed-in patient's own Firestore data. An earlier version carried a
/// hardcoded list of demonstration readings, which meant every account,
/// including brand-new ones, was shown the same seven fabricated entries.
/// A new patient must see an empty history, not someone else's.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

/// The three buckets a reading can fall into for display and filtering.
enum _Band { high, elevated, normal }

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _filter = 'All';

  static const _filters = ['All', 'High BP', 'Elevated', 'Normal'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    ReadingsRepository.instance.addListener(_onReadingsChanged);
  }

  @override
  void dispose() {
    ReadingsRepository.instance.removeListener(_onReadingsChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onReadingsChanged() {
    if (mounted) setState(() {});
  }

  List<Reading> get _all => ReadingsRepository.instance.readings;

  /// Collapses the detailed BP and glucose statuses into three display
  /// bands, taking whichever of the two present values is more severe.
  _Band _bandOf(Reading r) {
    const severity = {
      'critical': 3, 'stage2': 3, 'high': 3,
      'stage1': 2, 'elevated': 2, 'low': 2,
      'normal': 1,
    };
    final statuses = [r.bpStatus, r.glucoseStatus].whereType<String>();
    if (statuses.isEmpty) return _Band.normal;
    final worst = statuses
        .map((s) => severity[s] ?? 1)
        .reduce((a, b) => a > b ? a : b);
    if (worst >= 3) return _Band.high;
    if (worst == 2) return _Band.elevated;
    return _Band.normal;
  }

  List<Reading> get _filtered {
    switch (_filter) {
      case 'High BP':
        return _all.where((r) => _bandOf(r) == _Band.high).toList();
      case 'Elevated':
        return _all.where((r) => _bandOf(r) == _Band.elevated).toList();
      case 'Normal':
        return _all.where((r) => _bandOf(r) == _Band.normal).toList();
      default:
        return _all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text(
          'Reading History',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 2.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Readings'), Tab(text: 'Summary')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_readingsTab(), _summaryTab()],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Readings tab
  // ---------------------------------------------------------------

  Widget _readingsTab() {
    if (_all.isEmpty) {
      return _emptyState(
        Icons.history_outlined,
        'No readings yet',
        'Your readings will appear here once you log your first one. '
            'Tap the + button on the home screen to start.',
      );
    }

    final items = _filtered;

    return Column(
      children: [
        _filterBar(),
        Expanded(
          child: items.isEmpty
              ? _emptyState(
                  Icons.filter_alt_off_outlined,
                  'No readings match this filter',
                  'Try another filter to see the rest of your history.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _readingCard(items[i]),
                ),
        ),
      ],
    );
  }

  Widget _filterBar() {
    return Container(
      color: AppColors.background(context),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((f) {
            final selected = _filter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: selected ? AppColors.primary : AppColors.card(context),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _filter = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border(context),
                      ),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _dateLabel(DateTime ts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(ts.year, ts.month, ts.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${ts.day} ${months[ts.month - 1]}';
  }

  String _time(DateTime ts) =>
      '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

  (String, Color, Color) _bandStyle(_Band b) {
    switch (b) {
      case _Band.high:
        return ('High BP', AppColors.dangerText(context),
            AppColors.dangerBg(context));
      case _Band.elevated:
        return ('Elevated', AppColors.warningText(context),
            AppColors.warningBg(context));
      case _Band.normal:
        return ('Normal', AppColors.successText(context),
            AppColors.successBg(context));
    }
  }

  Widget _readingCard(Reading r) {
    final band = _bandOf(r);
    final (label, fg, bg) = _bandStyle(band);
    final bpAlert = r.bpStatus == 'critical' || r.bpStatus == 'stage2';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chip('${_dateLabel(r.timestamp)} · ${_time(r.timestamp)}',
                  AppColors.primaryText(context), AppColors.tint(context),
                  bold: true),
              if (r.context.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: _chip(r.context, AppColors.textSecondary(context),
                      AppColors.field(context)),
                ),
              ],
              const Spacer(),
              _chip(label, fg, bg, bold: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _valueBox(
                  Icons.favorite_outline,
                  r.hasBP ? '${r.sbp}/${r.dbp}' : '—',
                  'mmHg',
                  alert: bpAlert,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _valueBox(
                  Icons.water_drop_outlined,
                  r.hasGlucose ? '${r.glucose}' : '—',
                  'mmol/L',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _valueBox(
                  Icons.monitor_heart_outlined,
                  r.hr != null ? '${r.hr}' : '—',
                  'bpm',
                ),
              ),
            ],
          ),
          if (r.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes, size: 14, color: AppColors.textMuted(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.notes,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text, Color fg, Color bg, {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }

  Widget _valueBox(IconData icon, String value, String unit,
      {bool alert = false}) {
    final fg =
        alert ? AppColors.dangerText(context) : AppColors.primaryText(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.field(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: fg,
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textMuted(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Summary tab
  // ---------------------------------------------------------------

  Widget _summaryTab() {
    if (_all.isEmpty) {
      return _emptyState(
        Icons.insights_outlined,
        'Nothing to summarise yet',
        'Once you have logged a few readings, your averages and patterns '
            'will appear here.',
      );
    }

    final bpReadings = _all.where((r) => r.hasBP).toList();
    final glucoseReadings = _all.where((r) => r.hasGlucose).toList();

    final avgSbp = bpReadings.isEmpty
        ? null
        : bpReadings.map((r) => r.sbp!).reduce((a, b) => a + b) /
            bpReadings.length;
    final avgDbp = bpReadings.isEmpty
        ? null
        : bpReadings.map((r) => r.dbp!).reduce((a, b) => a + b) /
            bpReadings.length;
    final avgGlu = glucoseReadings.isEmpty
        ? null
        : glucoseReadings.map((r) => r.glucose!).reduce((a, b) => a + b) /
            glucoseReadings.length;

    final counts = {
      _Band.high: _all.where((r) => _bandOf(r) == _Band.high).length,
      _Band.elevated: _all.where((r) => _bandOf(r) == _Band.elevated).length,
      _Band.normal: _all.where((r) => _bandOf(r) == _Band.normal).length,
    };
    final total = _all.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Avg blood pressure',
                avgSbp == null
                    ? '—'
                    : '${avgSbp.round()}/${avgDbp!.round()}',
                'mmHg',
                Icons.favorite_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Avg glucose',
                avgGlu == null ? '—' : avgGlu.toStringAsFixed(1),
                'mmol/L',
                Icons.water_drop_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _statCard('Total readings', '$total',
            total == 1 ? 'reading logged' : 'readings logged',
            Icons.format_list_numbered),
        const SizedBox(height: 16),
        _section(
          'Reading distribution',
          Column(
            children: [
              _distributionBar('High BP', counts[_Band.high]!, total,
                  AppColors.dangerText(context)),
              const SizedBox(height: 12),
              _distributionBar('Elevated', counts[_Band.elevated]!, total,
                  AppColors.warningText(context)),
              const SizedBox(height: 12),
              _distributionBar('Normal', counts[_Band.normal]!, total,
                  AppColors.successText(context)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _section('Insights', Column(children: _insights(counts, total))),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Plain-language observations drawn only from the patient's own data.
  /// Each one is conditional, so a patient with no high readings is not
  /// shown an alarming sentence with a zero in it.
  List<Widget> _insights(Map<_Band, int> counts, int total) {
    final out = <Widget>[];
    final highShare = counts[_Band.high]! / total;

    if (counts[_Band.high]! > 0) {
      out.add(_insightRow(
        Icons.warning_amber_rounded,
        '${(highShare * 100).round()}% of your readings were in the high '
        'range.',
        AppColors.dangerText(context),
      ));
    } else {
      out.add(_insightRow(
        Icons.check_circle_outline,
        'None of your readings so far have been in the high range.',
        AppColors.successText(context),
      ));
    }

    final bothCount = _all.where((r) => r.hasBP && r.hasGlucose).length;
    if (bothCount < total) {
      out.add(const SizedBox(height: 10));
      out.add(_insightRow(
        Icons.tips_and_updates_outlined,
        'Logging blood pressure and glucose together gives your risk '
        'score the most to work with.',
        AppColors.primaryText(context),
      ));
    }

    if (total < 7) {
      out.add(const SizedBox(height: 10));
      out.add(_insightRow(
        Icons.hourglass_empty,
        '${7 - total} more reading${7 - total == 1 ? '' : 's'} needed '
        'before a risk score can be calculated.',
        AppColors.textSecondary(context),
      ));
    }

    return out;
  }

  Widget _insightRow(IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary(context),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary(context)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText(context),
            ),
          ),
          Text(
            unit,
            style:
                TextStyle(fontSize: 11, color: AppColors.textMuted(context)),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
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
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText(context),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _distributionBar(String label, int count, int total, Color color) {
    final share = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary(context))),
            Text(
              '$count  ·  ${(share * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 8,
            backgroundColor: AppColors.field(context),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted(context)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(context),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
