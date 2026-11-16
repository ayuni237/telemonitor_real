import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// English or French, for the app, its notifications and its emails. Each
/// language is named in itself, so it can be found whatever the current one.
class LanguageSelectorCard extends StatelessWidget {
  const LanguageSelectorCard({super.key});

  static const names = {'en': 'English', 'fr': 'Français'};

  /// Applies and saves the choice, on the account too when signed in.
  static Future<void> choose(String code) =>
      LocaleController.instance.choose(code, uid: AuthService.instance.currentFirebaseUser?.uid);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: LocaleController.instance, builder: _build);
  }

  Widget _build(BuildContext context, Widget? _) {
    final current = LocaleController.instance.code;
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
              Icon(Icons.translate, size: 16, color: AppColors.primaryText(context)),
              const SizedBox(width: 8),
              Text(
                context.l10n.languageTitle,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText(context)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final code in LocaleController.supported) ...[
                if (code != LocaleController.supported.first) const SizedBox(width: 8),
                Expanded(child: _option(context, code, current == code)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(context.l10n.languageNote, style: TextStyle(fontSize: 11, color: AppColors.textMuted(context))),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, String code, bool selected) {
    final color = selected ? Colors.white : AppColors.textSecondary(context);
    return Material(
      color: selected ? AppColors.primary : AppColors.field(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => choose(code),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(code.toUpperCase(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 4),
              Text(names[code]!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact EN | FR switch, for screens without room for the card (the
/// login screen, the clinician's app bar).
class LanguageToggle extends StatelessWidget {
  final Color? color;

  const LanguageToggle({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: LocaleController.instance, builder: _build);
  }

  Widget _build(BuildContext context, Widget? _) {
    final current = LocaleController.instance.code;
    final base = color ?? AppColors.primaryText(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final code in LocaleController.supported) ...[
          if (code != LocaleController.supported.first)
            Text('|', style: TextStyle(color: base.withValues(alpha: 0.5), fontSize: 13)),
          Semantics(
            selected: current == code,
            label: LanguageSelectorCard.names[code],
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => LanguageSelectorCard.choose(code),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  code.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: current == code ? FontWeight.w800 : FontWeight.w500,
                    color: current == code ? base : base.withValues(alpha: 0.6),
                    decoration: current == code ? TextDecoration.underline : null,
                    decorationColor: base,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
