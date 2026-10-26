import 'package:flutter/material.dart';

import '../services/home_protocol.dart';
import '../theme/app_theme.dart';

/// One colour per level of the home triage (green, yellow, red; thesis ch.4
/// §triage), used by every screen, so that a reading looks the same on the
/// dashboard, the history, the entry preview and the clinician's views, and
/// matches the risk tier it leads to.
class LevelStyle {
  final String label;
  final Color fg;
  final Color bg;

  const LevelStyle(this.label, this.fg, this.bg);

  factory LevelStyle.of(BuildContext context, int? level) => switch (level) {
        HomeProtocol.red => LevelStyle(HomeProtocol.name(level), AppColors.dangerText(context), AppColors.dangerBg(context)),
        HomeProtocol.yellow =>
          LevelStyle(HomeProtocol.name(level), AppColors.warningText(context), AppColors.warningBg(context)),
        HomeProtocol.green =>
          LevelStyle(HomeProtocol.name(level), AppColors.successText(context), AppColors.successBg(context)),
        _ => LevelStyle(HomeProtocol.name(null), AppColors.textSecondary(context), AppColors.field(context)),
      };

  /// Value colour on a neutral card: only yellow and red stand out.
  static Color valueColor(BuildContext context, int? level) => switch (level) {
        HomeProtocol.red => AppColors.dangerText(context),
        HomeProtocol.yellow => AppColors.warningText(context),
        _ => AppColors.primaryText(context),
      };

  Widget badge({double fontSize = 12}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: fg)),
      );
}
