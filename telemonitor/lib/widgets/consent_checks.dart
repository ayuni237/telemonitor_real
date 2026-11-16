import 'package:flutter/material.dart';

import '../screens/terms_screen.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';

/// The two ticks of the sign-up form and of the terms screen: the terms of
/// use (required) and the use of the data for research (optional, separate,
/// so that saying no costs the patient nothing).
class ConsentChecks extends StatelessWidget {
  final bool terms;
  final bool research;
  final ValueChanged<bool> onTerms;
  final ValueChanged<bool> onResearch;

  /// Shows the "Read the terms" link (not needed under the full text).
  final bool showReadLink;

  const ConsentChecks({
    super.key,
    required this.terms,
    required this.research,
    required this.onTerms,
    required this.onResearch,
    this.showReadLink = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Tick(
          value: terms,
          onChanged: onTerms,
          text: context.l10n.acceptTermsTick,
        ),
        if (showReadLink)
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 32),
                foregroundColor: AppColors.primaryText(context),
              ),
              icon: const Icon(Icons.description_outlined, size: 16),
              label: Text(context.l10n.readTheTerms, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        const SizedBox(height: 4),
        _Tick(
          value: research,
          onChanged: onResearch,
          text: context.l10n.researchTick,
        ),
      ],
    );
  }
}

class _Tick extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;

  const _Tick({required this.value, required this.onChanged, required this.text});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              height: 32,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  text,
                  style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textPrimary(context)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
