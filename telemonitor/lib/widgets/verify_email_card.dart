import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Reminder on the patient's dashboard until their email address is
/// confirmed (auth_service.dart, "Email confirmation"): the link sent at
/// sign-up, sent again on request, then checked with the server.
class VerifyEmailCard extends StatefulWidget {
  const VerifyEmailCard({super.key});

  @override
  State<VerifyEmailCard> createState() => _VerifyEmailCardState();
}

class _VerifyEmailCardState extends State<VerifyEmailCard> {
  bool _verified = AuthService.instance.emailVerified;
  bool _busy = false;

  Future<void> _check() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await AuthService.instance.refreshEmailVerified();
      if (!mounted) return;
      setState(() => _verified = ok);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Email address confirmed. Thank you.'
                : 'Not confirmed yet. Open the link in the email, then tap this button again.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(AuthService.instance.messageFor(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.instance.sendEmailVerification();
      messenger.showSnackBar(
        const SnackBar(content: Text('Email sent. It can take a few minutes; look in the spam folder too.')),
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'too-many-requests'
                ? 'An email was sent a moment ago. Please wait a few minutes before asking again.'
                : AuthService.instance.messageFor(e),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(AuthService.instance.messageFor(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) return const SizedBox.shrink();
    final email = AuthService.instance.currentProfile?.email ?? 'your address';
    // the neutral card style: amber and red belong to the clinical levels
    final fg = AppColors.primaryText(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
              Icon(Icons.mark_email_unread_outlined, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confirm your email address',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'We sent a link to $email. Open it to confirm the address: it is the only way '
            'to set a new password if you forget yours.',
            style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton(
                  onPressed: _busy ? null : _resend,
                  style: TextButton.styleFrom(foregroundColor: fg),
                  child: const Text('Send it again'),
                ),
                TextButton(
                  onPressed: _busy ? null : _check,
                  style: TextButton.styleFrom(foregroundColor: fg),
                  child: const Text("I've confirmed it", style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
