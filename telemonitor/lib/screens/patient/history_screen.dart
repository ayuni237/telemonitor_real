import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/reading.dart';
import '../../services/home_protocol.dart';
import '../../services/readings_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/level_style.dart';
import 'log_reading_screen.dart';
import '../../l10n/l10n.dart';

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

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _filter = 'All';

  /// 'All', then the levels of the thesis label, most severe first.
  static final _filters = ['All', for (final l in _levels) HomeProtocol.name(l)];

  /// Levels of the home triage, most severe first.
  static const _levels = [HomeProtocol.red, HomeProtocol.yellow, HomeProtocol.green];

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

  /// Overall level of a reading; a reading without values counts as stable.
  int _levelOf(Reading r) => r.level ?? 0;

  List<Reading> get _filtered {
    if (_filter == 'All') return _all;
    final level = HomeProtocol.names.indexOf(_filter);
    return _all.where((r) => _levelOf(r) == level).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          context.l10n.readingHistory,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 2.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: [Tab(text: context.l10n.readingsTab), Tab(text: context.l10n.summaryTab)],
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
        context.l10n.noReadingsYet,
        context.l10n.historyEmptyNote,
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
                  context.l10n.noReadingsMatch,
                  context.l10n.noReadingsMatchNote,
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
                      // the filter values stay the stored level names; shown in the user's language
                      f == 'All' ? context.l10n.filterAll : context.l10n.homeLevel(HomeProtocol.names.indexOf(f)),
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
    if (diff == 0) return context.l10n.today;
    if (diff == 1) return context.l10n.yesterday;
    return DateFormat('d MMM').format(ts);
  }

  String _time(DateTime ts) =>
      '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

  Widget _readingCard(Reading r) {
    final style = LevelStyle.of(context, _levelOf(r));

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
              const Spacer(),
              style.badge(fontSize: 12),
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
                  color: LevelStyle.valueColor(
                      context, r.hasBP ? HomeProtocol.haemodynamic(sbp: r.sbp, dbp: r.dbp) : null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _valueBox(
                  Icons.water_drop_outlined,
                  r.hasGlucose ? '${r.glucose}' : '—',
                  'mmol/L',
                  color: LevelStyle.valueColor(context, r.glycaemicLevel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _valueBox(
                  r.hr == null && r.hrCamera != null ? Icons.photo_camera_outlined : Icons.monitor_heart_outlined,
                  r.hr != null ? '${r.hr}' : (r.hrCamera != null ? '${r.hrCamera}' : '—'),
                  'bpm',
                  color: LevelStyle.valueColor(context, HomeProtocol.pulse(r.hr)),
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
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    if (r.context.isNotEmpty) context.l10n.readingContextShort(r.context),
                    if (ReadingsRepository.instance.isPending(r)) context.l10n.tagPending,
                    if (r.readingCount == 2) context.l10n.tagSecondOfTwo,
                    if (r.hrCamera != null)
                      r.hr == null ? context.l10n.tagPulseCamera : context.l10n.tagPulseCameraValue(r.hrCamera!),
                    if (r.isCorrection) context.l10n.tagCorrected,
                    if (r.isBackdated) context.l10n.tagEnteredLater,
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted(context)),
                ),
              ),
              // Append-only record: no edit or delete, a correction is a new
              // reading that supersedes this one.
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LogReadingScreen(correcting: r)),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: Text(context.l10n.correct, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
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

  Widget _valueBox(IconData icon, String value, String unit, {required Color color}) {
    final fg = color;
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
                // scaled down rather than cut: a truncated 164/... hides the diastolic
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: fg,
                    ),
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textMuted(context)),
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
        context.l10n.nothingToSummarise,
        context.l10n.nothingToSummariseNote,
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

    final counts = {for (final l in _levels) l: _all.where((r) => _levelOf(r) == l).length};
    final total = _all.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                context.l10n.avgBloodPressure,
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
                context.l10n.avgGlucose,
                avgGlu == null ? '—' : avgGlu.toStringAsFixed(1),
                'mmol/L',
                Icons.water_drop_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _statCard(context.l10n.totalReadings, '$total',
            context.l10n.readingsLogged(total),
            Icons.format_list_numbered),
        const SizedBox(height: 16),
        _section(
          context.l10n.readingDistribution,
          Column(
            children: [
              for (final l in _levels) ...[
                _distributionBar(context.l10n.homeLevel(l), counts[l]!, total, LevelStyle.of(context, l).fg),
                if (l > HomeProtocol.green) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _section(context.l10n.insights, Column(children: _insights(counts, total))),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Plain-language observations drawn only from the patient's own data.
  /// Each one is conditional, so a patient with no high readings is not
  /// shown an alarming sentence with a zero in it.
  List<Widget> _insights(Map<int, int> counts, int total) {
    final out = <Widget>[];
    final alerts = counts[HomeProtocol.red]! + counts[HomeProtocol.yellow]!;
    final highShare = alerts / total;

    if (alerts > 0) {
      out.add(_insightRow(
        Icons.warning_amber_rounded,
        context.l10n.insightHighShare((highShare * 100).round()),
        AppColors.warningText(context),
      ));
    } else {
      out.add(_insightRow(
        Icons.check_circle_outline,
        context.l10n.insightAllInTarget,
        AppColors.successText(context),
      ));
    }

    final bothCount = _all.where((r) => r.hasBP && r.hasGlucose).length;
    if (bothCount < total) {
      out.add(const SizedBox(height: 10));
      out.add(_insightRow(
        Icons.tips_and_updates_outlined,
        context.l10n.insightLogBoth,
        AppColors.primaryText(context),
      ));
    }

    out.add(const SizedBox(height: 10));
    out.add(_insightRow(
      Icons.schedule,
      context.l10n.insightFourDays,
      AppColors.textSecondary(context),
    ));

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
