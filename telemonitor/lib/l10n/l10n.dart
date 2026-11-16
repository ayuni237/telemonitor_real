import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';
import 'locale_controller.dart';

export 'app_localizations.dart';
export 'locale_controller.dart';

extension L10nContext on BuildContext {
  /// The app's texts in the chosen language. English where the widget tree
  /// has no localizations (widget tests that build a bare MaterialApp).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ?? lookupAppLocalizations(const Locale('en'));
}

/// The texts outside widgets (services, models), in the chosen language.
AppLocalizations get l10nNow => lookupAppLocalizations(LocaleController.instance.locale);

/// Times as the screens show them, in the user's language (24-hour clock).
extension L10nTime on AppLocalizations {
  /// "5 min ago", "3 h ago", "2 d ago".
  String ago(DateTime t, [DateTime? now]) {
    final d = (now ?? DateTime.now()).difference(t);
    if (d.inMinutes < 60) return minutesAgo(d.inMinutes.clamp(0, 59));
    if (d.inHours < 24) return hoursAgo(d.inHours);
    return daysAgo(d.inDays);
  }

  /// "Today, 14:05", "Yesterday, 09:10", "3 Nov, 08:00".
  String dayAndTime(DateTime ts, [DateTime? now]) {
    now ??= DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(ts.year, ts.month, ts.day)).inDays;
    final time = DateFormat('HH:mm').format(ts);
    if (days == 0) return todayAt(time);
    if (days == 1) return yesterdayAt(time);
    return dateAt(DateFormat('d MMM').format(ts), time);
  }
}

/// Values stored in English in Firestore (the worker, the research export and
/// the clinician's other devices read them), shown in the user's language.
extension L10nValues on AppLocalizations {
  /// A level of the home triage (HomeProtocol: 0 green, 1 yellow, 2 red).
  String homeLevel(int? level) => switch (level) {
        0 => levelGreen,
        1 => levelYellow,
        2 => levelRed,
        _ => notMeasured,
      };

  /// The measurement context of a reading, as offered when logging it.
  String readingContextChoice(String stored) => switch (stored) {
        'Fasting' => ctxFasting,
        'Before meal' => ctxBeforeMeal,
        'After meal' => ctxAfterMeal,
        'After medication' => ctxAfterMedication,
        'After exercise' => ctxAfterExercise,
        'Random' => ctxRandom,
        _ => stored,
      };

  /// The measurement context in a few words, inside a sentence or a list
  /// ("fasting", "after a meal").
  String readingContextShort(String stored) => switch (stored) {
        'Fasting' => tagFasting,
        'Before meal' => tagBeforeMeal,
        'After meal' => tagAfterMeal,
        'After medication' => tagAfterMedication,
        'After exercise' => tagAfterExercise,
        'Random' => tagOtherTime,
        _ => stored,
      };

  /// A measured channel (StateEvolution: sbp, dbp, hr, glucose).
  String channelName(String channel) => switch (channel) {
        'sbp' => systolic,
        'dbp' => diastolic,
        'hr' => pulse,
        'glucose' => glucose,
        _ => channel,
      };

  String sexLabel(String stored) => switch (stored) {
        'Male' => sexMale,
        'Female' => sexFemale,
        'Other' => sexOther,
        _ => stored,
      };
}
