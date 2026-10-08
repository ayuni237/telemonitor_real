import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Lets a patient who registered without a clinician connect to one
/// later, using the code their doctor gives them.
///
/// This is a one-time action — see [AuthService.linkToClinician] for why
/// switching is not permitted.
class ConnectClinicianScreen extends StatefulWidget {
  const ConnectClinicianScreen({super.key});

  @override
  State<ConnectClinicianScreen> createState() =>
      _ConnectClinicianScreenState();
}

class _ConnectClinicianScreenState extends State<ConnectClinicianScreen> {
  final _codeController = TextEditingController();

  Timer? _debounce;
  bool _checking = false;
  bool _checked = false;
  ClinicianCode? _verified;

  bool _isLinking = false;
  String? _errorMessage;

  @override
  void dispose() {
    _debounce?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _verified = null;
      _checked = false;
      _errorMessage = null;
    });
    if (value.trim().length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 600), _verify);
  }

  Future<void> _verify() async {
    setState(() => _checking = true);
    ClinicianCode? result;
    try {
      result =
          await AuthService.instance.lookupClinicianCode(_codeController.text);
    } catch (_) {
      result = null;
    }
    if (!mounted) return;
    setState(() {
      _verified = result;
      _checked = true;
      _checking = false;
    });
  }

  Future<void> _confirmAndLink() async {
    final code = _verified;
    if (code == null) return;

    // Confirmed explicitly because the action cannot be undone by the
    // patient afterwards.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm your clinician',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText(context),
          ),
        ),
        content: Text(
          'You will be connected to ${code.clinicianName}. They will be '
          'able to see the readings you record.\n\n'
          'This cannot be changed from the app afterwards — contact your '
          'care team if you need it corrected.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      _isLinking = true;
      _errorMessage = null;
    });

    try {
      final linked =
          await AuthService.instance.linkToClinician(_codeController.text);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${linked.clinicianName}'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AuthService.instance.messageFor(e);
        _isLinking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Connect to your clinician',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your clinician code',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ask your doctor for their code. It looks something like '
                    'MBARGA-4F7K.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _codeController,
                    onChanged: _onChanged,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      fontSize: 16,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'MBARGA-4F7K',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted(context),
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: Icon(Icons.medical_services_outlined,
                          color: AppColors.primaryText(context), size: 20),
                      filled: true,
                      fillColor: AppColors.field(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                  _feedback(),
                  const SizedBox(height: 18),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline,
                              color: AppColors.dangerText(context), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.dangerText(context)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_verified == null || _isLinking)
                          ? null
                          : _confirmAndLink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.textMuted(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLinking
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Connect',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.tint(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.help_outline,
                      size: 16, color: AppColors.primaryText(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Don't have a code yet? You can keep recording your "
                      'readings without one. They are saved to your account '
                      'and your clinician will see them from the day you '
                      'connect.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedback() {
    if (_checking) {
      return const Padding(
        padding: EdgeInsets.only(top: 10, left: 4),
        child: Row(
          children: [
            SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Checking code…',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      );
    }
    if (_verified != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, left: 4),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 14, color: AppColors.successText(context)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _verified!.clinicianName,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.successText(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_checked) {
      return Padding(
        padding: EdgeInsets.only(top: 10, left: 4),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 14, color: AppColors.dangerText(context)),
            SizedBox(width: 6),
            Text('Code not recognised',
                style: TextStyle(fontSize: 11, color: AppColors.dangerText(context))),
          ],
        ),
      );
    }
    return const SizedBox(height: 10);
  }
}
