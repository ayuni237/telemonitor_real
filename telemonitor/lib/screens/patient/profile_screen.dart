import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/consent_service.dart';
import '../../services/profile_service.dart';
import '../../services/push_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/clinician_link_card.dart';
import '../../widgets/language_selector_card.dart';
import '../../widgets/theme_selector_card.dart';
import '../../widgets/user_avatar.dart';
import '../terms_screen.dart';
import 'edit_profile_screen.dart';
import '../../l10n/l10n.dart';

/// The patient's own profile, driven by their Firestore document.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: ProfileService.instance.watchOwnProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;

        return Scaffold(
          backgroundColor: AppColors.background(context),
          appBar: AppBar(
            title: Text(
              context.l10n.myProfile,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            actions: [
              if (profile != null)
                IconButton(
                  tooltip: context.l10n.editProfile,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(profile: profile),
                    ),
                  ),
                ),
            ],
          ),
          body: profile == null
              ? const Center(child: CircularProgressIndicator())
              : _body(context, profile),
        );
      },
    );
  }

  Widget _body(BuildContext context, AppUser p) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _header(context, p),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const ClinicianLinkCard(),
                if (!p.hasClinicalInfo) _completePrompt(context, p),
                if (p.conditions.isNotEmpty) ...[
                  _listCard(
                    context,
                    context.l10n.medicalConditions,
                    Icons.medical_information_outlined,
                    p.conditions,
                    AppColors.dangerText(context),
                  ),
                  const SizedBox(height: 14),
                ],
                if (p.medications.isNotEmpty) ...[
                  _listCard(
                    context,
                    context.l10n.currentMedications,
                    Icons.medication_outlined,
                    p.medications,
                    AppColors.primaryText(context),
                  ),
                  const SizedBox(height: 14),
                ],
                if (p.height != null || p.weight != null) ...[
                  _card(
                    context,
                    title: context.l10n.physicalInfo,
                    icon: Icons.monitor_weight_outlined,
                    child: Column(
                      children: [
                        if (p.height != null)
                          _row(context, context.l10n.height, _withUnit(p.height!, 'cm'),
                              Icons.height),
                        if (p.height != null && p.weight != null)
                          const SizedBox(height: 10),
                        if (p.weight != null)
                          _row(context, context.l10n.weight, _withUnit(p.weight!, 'kg'),
                              Icons.monitor_weight_outlined),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (p.phone != null || p.emergencyContact != null) ...[
                  _card(
                    context,
                    title: context.l10n.contact,
                    icon: Icons.phone_outlined,
                    child: Column(
                      children: [
                        if (p.phone != null)
                          _row(context, context.l10n.phone, p.phone!,
                              Icons.phone_outlined),
                        if (p.phone != null && p.emergencyContact != null)
                          const SizedBox(height: 10),
                        if (p.emergencyContact != null)
                          _row(context, context.l10n.emergency, p.emergencyContact!,
                              Icons.emergency_outlined),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                _consentCard(context, p),
                const SizedBox(height: 14),

                // Appearance control — Light / Dark / Auto.
                const ThemeSelectorCard(),
                const SizedBox(height: 14),

                // English or French, for the app, notifications and emails.
                const LanguageSelectorCard(),
                const SizedBox(height: 14),

                _card(
                  context,
                  title: context.l10n.account,
                  icon: Icons.badge_outlined,
                  child: Column(
                    children: [
                      _row(context, context.l10n.emailLabel, p.email, Icons.email_outlined),
                      const SizedBox(height: 10),
                      _row(
                        context,
                        context.l10n.clinician,
                        p.isAssigned ? context.l10n.assigned : context.l10n.notYetAssigned,
                        Icons.person_pin_outlined,
                      ),
                      const SizedBox(height: 4),
                      _actionRow(
                        context,
                        context.l10n.passwordLabel,
                        context.l10n.change,
                        Icons.lock_outline,
                        () => _changePassword(context, p.email),
                      ),
                      const _NotificationsRow(),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _signOutButton(context),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Terms accepted, and the research consent the patient can give or
  /// withdraw at any time (consent_service.dart).
  Widget _consentCard(BuildContext context, AppUser p) {
    final accepted = p.termsAcceptedAt == null
        ? context.l10n.termsAccepted
        : context.l10n.termsAcceptedOn(DateFormat('d MMM y').format(p.termsAcceptedAt!));
    return _card(
      context,
      title: context.l10n.privacyAndConsent,
      icon: Icons.privacy_tip_outlined,
      child: Column(
        children: [
          _actionRow(
            context,
            context.l10n.termsOfUse,
            context.l10n.read,
            Icons.description_outlined,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
            detail: accepted,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.science_outlined, size: 16, color: AppColors.textMuted(context)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.researchUseTitle,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.researchUseNote,
                      style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.textMuted(context)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: p.researchConsent,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => _setResearch(context, v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _setResearch(BuildContext context, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    String text;
    try {
      await ConsentService.instance.setResearchConsent(value);
      text = value
          ? l10n.researchConsentGiven
          : l10n.researchConsentWithdrawn;
    } on TimeoutException {
      text = l10n.savedOffline;
    } catch (e) {
      text = l10n.choiceNotSaved('$e');
    }
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  /// A reset link to the account's own address, as from the login screen.
  static Future<void> _changePassword(BuildContext context, String email) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await AuthService.instance.sendPasswordReset(email);
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.resetLinkSentTo(email)),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(AuthService.instance.messageFor(e))));
    }
  }

  Widget _actionRow(BuildContext context, String label, String action, IconData icon, VoidCallback onTap,
      {String? detail}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
              if (detail != null)
                Text(detail, style: TextStyle(fontSize: 11, color: AppColors.textMuted(context))),
            ],
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryText(context),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 36),
          ),
          child: Text(action, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  /// Appends a unit unless the stored value already carries letters.
  static String _withUnit(String value, String unit) {
    final v = value.trim();
    return RegExp(r'[a-zA-Z]').hasMatch(v) ? v : '$v $unit';
  }

  Widget _header(BuildContext context, AppUser p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      // Brand navy in both themes, matching the app bar above it.
      decoration: const BoxDecoration(color: AppColors.primary),
      child: Column(
        children: [
          // Optional photo: tap to take, choose or remove it.
          Semantics(
            button: true,
            label: context.l10n.changeProfilePhoto,
            child: GestureDetector(
              onTap: () => showProfilePhotoSheet(context, uid: p.uid, forClinician: false),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    uid: p.uid,
                    name: p.displayName,
                    size: 72,
                    background: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white, width: 2),
                    fontSize: 26,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: const Icon(Icons.photo_camera, size: 13, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            p.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (p.age != null || p.sex != null || p.bloodType != null) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                if (p.age != null) _pill(context.l10n.ageYears(p.age!), Icons.cake_outlined),
                if (p.sex != null) _pill(context.l10n.sexLabel(p.sex!), Icons.person_outline),
                if (p.bloodType != null)
                  _pill(p.bloodType!, Icons.water_drop_outlined),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _completePrompt(BuildContext context, AppUser p) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningBg(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: AppColors.warningText(context)),
              const SizedBox(width: 8),
              Text(
                context.l10n.completeProfile,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warningText(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.completeProfileNote,
            style: TextStyle(
                fontSize: 12, color: AppColors.warningText(context)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(profile: p),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warningText(context),
                side: BorderSide(
                    color: AppColors.warningText(context), width: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                context.l10n.addDetails,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signOutButton(BuildContext context) {
    return GestureDetector(
      onTap: () => AuthService.instance.signOut(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primaryText(context).withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout,
                color: AppColors.primaryText(context), size: 18),
            const SizedBox(width: 8),
            Text(
              context.l10n.signOutButton,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listCard(BuildContext context, String title, IconData icon,
      List<String> items, Color dot) {
    return _card(
      context,
      title: title,
      icon: icon,
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: dot, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _row(
      BuildContext context, String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textMuted(context)),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary(context))),
          ],
        ),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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
          child,
        ],
      ),
    );
  }
}

/// Whether this phone shows the app's notifications (alerts, reminders,
/// reviews), with a way to ask again when they are off. Hidden where the app
/// cannot tell (screen tests, web).
class _NotificationsRow extends StatefulWidget {
  const _NotificationsRow();

  @override
  State<_NotificationsRow> createState() => _NotificationsRowState();
}

class _NotificationsRowState extends State<_NotificationsRow> {
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    PushService.instance.notificationsAllowed().then((v) {
      if (mounted) setState(() => _allowed = v);
    });
  }

  Future<void> _enable() async {
    final v = await PushService.instance.enable();
    if (!mounted) return;
    setState(() => _allowed = v);
    if (v != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.notificationsBlocked),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _allowed;
    if (allowed == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(allowed ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
              size: 16, color: AppColors.textMuted(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.l10n.notifications, style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
          ),
          if (allowed)
            Text(context.l10n.notificationsOn,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.successText(context)))
          else
            TextButton(
              onPressed: _enable,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.dangerText(context),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
              child: Text(context.l10n.notificationsTurnOn, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
