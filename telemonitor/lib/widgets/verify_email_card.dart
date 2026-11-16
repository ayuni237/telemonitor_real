import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';

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
    final l10n = context.l10n;
    try {
      final ok = await AuthService.instance.refreshEmailVerified();
      if (!mounted) return;
      setState(() => _verified = ok);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? l10n.emailConfirmed
                : l10n.emailNotConfirmedYet,
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
    final l10n = context.l10n;
    try {
      await AuthService.instance.sendEmailVerification();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.emailSentCheckSpam)),
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'too-many-requests'
                ? l10n.emailSentRecently
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
    final email = AuthService.instance.currentProfile?.email ?? context.l10n.yourAddress;
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
                  context.l10n.confirmEmailTitle,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.confirmEmailBody(email),
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
                  child: Text(context.l10n.sendItAgain),
                ),
                TextButton(
                  onPressed: _busy ? null : _check,
                  style: TextButton.styleFrom(foregroundColor: fg),
                  child: Text(context.l10n.iveConfirmedIt, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
