import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/clinical_levels.dart';
import '../../models/reading.dart';
import '../../services/readings_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/level_style.dart';

/// Manual entry of a reading (thesis ch.4 §Manual entry): fixed glucose
/// unit, plausible ranges, coherent pressure pair, measurement context, the
/// two blood pressure readings of the protocol (the second is retained), and
/// the time the reading was taken when it is entered later.
///
/// With [correcting], the screen records a correction: a new reading that
/// supersedes the old one, which stays in the record (append-only).
class LogReadingScreen extends StatefulWidget {
  final Reading? correcting;
  const LogReadingScreen({super.key, this.correcting});

  @override
  State<LogReadingScreen> createState() => _LogReadingScreenState();
}

class _LogReadingScreenState extends State<LogReadingScreen> {
  // Retained reading (the second of the protocol pair, or the only one).
  final _sbpController = TextEditingController();
  final _dbpController = TextEditingController();
  final _glucoseController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _notesController = TextEditingController();

  // First reading of the protocol pair, kept for audit only.
  final _sbp1Controller = TextEditingController();
  final _dbp1Controller = TextEditingController();
  final _hr1Controller = TextEditingController();

  String _selectedMeasurementType = 'Both';
  String _selectedContext = 'Fasting';
  bool _isLoading = false;

  /// Protocol: two readings one minute apart, the second retained.
  bool _twoReadings = true;

  /// When the reading was taken; null means now (set at save).
  DateTime? _measuredAt;

  /// How far back a reading may be dated (the server accepts 30 days, to
  /// leave room for readings queued offline).
  static const Duration _maxBackdate = Duration(days: 7);

  bool get _isCorrection => widget.correcting != null;

  @override
  void initState() {
    super.initState();
    final r = widget.correcting;
    if (r == null) return;
    _measuredAt = r.timestamp;
    _selectedMeasurementType =
        r.hasBP && r.hasGlucose ? 'Both' : (r.hasBP ? 'Blood Pressure' : 'Glucose');
    if (_contextOptions.contains(r.context)) _selectedContext = r.context;
    _sbpController.text = r.sbp?.toString() ?? '';
    _dbpController.text = r.dbp?.toString() ?? '';
    _heartRateController.text = r.hr?.toString() ?? '';
    _glucoseController.text = r.glucose?.toString() ?? '';
    _notesController.text = r.notes;
    _twoReadings = r.readingCount == 2;
    _sbp1Controller.text = r.firstSbp?.toString() ?? '';
    _dbp1Controller.text = r.firstDbp?.toString() ?? '';
    _hr1Controller.text = r.firstHr?.toString() ?? '';
  }

  static const _measurementTypes = ['Both', 'Blood Pressure', 'Glucose'];
  static const _contextOptions = [
    'Fasting',
    'After meal',
    'After medication',
    'After exercise',
    'Random',
  ];

  // ---------------------------------------------------------------
  // Physiologically plausible input ranges.
  //
  // Deliberately WIDE — not clinical thresholds, and not a judgement of
  // whether a reading is healthy. Their only job is to catch data-entry
  // mistakes (a slipped digit, 50 typed for 150) before they reach
  // Firestore and, later, the model. A genuinely alarming but real value
  // must still get through.
  // ---------------------------------------------------------------
  static const int _sbpMin = 60, _sbpMax = 260;
  static const int _dbpMin = 30, _dbpMax = 160;
  static const double _glucoseMin = 1.0, _glucoseMax = 35.0;
  static const int _hrMin = 30, _hrMax = 220;

  /// Minimum systolic–diastolic gap. A reading like 120/118 is not
  /// physiologically meaningful and is almost always a typo.
  static const int _minPulsePressure = 10;

  @override
  void dispose() {
    _sbpController.dispose();
    _dbpController.dispose();
    _glucoseController.dispose();
    _heartRateController.dispose();
    _notesController.dispose();
    _sbp1Controller.dispose();
    _dbp1Controller.dispose();
    _hr1Controller.dispose();
    super.dispose();
  }

