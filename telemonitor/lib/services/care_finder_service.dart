import 'package:url_launcher/url_launcher.dart';
import '../l10n/l10n.dart';

/// A category of care facility a patient might need to find.
enum CareCategory {
  pharmacy,
  hospital,
  clinic,
  laboratory,
}

extension CareCategoryInfo on CareCategory {
  /// The search text sent to Google Maps.
  ///
  /// French is used alongside English because Douala is Francophone and
  /// most facilities are listed under French names — "pharmacie" returns
  /// considerably more local results than "pharmacy" alone.
  String get query {
    switch (this) {
      case CareCategory.pharmacy:
        return 'pharmacie pharmacy';
      case CareCategory.hospital:
        return 'hopital hospital';
      case CareCategory.clinic:
        return 'clinique clinic centre de sante';
      case CareCategory.laboratory:
        return 'laboratoire analyses medicales';
    }
  }

  String get label {
    switch (this) {
      case CareCategory.pharmacy:
        return l10nNow.carePharmacy;
      case CareCategory.hospital:
        return l10nNow.careHospital;
      case CareCategory.clinic:
        return l10nNow.careClinic;
      case CareCategory.laboratory:
        return l10nNow.careLaboratory;
    }
  }

  String get description {
    switch (this) {
      case CareCategory.pharmacy:
        return l10nNow.carePharmacyNote;
      case CareCategory.hospital:
        return l10nNow.careHospitalNote;
      case CareCategory.clinic:
        return l10nNow.careClinicNote;
      case CareCategory.laboratory:
        return l10nNow.careLaboratoryNote;
    }
  }
}

/// Opens Google Maps at a search for nearby care facilities.
///
/// Deliberately hands off to Google Maps rather than embedding a map.
/// Two reasons, and both matter here:
///
///  1. An in-app map using the Places API requires a Google Maps Platform
///     billing account. Handing off needs no API key and no billing, so
///     the feature cannot break because a card expired.
///  2. The query says "near me", which lets Google resolve the location
///     itself. The app therefore never requests the device's location
///     permission, never receives coordinates, and never stores them —
///     one less category of personal data in a system that already
///     handles clinical measurements.
///
/// If Google Maps is not installed the URL opens in the browser, so this
/// works on any device.
class CareFinderService {
  CareFinderService._internal();
  static final CareFinderService instance = CareFinderService._internal();

  /// Launches a nearby search for [category].
  ///
  /// Returns false if no application could handle the request, so the
  /// caller can tell the patient rather than appearing to do nothing.
  Future<bool> findNearby(CareCategory category) async {
    final q = Uri.encodeComponent('${category.query} near me');
    // Google's documented Maps URL format, stable across platforms.
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
