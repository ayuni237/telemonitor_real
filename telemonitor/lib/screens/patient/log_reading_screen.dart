import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/reading.dart';
import '../../services/readings_repository.dart';
import '../../theme/app_theme.dart';

class LogReadingScreen extends StatefulWidget {
  const LogReadingScreen({super.key});

  @override
  State<LogReadingScreen> createState() => _LogReadingScreenState();
}

class _LogReadingScreenState extends State<LogReadingScreen> {
  final _sbpController = TextEditingController();
  final _dbpController = TextEditingController();
  final _glucoseController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedMeasurementType = 'Both';
  String _selectedContext = 'Fasting';
  bool _isLoading = false;

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
    super.dispose();
  }

  bool get _needsBP => _selectedMeasurementType != 'Glucose';
  bool get _needsGlucose => _selectedMeasurementType != 'Blood Pressure';

  /// Returns a human-readable problem with the input, or null if
  /// everything is plausible. Checked before any write.
  String? _validationError() {
    if (_needsBP) {
      final sbp = int.tryParse(_sbpController.text);
      final dbp = int.tryParse(_dbpController.text);

      if (sbp == null || dbp == null) {
        return 'Please enter valid blood pressure values.';
      }
      if (sbp < _sbpMin || sbp > _sbpMax) {
        return 'Systolic $sbp is outside the plausible range '
            '($_sbpMin–$_sbpMax mmHg). Please re-check the reading.';
      }
      if (dbp < _dbpMin || dbp > _dbpMax) {
        return 'Diastolic $dbp is outside the plausible range '
            '($_dbpMin–$_dbpMax mmHg). Please re-check the reading.';
      }
      if (sbp - dbp < _minPulsePressure) {
        return 'Systolic ($sbp) should be at least $_minPulsePressure '
            'higher than diastolic ($dbp). Please re-check the reading.';
      }

      // Heart rate is optional — validated only when something is typed.
      final hrText = _heartRateController.text.trim();
      if (hrText.isNotEmpty) {
        final hr = int.tryParse(hrText);
        if (hr == null) return 'Please enter a valid heart rate.';
        if (hr < _hrMin || hr > _hrMax) {
          return 'Heart rate $hr is outside the plausible range '
              '($_hrMin–$_hrMax bpm). Please re-check the reading.';
        }
      }
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

  String _bpStatus(int sbp, int dbp) {
    if (sbp > 180 || dbp > 120) return 'critical';
    // Checked before the hypertension bands: without it, a low reading
    // such as 85/55 falls through to 'normal', which is misleading.
    if (sbp < 90 || dbp < 60) return 'low';
    if (sbp >= 140 || dbp >= 90) return 'stage2';
    if (sbp >= 130 || dbp >= 80) return 'stage1';
    if (sbp >= 120 && dbp < 80) return 'elevated';
    return 'normal';
  }

  String _glucoseStatus(double bg) {
    if (bg > 11.1) return 'critical';
    if (bg > 7.0) return 'high';
    if (bg < 3.9) return 'low';
    return 'normal';
  }

  /// Label, foreground and background for a status. Severe states use the
  /// danger palette; borderline states use warning; normal uses success.
  (String, Color, Color) _statusStyle(String status, {bool glucose = false}) {
    switch (status) {
      case 'critical':
        return (
          glucose ? 'Very High' : 'Hypertensive Crisis',
          AppColors.dangerText(context),
          AppColors.dangerBg(context)
        );
      case 'stage2':
        return ('Stage 2 Hypertension', AppColors.dangerText(context),
            AppColors.dangerBg(context));
      case 'high':
        return ('High', AppColors.dangerText(context),
            AppColors.dangerBg(context));
      case 'stage1':
        return ('Stage 1 Hypertension', AppColors.warningText(context),
            AppColors.warningBg(context));
      case 'elevated':
        return ('Elevated', AppColors.warningText(context),
            AppColors.warningBg(context));
      case 'low':
        return ('Low', AppColors.warningText(context),
            AppColors.warningBg(context));
      default:
        return ('Normal', AppColors.successText(context),
            AppColors.successBg(context));
    }
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
              _statusStyle(_bpStatus(
                int.tryParse(sbpText) ?? 0,
                int.tryParse(dbpText) ?? 0,
              )),
            ),
          if (hasBP && hasBG) const SizedBox(height: 8),
          if (hasBG)
            _previewRow(
              'Glucose: $bgText mmol/L',
              _statusStyle(
                _glucoseStatus(double.tryParse(bgText) ?? 0),
                glucose: true,
              ),
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

    setState(() => _isLoading = true);

    try {
      await ReadingsRepository.instance.addReading(
        Reading(
          timestamp: DateTime.now(),
          sbp: _needsBP ? sbp : null,
          dbp: _needsBP ? dbp : null,
          glucose: _needsGlucose ? bg : null,
          hr: _needsBP ? hr : null,
          context: _selectedContext,
          notes: _notesController.text.trim(),
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
        title: const Text(
          'Log a Reading',
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

            if (_needsBP) ...[
              _sectionLabel('Blood Pressure (mmHg)'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _inputField(
                      controller: _sbpController,
                      hint: 'Systolic',
                      label: 'SBP',
                      maxLength: 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '/',
                    style: TextStyle(
                      fontSize: 24,
                      color: AppColors.primaryText(context),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _inputField(
                      controller: _dbpController,
                      hint: 'Diastolic',
                      label: 'DBP',
                      maxLength: 3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionLabel('Heart Rate (bpm) — optional'),
              const SizedBox(height: 8),
              _inputField(
                controller: _heartRateController,
                hint: 'e.g. 78',
                label: 'HR',
                maxLength: 3,
              ),
              const SizedBox(height: 20),
            ],

            if (_needsGlucose) ...[
              _sectionLabel('Blood Glucose (mmol/L)'),
              const SizedBox(height: 8),
              _inputField(
                controller: _glucoseController,
                hint: 'e.g. 6.1',
                label: 'BG',
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
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_outlined, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Save Reading',
                            style: TextStyle(
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
                  'Enter your reading',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Type the values shown on your blood pressure monitor or '
                  'glucometer. Logging both together gives your risk score '
                  'the most to work with.',
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
          style: TextStyle(
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