  bool get _needsBP => _selectedMeasurementType != 'Glucose';
  bool get _needsGlucose => _selectedMeasurementType != 'Blood Pressure';

  /// Returns a human-readable problem with the input, or null if
  /// everything is plausible. Checked before any write.
  String? _bpError(TextEditingController sbpC, TextEditingController dbpC,
      TextEditingController hrC, String which) {
    final sbp = int.tryParse(sbpC.text);
    final dbp = int.tryParse(dbpC.text);

    if (sbp == null || dbp == null) {
      return 'Please enter valid blood pressure values$which.';
    }
    if (sbp < _sbpMin || sbp > _sbpMax) {
      return 'Systolic $sbp$which is outside the plausible range '
          '($_sbpMin–$_sbpMax mmHg). Please re-check the reading.';
    }
    if (dbp < _dbpMin || dbp > _dbpMax) {
      return 'Diastolic $dbp$which is outside the plausible range '
          '($_dbpMin–$_dbpMax mmHg). Please re-check the reading.';
    }
    if (sbp - dbp < _minPulsePressure) {
      return 'Systolic ($sbp) should be at least $_minPulsePressure '
          'higher than diastolic ($dbp)$which. Please re-check the reading.';
    }

    // Heart rate is optional — validated only when something is typed.
    final hrText = hrC.text.trim();
    if (hrText.isNotEmpty) {
      final hr = int.tryParse(hrText);
      if (hr == null) return 'Please enter a valid heart rate$which.';
      if (hr < _hrMin || hr > _hrMax) {
        return 'Heart rate $hr$which is outside the plausible range '
            '($_hrMin–$_hrMax bpm). Please re-check the reading.';
      }
    }
    return null;
  }

  String? _validationError() {
    final at = _measuredAt;
    if (at != null) {
      final now = DateTime.now();
      if (at.isAfter(now.add(const Duration(minutes: 1)))) {
        return 'The time of the reading cannot be in the future.';
      }
      if (now.difference(at) > _maxBackdate && !_isCorrection) {
        return 'A reading can be dated at most ${_maxBackdate.inDays} days back.';
      }
    }

    if (_needsBP) {
      if (_twoReadings) {
        final first =
            _bpError(_sbp1Controller, _dbp1Controller, _hr1Controller, ' (reading 1)');
        if (first != null) return first;
      }
      final kept = _bpError(_sbpController, _dbpController, _heartRateController,
          _twoReadings ? ' (reading 2)' : '');
      if (kept != null) return kept;
    }

    if (_needsGlucose) {
      final bg = double.tryParse(_glucoseController.text);
      if (bg == null) return 'Please enter a valid glucose value.';
      if (bg < _glucoseMin || bg > _glucoseMax) {
        return 'Glucose $bg is outside the plausible range '
            '($_glucoseMin–$_glucoseMax mmol/L). Check your units — this '
            'app uses mmol/L, not mg/dL.';
      }
    }

    return null;
  }

  // ---------------------------------------------------------------
  // Live interpretation
  // ---------------------------------------------------------------

  (String, Color, Color) _levelStyle(int? level) {
    final st = LevelStyle.of(context, level);
    return (st.label, st.fg, st.bg);
  }

