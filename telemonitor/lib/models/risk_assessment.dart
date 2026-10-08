import 'risk_prediction.dart';

/// Why a risk assessment could not be produced.
enum RiskUnavailableReason {
  /// Fewer than 7 readings logged in total.
  notEnoughReadings,

  /// Seven readings exist, but one or more channels has too few real
  /// values to summarise honestly (see kMinRealPerChannel).
  tooSparse,

  /// The model failed to load or run.
  modelError,
}

/// The outcome of asking for a patient's current risk level: either a
/// prediction, or a specific reason there isn't one.
///
/// Modelled as one type with an explicit "unavailable" case rather than
/// a nullable prediction, because the UI needs to tell the patient WHY
/// there's no score — "3 more readings needed" is useful, a blank card
/// is not.
class RiskAssessment {
  final RiskPrediction? prediction;
  final RiskUnavailableReason? reason;

  /// How many readings are still needed, when [reason] is
  /// notEnoughReadings.
  final int readingsStillNeeded;

  /// Fraction of the 28 values in the window (4 channels x 7 readings)
  /// that came from actual measurements rather than being carried
  /// forward. 1.0 means nothing was imputed.
  final double completeness;

  /// Channels that were partly or wholly imputed — surfaced so a
  /// clinician can see which parts of the input were reconstructed.
  final List<String> imputedChannels;

  const RiskAssessment._({
    this.prediction,
    this.reason,
    this.readingsStillNeeded = 0,
    this.completeness = 1.0,
    this.imputedChannels = const [],
  });

  factory RiskAssessment.available({
    required RiskPrediction prediction,
    required double completeness,
    required List<String> imputedChannels,
  }) =>
      RiskAssessment._(
        prediction: prediction,
        completeness: completeness,
        imputedChannels: imputedChannels,
      );

  factory RiskAssessment.unavailable(
    RiskUnavailableReason reason, {
    int readingsStillNeeded = 0,
  }) =>
      RiskAssessment._(
        reason: reason,
        readingsStillNeeded: readingsStillNeeded,
      );

  bool get isAvailable => prediction != null;

  /// True when a meaningful share of the input was carried forward
  /// rather than measured. The threshold is a judgement call, not a
  /// derived constant: below this, the score is still shown but flagged,
  /// because a confident-looking number built largely from repeated
  /// values would mislead more than it informs.
  bool get isLowConfidence => completeness < 0.75;

  String get explanation {
    switch (reason) {
      case RiskUnavailableReason.notEnoughReadings:
        return readingsStillNeeded == 1
            ? '1 more reading needed before a risk score can be calculated.'
            : '$readingsStillNeeded more readings needed before a risk '
                'score can be calculated.';
      case RiskUnavailableReason.tooSparse:
        return 'Not enough blood pressure and glucose measurements in '
            'recent readings. Log both together to enable the risk score.';
      case RiskUnavailableReason.modelError:
        return 'The risk model could not be loaded on this device.';
      case null:
        return '';
    }
  }
}
