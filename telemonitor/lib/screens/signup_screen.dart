import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Patient self-registration.
///
/// Note what this screen does NOT contain: any choice of account type.
/// Every account created here is a patient. The clinician code selects
/// WHICH clinician the patient is linked to; it never selects WHAT the
/// user is. Clinician accounts are provisioned administratively.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Live verification of the clinician code, so the patient sees who
  // they are about to be linked to before committing.
  Timer? _codeDebounce;
  bool _checkingCode = false;
  ClinicianCode? _verifiedCode;
  bool _codeChecked = false;

  /// Matches the login screen: navy in light mode, normal dark page
  /// background in dark mode so the card keeps its contrast.
  Color _authBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.background(context)
          : AppColors.primary;

  @override
  void dispose() {
    _codeDebounce?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    _codeDebounce?.cancel();
    setState(() {
      _verifiedCode = null;
      _codeChecked = false;
    });
    if (value.trim().length < 3) return;

    // Debounced so a lookup is not fired on every keystroke.
    _codeDebounce = Timer(const Duration(milliseconds: 600), _verifyCode);
  }

  Future<void> _verifyCode() async {
    setState(() => _checkingCode = true);
    ClinicianCode? result;
    try {
      result =
          await AuthService.instance.lookupClinicianCode(_codeController.text);
    } catch (_) {
      result = null;
    }
    if (!mounted) return;
    setState(() {
      _verifiedCode = result;
      _codeChecked = true;
      _checkingCode = false;
    });
  }

  String? _validate() {
    if (_nameController.text.trim().isEmpty) {
      return 'Please enter your full name.';
    }
    if (_emailController.text.trim().isEmpty) {
      return 'Please enter your email address.';
    }
    if (_passwordController.text.length < 6) {
      return 'Please choose a password of at least 6 characters.';
    }
    // The clinician code is OPTIONAL. A patient may register without one
    // and connect later — otherwise someone who has heard about the app
    // but has no code yet is locked out entirely.
    final code = _codeController.text.trim();
    if (code.isNotEmpty && _verifiedCode == null) {
      return 'That code was not recognised. Check it, or clear the field '
          'and connect to your clinician later.';
    }
    return null;
  }

  Future<void> _handleSignUp() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _errorMessage = problem);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.signUpPatient(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
        clinicianCode: _codeController.text.trim().isEmpty
            ? null
            : _codeController.text,
      );
      // No manual navigation: AuthGate is listening to auth state and
      // swaps the screen as soon as the account exists.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AuthService.instance.messageFor(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _authBackground(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Create account',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.border(context), width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Join your care team',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create your account to start recording readings. '
                        'You can connect to a clinician now or later.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context)),
                      ),
                      const SizedBox(height: 24),

                      _label('Full name'),
                      const SizedBox(height: 8),
                      _field(
                        controller: _nameController,
                        hint: 'e.g. Jean Mbarga',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),

                      _label('Email'),
                      const SizedBox(height: 8),
                      _field(
                        controller: _emailController,
                        hint: 'you@example.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      _label('Password'),
                      const SizedBox(height: 8),
                      _field(
                        controller: _passwordController,
                        hint: 'At least 6 characters',
                        icon: Icons.lock_outline,
                        obscure: _obscurePassword,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textMuted(context),
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Text(
                            'Clinician code',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText(context),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(optional)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Have one from your doctor? Enter it to connect '
                        'straight away. You can also skip this and connect '
                        'later from your profile.',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                            height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      _field(
                        controller: _codeController,
                        hint: 'e.g. MBARGA-4F7K',
                        icon: Icons.medical_services_outlined,
                        onChanged: _onCodeChanged,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      _codeFeedback(),

                      const SizedBox(height: 20),

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
                                  color: AppColors.dangerText(context),
                                  size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.dangerText(context)),
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
                          onPressed: _isLoading ? null : _handleSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                              : const Text(
                                  'Create account',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Already have an account? Sign in',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryText(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Clinician accounts are created by the '
                            'administrator, not here.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
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
        ),
      ),
    );
  }

  /// Confirms to the patient which clinician they are about to join,
  /// before the account is created rather than after.
  Widget _codeFeedback() {
    if (_checkingCode) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text('Checking code…',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary(context))),
          ],
        ),
      );
    }

    if (_verifiedCode != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 14, color: AppColors.successText(context)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'You will be linked to ${_verifiedCode!.clinicianName}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.successText(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_codeChecked) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                size: 14, color: AppColors.dangerText(context)),
            const SizedBox(width: 6),
            Text('Code not recognised',
                style: TextStyle(
                    fontSize: 11, color: AppColors.dangerText(context))),
          ],
        ),
      );
    }

    return const SizedBox(height: 8);
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryText(context),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      // Explicit text colour — without it the field inherits the theme
      // default and renders light-on-light in dark mode.
      style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: AppColors.textMuted(context), fontSize: 13),
        prefixIcon:
            Icon(icon, color: AppColors.primaryText(context), size: 20),
        suffixIcon: suffix,
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
          borderSide:
              BorderSide(color: AppColors.primaryText(context), width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
