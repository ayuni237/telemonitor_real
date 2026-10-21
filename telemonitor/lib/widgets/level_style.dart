import 'package:flutter/material.dart';

import '../services/clinical_levels.dart';
import '../theme/app_theme.dart';

/// One colour per level of the thesis label, used by every screen, so that a
/// reading looks the same on the dashboard, the history, the entry preview
/// and the clinician's views. The colours follow the tier the level maps to
/// (configs/serve.yaml, rule_floor): critical -> red, high -> yellow,
/// moderate and stable -> green, moderate being set apart by a neutral tint.
class LevelStyle {
  final String label;
  final Color fg;
  final Color bg;

  const LevelStyle(this.label, this.fg, this.bg);

  factory LevelStyle.of(BuildContext context, int? level) => switch (level) {
        3 => LevelStyle(ClinicalLevels.name(3), AppColors.dangerText(context), AppColors.dangerBg(context)),
        2 => LevelStyle(ClinicalLevels.name(2), AppColors.warningText(context), AppColors.warningBg(context)),
        1 => LevelStyle(ClinicalLevels.name(1), AppColors.primaryText(context), AppColors.tint(context)),
        0 => LevelStyle(ClinicalLevels.name(0), AppColors.successText(context), AppColors.successBg(context)),
        _ => LevelStyle(ClinicalLevels.name(null), AppColors.textSecondary(context), AppColors.field(context)),
      };

  /// Value colour on a neutral card: only high and critical stand out.
  static Color valueColor(BuildContext context, int? level) => switch (level) {
        3 => AppColors.dangerText(context),
        2 => AppColors.warningText(context),
        _ => AppColors.primaryText(context),
      };

  Widget badge({double fontSize = 11}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: fg)),
      );
}