  Widget _buildLivePreview() {
    final sbpText = _sbpController.text;
    final dbpText = _dbpController.text;
    final bgText = _glucoseController.text;

    final hasBP = _needsBP && sbpText.isNotEmpty && dbpText.isNotEmpty;
    final hasBG = _needsGlucose && bgText.isNotEmpty;

    if (!hasBP && !hasBG) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live interpretation',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText(context),
            ),
          ),
          const SizedBox(height: 10),
          if (hasBP)
            _previewRow(
              'BP: $sbpText/$dbpText mmHg',
              _levelStyle(ClinicalLevels.haemodynamic(
                sbp: int.tryParse(sbpText),
                dbp: int.tryParse(dbpText),
                hr: int.tryParse(_heartRateController.text.trim()),
              )),
            ),
          if (hasBP && hasBG) const SizedBox(height: 8),
          if (hasBG)
            _previewRow(
              'Glucose: $bgText mmol/L',
              _levelStyle(ClinicalLevels.glycaemic(double.tryParse(bgText))),
            ),
        ],
      ),
    );
  }

  Widget _previewRow(String text, (String, Color, Color) style) {
    final (label, fg, bg) = style;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText(context),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------

  Future<void> _saveReading() async {
    final problem = _validationError();
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(problem),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final sbp = int.tryParse(_sbpController.text);
    final dbp = int.tryParse(_dbpController.text);
    final bg = double.tryParse(_glucoseController.text);
    final hr = int.tryParse(_heartRateController.text);
    final pair = _needsBP && _twoReadings;

    setState(() => _isLoading = true);

    try {
      await ReadingsRepository.instance.addReading(
        Reading(
          timestamp: _measuredAt ?? DateTime.now(),
          sbp: _needsBP ? sbp : null,
          dbp: _needsBP ? dbp : null,
          glucose: _needsGlucose ? bg : null,
          hr: _needsBP ? hr : null,
          context: _selectedContext,
          notes: _notesController.text.trim(),
          readingCount: pair ? 2 : 1,
          firstSbp: pair ? int.tryParse(_sbp1Controller.text) : null,
          firstDbp: pair ? int.tryParse(_dbp1Controller.text) : null,
          firstHr: pair ? int.tryParse(_hr1Controller.text) : null,
          supersedes: widget.correcting?.id,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Reading saved successfully'),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  // ---------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          _isCorrection ? 'Correct a Reading' : 'Log a Reading',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEntryHint(),
            const SizedBox(height: 20),

            _sectionLabel('Measurement type'),
            const SizedBox(height: 8),
            _buildSegmentedControl(),
            const SizedBox(height: 20),

            _sectionLabel('When was it taken?'),
            const SizedBox(height: 8),
            _buildTimePicker(),
            const SizedBox(height: 20),

            if (_needsBP) ...[
              _buildProtocolSwitch(),
              const SizedBox(height: 12),
              if (_twoReadings) ...[
                _bpInputs('Reading 1', _sbp1Controller, _dbp1Controller, _hr1Controller),
                const SizedBox(height: 16),
              ],
              _bpInputs(_twoReadings ? 'Reading 2 — kept' : 'Blood Pressure (mmHg)',
                  _sbpController, _dbpController, _heartRateController),
              const SizedBox(height: 6),
              Text(
                'Pressures in mmHg; pulse in beats per minute, optional.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted(context)),
              ),
              const SizedBox(height: 20),
            ],

            if (_needsGlucose) ...[
              _sectionLabel('Blood Glucose (mmol/L)'),
              const SizedBox(height: 8),
              _inputField(
                controller: _glucoseController,
                hint: 'e.g. 6.1',
                label: 'Glucose',
                isDecimal: true,
                maxLength: 5,
              ),
              const SizedBox(height: 20),
            ],

            _sectionLabel('Measurement context'),
            const SizedBox(height: 8),
            _buildContextDropdown(),
            const SizedBox(height: 20),

            _buildLivePreview(),

            _sectionLabel('Notes (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textPrimary(context)),
              decoration: _decoration(
                hint: 'e.g. Taken after morning medication...',
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveReading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isCorrection ? 'Save Correction' : 'Save Reading',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Replaces the old simulated "sensor connected" card.
  ///
  /// That card filled in fixed demonstration values (142/88, HR 76) when
  /// tapped, and once saved those were indistinguishable in Firestore from
  /// genuine measurements — which would contaminate exactly the data the
  /// model and the thesis depend on. Until a real Bluetooth integration
  /// exists, entry is manual and the screen says so.
  Widget _buildEntryHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tint(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_note_outlined,
              color: AppColors.primaryText(context), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCorrection ? 'Correct this reading' : 'Enter your reading',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isCorrection
                      ? 'Your corrected values replace the old ones on your '
                          'screens. The old entry stays in your record, marked '
                          'as corrected, so your clinician can see both.'
                      : 'Type the values shown on your blood pressure monitor or '
                          'glucometer. For blood pressure, sit and rest for five '
                          'minutes, then take two readings one minute apart: '
                          'the second is the one kept.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initial = _measuredAt ?? now;
    final earliest = now.subtract(_maxBackdate);
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      // a correction keeps the original time, which may be older
      firstDate: initial.isBefore(earliest) ? initial : earliest,
      lastDate: now,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    setState(() =>
        _measuredAt = DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  Widget _buildTimePicker() {
    final at = _measuredAt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: AppColors.textSecondary(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              at == null ? 'Now' : _formatTime(at),
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
            ),
          ),
          if (at != null && !_isCorrection)
            TextButton(
                onPressed: () => setState(() => _measuredAt = null),
                child: const Text('Now')),
          TextButton(onPressed: _pickTime, child: const Text('Earlier…')),
        ],
      ),
    );
  }

  Widget _buildProtocolSwitch() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Two blood pressure readings'),
              Text(
                'One minute apart; the second is kept.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
              ),
            ],
          ),
        ),
        Switch(
            value: _twoReadings, onChanged: (v) => setState(() => _twoReadings = v)),
      ],
    );
  }

  Widget _bpInputs(String title, TextEditingController sbpC,
      TextEditingController dbpC, TextEditingController hrC) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(title),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _inputField(
                  controller: sbpC, hint: 'e.g. 128', label: 'Systolic', maxLength: 3),
            ),
            const SizedBox(width: 8),
            Text(
              '/',
              style: TextStyle(
                fontSize: 24,
                color: AppColors.primaryText(context),
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _inputField(
                  controller: dbpC, hint: 'e.g. 82', label: 'Diastolic', maxLength: 3),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 76,
              child: _inputField(
                  controller: hrC, hint: 'e.g. 72', label: 'Pulse', maxLength: 3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Row(
        children: _measurementTypes.map((type) {
          final isSelected = _selectedMeasurementType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMeasurementType = type),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  type,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary(context),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryText(context),
      ),
    );
  }

  InputDecoration _decoration({String? hint, String? label}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textMuted(context), fontSize: 13),
      labelText: label,
      labelStyle:
          TextStyle(color: AppColors.primaryText(context), fontSize: 12),
      counterText: '',
      filled: true,
      fillColor: AppColors.card(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border(context), width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border(context), width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: AppColors.primaryText(context), width: 1),
      ),
      contentPadding: const EdgeInsets.all(14),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required String label,
    bool isDecimal = false,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      // Blocks non-numeric characters and caps the digit count, so an
      // absurd entry cannot even be typed. The range check in
      // _validationError() still runs.
      inputFormatters: [
        if (isDecimal)
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
        else
          FilteringTextInputFormatter.digitsOnly,
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      onChanged: (_) => setState(() {}),
      // Explicit text colour — without it the field inherits the theme
      // default and renders light-on-light in dark mode.
      style: TextStyle(fontSize: 15, color: AppColors.textPrimary(context)),
      decoration: _decoration(hint: hint, label: label),
    );
  }

  Widget _buildContextDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedContext,
          isExpanded: true,
          dropdownColor: AppColors.card(context),
          // from the theme's text style, so the font matches the other fields
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AppColors.textPrimary(context), fontSize: 14),
          iconEnabledColor: AppColors.textSecondary(context),
          items: _contextOptions
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (val) =>
              setState(() => _selectedContext = val ?? 'Fasting'),
        ),
      ),
    );
  }
}
