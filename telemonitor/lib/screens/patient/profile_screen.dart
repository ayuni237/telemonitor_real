import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/clinician_link_card.dart';
import '../../widgets/theme_selector_card.dart';
import 'edit_profile_screen.dart';

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
            title: const Text(
              'My Profile',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            actions: [
              if (profile != null)
                IconButton(
                  tooltip: 'Edit profile',
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
                    'Medical Conditions',
                    Icons.medical_information_outlined,
                    p.conditions,
                    AppColors.dangerText(context),
                  ),
                  const SizedBox(height: 14),
                ],
                if (p.medications.isNotEmpty) ...[
                  _listCard(
                    context,
                    'Current Medications',
                    Icons.medication_outlined,
                    p.medications,
                    AppColors.primaryText(context),
                  ),
                  const SizedBox(height: 14),
                ],
                if (p.height != null || p.weight != null) ...[
                  _card(
                    context,
                    title: 'Physical Info',
                    icon: Icons.monitor_weight_outlined,
                    child: Column(
                      children: [
                        if (p.height != null)
                          _row(context, 'Height', _withUnit(p.height!, 'cm'),
                              Icons.height),
                        if (p.height != null && p.weight != null)
                          const SizedBox(height: 10),
                        if (p.weight != null)
                          _row(context, 'Weight', _withUnit(p.weight!, 'kg'),
                              Icons.monitor_weight_outlined),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (p.phone != null || p.emergencyContact != null) ...[
                  _card(
                    context,
                    title: 'Contact',
                    icon: Icons.phone_outlined,
                    child: Column(
                      children: [
                        if (p.phone != null)
                          _row(context, 'Phone', p.phone!,
                              Icons.phone_outlined),
                        if (p.phone != null && p.emergencyContact != null)
                          const SizedBox(height: 10),
                        if (p.emergencyContact != null)
                          _row(context, 'Emergency', p.emergencyContact!,
                              Icons.emergency_outlined),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Appearance control — Light / Dark / Auto.
                const ThemeSelectorCard(),
                const SizedBox(height: 14),

                _card(
                  context,
                  title: 'Account',
                  icon: Icons.badge_outlined,
                  child: Column(
                    children: [
                      _row(context, 'Email', p.email, Icons.email_outlined),
                      const SizedBox(height: 10),
                      _row(
                        context,
                        'Clinician',
                        p.isAssigned ? 'Assigned' : 'Not yet assigned',
                        Icons.person_pin_outlined,
                      ),
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
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                _initials(p.displayName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
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
                if (p.age != null) _pill('${p.age} yrs', Icons.cake_outlined),
                if (p.sex != null) _pill(p.sex!, Icons.person_outline),
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
                'Complete your profile',
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
            'Adding your conditions, medications and emergency contact '
            'helps your clinician interpret your readings.',
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
              child: const Text(
                'Add details',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
              'Sign Out',
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

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
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
