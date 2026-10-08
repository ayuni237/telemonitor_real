import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/app_user.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';

/// Lets a patient maintain their own profile details.
///
/// Deliberately absent: email, role, and assigned clinician. Those are
/// administrative fields — shown read-only at the bottom so the patient
/// can see them, but not editable here or anywhere in the app.
class EditProfileScreen extends StatefulWidget {
  final AppUser profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _phone;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _conditions;
  late final TextEditingController _medications;
  late final TextEditingController _emergency;

  String? _sex;
  String? _bloodType;
  bool _saving = false;

  static const _sexOptions = ['Male', 'Female', 'Other'];
  static const _bloodOptions = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p.name);
    _age = TextEditingController(text: p.age?.toString() ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    _height = TextEditingController(text: p.height ?? '');
    _weight = TextEditingController(text: p.weight ?? '');
    _conditions = TextEditingController(text: p.conditions.join('\n'));
    _medications = TextEditingController(text: p.medications.join('\n'));
    _emergency = TextEditingController(text: p.emergencyContact ?? '');
    _sex = _sexOptions.contains(p.sex) ? p.sex : null;
    _bloodType = _bloodOptions.contains(p.bloodType) ? p.bloodType : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _phone.dispose();
    _height.dispose();
    _weight.dispose();
    _conditions.dispose();
    _medications.dispose();
    _emergency.dispose();
    super.dispose();
  }

  List<String> _lines(TextEditingController c) => c.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final ageText = _age.text.trim();
    int? age;
    if (ageText.isNotEmpty) {
      age = int.tryParse(ageText);
      // Wide bounds that catch a typo without second-guessing an
      // unusual but real value.
      if (age == null || age < 1 || age > 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter an age between 1 and 120.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await ProfileService.instance.updateOwnProfile(
        name: name,
        age: age,
        sex: _sex,
        phone: _phone.text,
        height: _height.text,
        weight: _weight.text,
        bloodType: _bloodType,
        conditions: _lines(_conditions),
        medications: _lines(_medications),
        emergencyContact: _emergency.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _card('About you', Icons.person_outline, [
              _field(_name, 'Full name', 'e.g. Jean Mbarga'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _field(_age, 'Age', 'e.g. 34',
                        numeric: true, maxLength: 3),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dropdown(
                      label: 'Sex',
                      value: _sex,
                      options: _sexOptions,
                      onChanged: (v) => setState(() => _sex = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _field(_height, 'Height', 'e.g. 175 cm')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_weight, 'Weight', 'e.g. 78 kg')),
                ],
              ),
              const SizedBox(height: 14),
              _dropdown(
                label: 'Blood type',
                value: _bloodType,
                options: _bloodOptions,
                onChanged: (v) => setState(() => _bloodType = v),
              ),
            ]),

            const SizedBox(height: 14),
            _card('Medical', Icons.medical_information_outlined, [
              _field(
                _conditions,
                'Conditions',
                'One per line\ne.g. Hypertension\nType 2 Diabetes',
                lines: 3,
              ),
              const SizedBox(height: 14),
              _field(
                _medications,
                'Current medications',
                'One per line\ne.g. Amlodipine 5mg',
                lines: 3,
              ),
            ]),

            const SizedBox(height: 14),
            _card('Contact', Icons.phone_outlined, [
              _field(_phone, 'Phone', '+237 6XX XXX XXX'),
              const SizedBox(height: 14),
              _field(_emergency, 'Emergency contact', '+237 6XX XXX XXX'),
            ]),

            const SizedBox(height: 14),
            _readOnlyCard(),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
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
            children: [
              Icon(icon, size: 16, color: AppColors.primaryText(context)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  /// Fields the patient can see but not change — shown so the
  /// restriction is visible rather than mysterious.
  Widget _readOnlyCard() {
    final p = widget.profile;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tint(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline,
                  size: 15, color: AppColors.textSecondary(context)),
              const SizedBox(width: 8),
              Text(
                'Managed by your care team',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _roRow('Email', p.email),
          _roRow('Account type',
              p.role == UserRole.clinician ? 'Clinician' : 'Patient'),
          _roRow('Assigned clinician',
              p.isAssigned ? 'Linked' : 'Not yet assigned'),
        ],
      ),
    );
  }

  Widget _roRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary(context))),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    String hint, {
    bool numeric = false,
    int lines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: c,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        if (numeric) FilteringTextInputFormatter.digitsOnly,
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      maxLines: lines,
      // Explicit text colour: without it the field inherits the theme's
      // default, which on a light fill in dark mode renders light-on-light
      // and is unreadable.
      style: TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: AppColors.primaryText(context), fontSize: 12),
        floatingLabelStyle: TextStyle(
            color: AppColors.primaryText(context), fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textMuted(context), fontSize: 12),
        counterText: '',
        filled: true,
        fillColor: AppColors.field(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppColors.primaryText(context), width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: AppColors.card(context),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: AppColors.primaryText(context), fontSize: 12),
        floatingLabelStyle: TextStyle(
            color: AppColors.primaryText(context), fontSize: 13),
        filled: true,
        fillColor: AppColors.field(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('Not set',
              style: TextStyle(color: AppColors.textMuted(context))),
        ),
        ...options.map((o) => DropdownMenuItem(value: o, child: Text(o))),
      ],
      onChanged: onChanged,
    );
  }
}
