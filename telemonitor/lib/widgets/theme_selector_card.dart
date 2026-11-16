import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../l10n/l10n.dart';

/// Lets the user choose Light, Dark, or follow the device setting.
///
/// Drop-in: place `const ThemeSelectorCard()` anywhere in a column. It
/// carries its own card styling to match the surrounding screens.
class ThemeSelectorCard extends StatelessWidget {
  const ThemeSelectorCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final current = ThemeController.instance.mode;

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
                  Icon(Icons.brightness_6_outlined,
                      size: 16, color: AppColors.primaryText(context)),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.appearanceTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _option(context, ThemeMode.light, context.l10n.themeLight,
                      Icons.light_mode_outlined, current),
                  const SizedBox(width: 8),
                  _option(context, ThemeMode.dark, context.l10n.themeDark,
                      Icons.dark_mode_outlined, current),
                  const SizedBox(width: 8),
                  _option(context, ThemeMode.system, context.l10n.themeAuto,
                      Icons.phone_android_outlined, current),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                current == ThemeMode.system
                    ? context.l10n.themeFollowsDevice
                    : current == ThemeMode.dark
                        ? context.l10n.themeAlwaysDark
                        : context.l10n.themeAlwaysLight,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _option(
    BuildContext context,
    ThemeMode mode,
    String label,
    IconData icon,
    ThemeMode current,
  ) {
    final selected = current == mode;

    return Expanded(
      child: Material(
        color: selected
            ? AppColors.primary
            : AppColors.field(context),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => ThemeController.instance.setMode(mode),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? Colors.white
                      : AppColors.textSecondary(context),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
