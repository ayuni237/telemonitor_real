// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageNote =>
      'Les notifications et les e-mails arrivent aussi dans cette langue.';

  @override
  String get loginMissingFields =>
      'Veuillez saisir votre e-mail et votre mot de passe.';

  @override
  String get resetLinkSentGeneric =>
      'Si un compte existe pour cette adresse, un lien de réinitialisation a été envoyé. Vérifiez votre boîte de réception, ainsi que le dossier spam.';

  @override
  String get appTagline => 'Télésurveillance des maladies chroniques';

  @override
  String get loginWelcome => 'Bon retour';

  @override
  String get loginSubtitle => 'Connectez-vous à votre compte';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get emailHint => 'vous@exemple.com';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get signIn => 'Se connecter';

  @override
  String get or => 'ou';

  @override
  String get createAccountLink => 'Nouveau patient ? Créez un compte';

  @override
  String get sameLogin => 'Patients et cliniciens utilisent la même connexion';

  @override
  String get resetPasswordTitle => 'Réinitialiser le mot de passe';

  @override
  String get resetPasswordIntro =>
      'Saisissez l\'adresse e-mail de votre compte : nous vous enverrons un lien pour choisir un nouveau mot de passe. Plus d\'accès à cette adresse ? Demandez à votre clinicien : l\'administrateur peut le réinitialiser.';

  @override
  String get cancel => 'Annuler';

  @override
  String get sendLink => 'Envoyer le lien';

  @override
  String get noProfileTitle => 'Aucun profil trouvé pour ce compte.';

  @override
  String noProfileBody(String uid) {
    return 'Ajoutez un document Firestore users/$uid avec les champs email, name et role pour terminer la configuration de ce compte.';
  }

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get appearanceTitle => 'Apparence';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeFollowsDevice => 'Suit le réglage de votre téléphone.';

  @override
  String get themeAlwaysDark =>
      'Toujours sombre, quel que soit le réglage de votre téléphone.';

  @override
  String get themeAlwaysLight =>
      'Toujours clair, quel que soit le réglage de votre téléphone.';

  @override
  String get myProfile => 'Mon profil';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get medicalConditions => 'Pathologies';

  @override
  String get currentMedications => 'Traitements en cours';

  @override
  String get physicalInfo => 'Informations physiques';

  @override
  String get height => 'Taille';

  @override
  String get weight => 'Poids';

  @override
  String get contact => 'Contact';

  @override
  String get phone => 'Téléphone';

  @override
  String get emergency => 'Urgence';

  @override
  String get account => 'Compte';

  @override
  String get clinician => 'Clinicien';

  @override
  String get assigned => 'Attribué';

  @override
  String get notYetAssigned => 'Pas encore attribué';

  @override
  String get change => 'Modifier';

  @override
  String get termsAccepted => 'Acceptées';

  @override
  String termsAcceptedOn(String date) {
    return 'Acceptées le $date';
  }

  @override
  String get privacyAndConsent => 'Confidentialité et consentement';

  @override
  String get termsOfUse => 'Conditions d\'utilisation';

  @override
  String get read => 'Lire';

  @override
  String get researchUseTitle => 'Utilisation de mes données pour la recherche';

  @override
  String get researchUseNote =>
      'Sans votre nom, vos coordonnées, votre photo ni vos messages. Vos soins restent les mêmes dans tous les cas.';

  @override
  String get researchConsentGiven =>
      'Merci. Vos données, sans votre nom ni vos coordonnées, pourront servir à la recherche.';

  @override
  String get researchConsentWithdrawn =>
      'C\'est fait. Vos données seront exclues des prochains extraits de recherche.';

  @override
  String get savedOffline =>
      'Enregistré sur le téléphone. Ce sera envoyé dès que vous serez de nouveau en ligne.';

  @override
  String choiceNotSaved(String error) {
    return 'Impossible d\'enregistrer votre choix : $error';
  }

  @override
  String resetLinkSentTo(String email) {
    return 'Nous avons envoyé un lien à $email pour choisir un nouveau mot de passe. Regardez aussi dans le dossier spam.';
  }

  @override
  String get changeProfilePhoto => 'Changer la photo de profil';

  @override
  String ageYears(int age) {
    return '$age ans';
  }

  @override
  String get sexMale => 'Homme';

  @override
  String get sexFemale => 'Femme';

  @override
  String get sexOther => 'Autre';

  @override
  String get completeProfile => 'Complétez votre profil';

  @override
  String get completeProfileNote =>
      'Indiquer vos pathologies, vos traitements et un contact d\'urgence aide votre clinicien à interpréter vos mesures.';

  @override
  String get addDetails => 'Compléter';

  @override
  String get signOutButton => 'Se déconnecter';

  @override
  String get notificationsBlocked =>
      'Les notifications sont bloquées sur ce téléphone. Autorisez-les pour TeleMonitor dans les réglages du téléphone (Applications, TeleMonitor, Notifications).';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsOn => 'Activées';

  @override
  String get notificationsTurnOn => 'Désactivées : activer';

  @override
  String get alternateRemoved => 'Suppléant retiré.';

  @override
  String alternateNamed(String name) {
    return '$name est désormais votre suppléant.';
  }

  @override
  String couldNotSave(String error) {
    return 'Enregistrement impossible : $error';
  }

  @override
  String get conversationNotOpened =>
      'Impossible d\'ouvrir cette conversation.';

  @override
  String get myPatients => 'Mes patients';

  @override
  String get myPhoto => 'Ma photo';

  @override
  String get alternateClinician => 'Clinicien suppléant';

  @override
  String queueTab(int count) {
    return 'File ($count)';
  }

  @override
  String get patientsTab => 'Patients';

  @override
  String get queueNotLoaded => 'Impossible de charger la file.';

  @override
  String get queueEmpty => 'Aucune alerte à examiner.';

  @override
  String get queueEmptyNote =>
      'Les mesures jaunes et rouges, les alertes du modèle et les patients qui n\'envoient plus de mesures apparaissent ici, les plus urgents en premier.';

  @override
  String get patientsNotLoaded => 'Impossible de charger les patients.';

  @override
  String get noPatientsYet => 'Aucun patient connecté pour l\'instant.';

  @override
  String get noPatientsYetNote =>
      'Communiquez le code ci-dessus à un patient pour qu\'il s\'inscrive et vous soit rattaché.';

  @override
  String get noReadingsYet => 'Aucune mesure pour l\'instant';

  @override
  String get readingLogged => 'Mesure enregistrée';

  @override
  String get noAlternate =>
      'Aucun suppléant désigné. Les alertes que vous laissez sans examen ne sont transmises à personne.';

  @override
  String currentAlternate(String name) {
    return 'Suppléant actuel : $name.';
  }

  @override
  String get colleagueCode => 'Code d\'inscription du collègue';

  @override
  String get remove => 'Retirer';

  @override
  String get save => 'Enregistrer';

  @override
  String get enterFullName => 'Veuillez saisir votre nom complet.';

  @override
  String get enterEmail => 'Veuillez saisir votre adresse e-mail.';

  @override
  String get passwordTooShort =>
      'Veuillez choisir un mot de passe d\'au moins 6 caractères.';

  @override
  String get codeNotRecognisedSignup =>
      'Ce code n\'a pas été reconnu. Vérifiez-le, ou videz le champ et rattachez-vous à votre clinicien plus tard.';

  @override
  String get acceptTermsFirst =>
      'Veuillez lire et accepter les conditions d\'utilisation pour créer votre compte.';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get joinCareTeam => 'Rejoignez votre équipe soignante';

  @override
  String get joinCareTeamNote =>
      'Créez votre compte pour commencer à enregistrer vos mesures. Vous pouvez vous rattacher à un clinicien maintenant ou plus tard.';

  @override
  String get fullName => 'Nom complet';

  @override
  String get fullNameHint => 'ex. Jean Mbarga';

  @override
  String get emailUseNote =>
      'Utilisez une adresse que vous consultez : nous y envoyons un lien de confirmation, et c\'est par elle que vous choisirez un nouveau mot de passe si vous oubliez le vôtre.';

  @override
  String get passwordHint => 'Au moins 6 caractères';

  @override
  String get clinicianCode => 'Code du clinicien';

  @override
  String get optional => '(facultatif)';

  @override
  String get clinicianCodeNote =>
      'Votre médecin vous en a donné un ? Saisissez-le pour vous rattacher tout de suite. Vous pouvez aussi passer cette étape et vous rattacher plus tard depuis votre profil.';

  @override
  String get clinicianCodeHint => 'ex. MBARGA-4F7K';

  @override
  String get haveAccountSignIn => 'Vous avez déjà un compte ? Connectez-vous';

  @override
  String get clinicianAccountsNote =>
      'Les comptes des cliniciens sont créés par l\'administrateur, pas ici.';

  @override
  String get checkingCode => 'Vérification du code…';

  @override
  String willBeLinkedTo(String name) {
    return 'Vous serez rattaché à $name';
  }

  @override
  String get codeNotRecognised => 'Code non reconnu';

  @override
  String get acceptTermsTick =>
      'J\'ai lu et j\'accepte les conditions d\'utilisation et la politique de confidentialité.';

  @override
  String get readTheTerms => 'Lire les conditions';

  @override
  String get researchTick =>
      'Facultatif : mes données, sans mon nom, mes coordonnées, ma photo ni mes messages, peuvent servir à la recherche médicale. Mes soins restent les mêmes si je refuse, et je peux changer d\'avis plus tard dans mon profil.';

  @override
  String get emailConfirmed => 'Adresse e-mail confirmée. Merci.';

  @override
  String get emailNotConfirmedYet =>
      'Pas encore confirmée. Ouvrez le lien de l\'e-mail, puis appuyez de nouveau sur ce bouton.';

  @override
  String get emailSentCheckSpam =>
      'E-mail envoyé. Il peut mettre quelques minutes à arriver ; regardez aussi dans le dossier spam.';

  @override
  String get emailSentRecently =>
      'Un e-mail vient d\'être envoyé. Veuillez patienter quelques minutes avant de redemander.';

  @override
  String get yourAddress => 'votre adresse';

  @override
  String get confirmEmailTitle => 'Confirmez votre adresse e-mail';

  @override
  String confirmEmailBody(String email) {
    return 'Nous avons envoyé un lien à $email. Ouvrez-le pour confirmer l\'adresse : c\'est le seul moyen de choisir un nouveau mot de passe si vous oubliez le vôtre.';
  }

  @override
  String get sendItAgain => 'Renvoyer';

  @override
  String get iveConfirmedIt => 'C\'est confirmé';

  @override
  String get yourClinician => 'Votre clinicien';

  @override
  String get clinicianCodeNotRecognised =>
      'Ce code de clinicien n\'a pas été reconnu. Vérifiez-le auprès de votre médecin, ou laissez le champ vide et rattachez-vous plus tard.';

  @override
  String accountNotSetUp(String error) {
    return 'Votre compte n\'a pas pu être créé. Veuillez réessayer. ($error)';
  }

  @override
  String get mustBeSignedIn => 'Vous devez être connecté pour faire cela.';

  @override
  String get alreadyConnected =>
      'Votre compte est déjà rattaché à un clinicien. Contactez votre équipe soignante s\'il faut le changer.';

  @override
  String get codeNotRecognisedCheck =>
      'Ce code n\'a pas été reconnu. Veuillez le vérifier auprès de votre médecin.';

  @override
  String couldNotConnect(String error) {
    return 'Impossible de vous rattacher à ce clinicien. ($error)';
  }

  @override
  String get wrongCredentials => 'E-mail ou mot de passe incorrect.';

  @override
  String get invalidEmail => 'Cette adresse e-mail ne semble pas valide.';

  @override
  String get emailInUse =>
      'Un compte existe déjà pour cette adresse. Essayez de vous connecter.';

  @override
  String get accountDisabled => 'Ce compte a été désactivé.';

  @override
  String get tooManyAttempts =>
      'Trop de tentatives — veuillez patienter un instant puis réessayer.';

  @override
  String get noInternet => 'Pas de connexion Internet.';

  @override
  String signInFailed(String code) {
    return 'Échec de la connexion ($code).';
  }

  @override
  String get somethingWentWrong =>
      'Un problème est survenu. Veuillez réessayer.';

  @override
  String get confirmClinician => 'Confirmez votre clinicien';

  @override
  String confirmClinicianBody(String name) {
    return 'Vous serez rattaché à $name, qui pourra voir les mesures que vous enregistrez.\n\nCe choix ne peut plus être modifié depuis l\'application — contactez votre équipe soignante s\'il faut le corriger.';
  }

  @override
  String get connect => 'Se rattacher';

  @override
  String connectedTo(String name) {
    return 'Rattaché à $name';
  }

  @override
  String get connectToClinician => 'Se rattacher à votre clinicien';

  @override
  String get enterClinicianCode => 'Saisissez le code de votre clinicien';

  @override
  String get askDoctorForCode =>
      'Demandez son code à votre médecin. Il ressemble à MBARGA-4F7K.';

  @override
  String get noCodeYetNote =>
      'Pas encore de code ? Vous pouvez continuer à enregistrer vos mesures sans code. Elles sont conservées dans votre compte et votre clinicien les verra dès que vous serez rattaché.';

  @override
  String get logAReading => 'Nouvelle mesure';

  @override
  String get navHome => 'Accueil';

  @override
  String get navHistory => 'Historique';

  @override
  String get navMessages => 'Messages';

  @override
  String get navProfile => 'Profil';

  @override
  String get goodMorning => 'Bonjour,';

  @override
  String get goodAfternoon => 'Bonjour,';

  @override
  String get goodEvening => 'Bonsoir,';

  @override
  String get alertBpRed =>
      'Tension ou pouls hors limites — contactez votre centre de santé aujourd\'hui';

  @override
  String get alertGlucoseRed =>
      'Glycémie hors limites — contactez votre centre de santé aujourd\'hui';

  @override
  String get alertBpYellow =>
      'Tension au-dessus de votre objectif à domicile — voir le contrôle sur 7 jours ci-dessous';

  @override
  String get alertGlucoseYellow =>
      'Glycémie au-dessus de votre objectif — voir le contrôle sur une journée ci-dessous';

  @override
  String readingsPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count mesures sont enregistrées sur votre téléphone et seront envoyées dès que vous serez en ligne.',
      one:
          '1 mesure est enregistrée sur votre téléphone et sera envoyée dès que vous serez en ligne.',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(int n) {
    return 'il y a $n min';
  }

  @override
  String hoursAgo(int n) {
    return 'il y a $n h';
  }

  @override
  String daysAgo(int n) {
    return 'il y a $n j';
  }

  @override
  String todayAt(String time) {
    return 'Aujourd\'hui, $time';
  }

  @override
  String yesterdayAt(String time) {
    return 'Hier, $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date, $time';
  }

  @override
  String get bloodPressure => 'Tension artérielle';

  @override
  String get bloodGlucose => 'Glycémie';

  @override
  String get pulse => 'Pouls';

  @override
  String get camera => 'caméra';

  @override
  String get lastReading => 'Dernière mesure';

  @override
  String get noneYet => 'aucune';

  @override
  String get recentReadings => 'Mesures récentes';

  @override
  String get noReadingsLoggedYet => 'Aucune mesure enregistrée pour l\'instant';

  @override
  String get noValuesRecorded => 'Aucune valeur enregistrée';

  @override
  String get levelGreen => 'Vert';

  @override
  String get levelYellow => 'Jaune';

  @override
  String get levelRed => 'Rouge';

  @override
  String get notMeasured => 'Non mesuré';

  @override
  String get ctxFasting => 'À jeun (avant le petit-déjeuner)';

  @override
  String get ctxBeforeMeal => 'Avant un repas';

  @override
  String get ctxAfterMeal => 'Environ 90 minutes après un repas';

  @override
  String get ctxAfterMedication => 'Après la prise de médicaments';

  @override
  String get ctxAfterExercise => 'Après un effort physique';

  @override
  String get ctxRandom => 'Autre / je ne sais pas';

  @override
  String bpInvalid(String which) {
    return 'Veuillez saisir des valeurs de tension valides$which.';
  }

  @override
  String sbpOutOfRange(int value, String which, int min, int max) {
    return 'La systolique $value$which est hors de la plage plausible ($min–$max mmHg). Veuillez vérifier la mesure.';
  }

  @override
  String dbpOutOfRange(int value, String which, int min, int max) {
    return 'La diastolique $value$which est hors de la plage plausible ($min–$max mmHg). Veuillez vérifier la mesure.';
  }

  @override
  String pulsePressureTooLow(int sbp, int gap, int dbp, String which) {
    return 'La systolique ($sbp) doit dépasser la diastolique ($dbp) d\'au moins $gap$which. Veuillez vérifier la mesure.';
  }

  @override
  String hrInvalid(String which) {
    return 'Veuillez saisir un pouls valide$which.';
  }

  @override
  String hrOutOfRange(int value, String which, int min, int max) {
    return 'Le pouls $value$which est hors de la plage plausible ($min–$max bpm). Veuillez vérifier la mesure.';
  }

  @override
  String get readingInFuture =>
      'L\'heure de la mesure ne peut pas être dans le futur.';

  @override
  String backdateLimit(int days) {
    return 'Une mesure peut être datée au plus de $days jours en arrière.';
  }

  @override
  String whichReading(int n) {
    return ' (mesure $n)';
  }

  @override
  String get glucoseInvalid => 'Veuillez saisir une valeur de glycémie valide.';

  @override
  String glucoseOutOfRange(String value, String min, String max) {
    return 'La glycémie $value est hors de la plage plausible ($min–$max mmol/L). Vérifiez l\'unité — cette application utilise les mmol/L, pas les mg/dL.';
  }

  @override
  String get glucoseNeedsContext =>
      'Indiquez quand la glycémie a été mesurée : votre objectif dépend du repas.';

  @override
  String get againstHomeTargets => 'Par rapport à vos objectifs à domicile';

  @override
  String previewBp(String sbp, String dbp) {
    return 'TA : $sbp/$dbp mmHg';
  }

  @override
  String previewGlucoseNoContext(String value) {
    return 'Glycémie : $value mmol/L. Choisissez le contexte de la mesure ci-dessous.';
  }

  @override
  String previewGlucose(String value) {
    return 'Glycémie : $value mmol/L';
  }

  @override
  String readingRejected(String error) {
    return 'Une mesure n\'a pas été acceptée par le serveur : $error';
  }

  @override
  String get outOfRangeTitle => 'Cette mesure est hors limites';

  @override
  String get iUnderstand => 'J\'ai compris';

  @override
  String get readingSavedOffline =>
      'Mesure enregistrée sur votre téléphone. Elle sera envoyée dès que vous serez en ligne.';

  @override
  String get readingSaved => 'Mesure enregistrée.';

  @override
  String get correctAReading => 'Corriger une mesure';

  @override
  String get logAReadingTitle => 'Nouvelle mesure';

  @override
  String get measurementType => 'Type de mesure';

  @override
  String get whenTaken => 'Quand a-t-elle été prise ?';

  @override
  String readingNumber(int n) {
    return 'Mesure $n';
  }

  @override
  String get reading2Kept => 'Mesure 2 — conservée';

  @override
  String get bpMmHg => 'Tension artérielle (mmHg)';

  @override
  String get unitsNote => 'Tensions en mmHg, pouls en battements par minute.';

  @override
  String get glucoseMmol => 'Glycémie (mmol/L)';

  @override
  String example(String value) {
    return 'ex. $value';
  }

  @override
  String get glucoseExample => '6,1';

  @override
  String get glucose => 'Glycémie';

  @override
  String get measurementContext => 'Contexte de la mesure';

  @override
  String get notesOptional => 'Notes (facultatif)';

  @override
  String get notesHint => 'ex. Prise après les médicaments du matin...';

  @override
  String get saveCorrection => 'Enregistrer la correction';

  @override
  String get saveReading => 'Enregistrer la mesure';

  @override
  String get correctThisReading => 'Corriger cette mesure';

  @override
  String get enterYourReading => 'Saisissez votre mesure';

  @override
  String get correctionNote =>
      'Les valeurs corrigées remplacent les anciennes sur vos écrans. L\'ancienne saisie reste dans votre dossier, marquée comme corrigée, pour que votre clinicien voie les deux.';

  @override
  String get entryNote =>
      'Saisissez les valeurs affichées par votre tensiomètre ou votre glucomètre. Pour la tension, asseyez-vous et reposez-vous cinq minutes, puis prenez deux mesures à une minute d\'intervalle : c\'est la seconde qui est conservée.';

  @override
  String get pulseCameraOptional =>
      'Pouls avec la caméra du téléphone (facultatif)';

  @override
  String pulseByCamera(int bpm) {
    return 'Pouls par caméra : $bpm bpm';
  }

  @override
  String get cameraPulseNote =>
      'Juste après la mesure de votre tensiomètre, vous pouvez aussi mesurer votre pouls avec la caméra et le flash. C\'est à titre indicatif : les alertes utilisent les valeurs de votre tensiomètre.';

  @override
  String get cameraPulseInfo =>
      'À titre indicatif, à côté du pouls de votre tensiomètre.';

  @override
  String get measure => 'Mesurer';

  @override
  String get measureAgain => 'Mesurer à nouveau';

  @override
  String get now => 'Maintenant';

  @override
  String get earlier => 'Plus tôt…';

  @override
  String get twoBpReadings => 'Deux mesures de tension';

  @override
  String get twoBpNote =>
      'À une minute d\'intervalle ; la seconde est conservée.';

  @override
  String get systolic => 'Systolique';

  @override
  String get diastolic => 'Diastolique';

  @override
  String get pulseOptional => 'Pouls (facultatif)';

  @override
  String get measureBoth => 'Les deux';

  @override
  String get measureBp => 'Tension';

  @override
  String get contextRequired => 'Choisir (obligatoire pour la glycémie)';

  @override
  String get optionalWord => 'Facultatif';

  @override
  String get filterAll => 'Toutes';

  @override
  String get readingHistory => 'Historique des mesures';

  @override
  String get readingsTab => 'Mesures';

  @override
  String get summaryTab => 'Synthèse';

  @override
  String get historyEmptyNote =>
      'Vos mesures apparaîtront ici dès que vous aurez enregistré la première. Appuyez sur le bouton + de l\'écran d\'accueil pour commencer.';

  @override
  String get noReadingsMatch => 'Aucune mesure ne correspond à ce filtre';

  @override
  String get noReadingsMatchNote =>
      'Essayez un autre filtre pour voir le reste de votre historique.';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get yesterday => 'Hier';

  @override
  String get tagPending =>
      'enregistrée sur votre téléphone, pas encore envoyée';

  @override
  String get tagSecondOfTwo => 'seconde de deux mesures';

  @override
  String get tagPulseCamera => 'pouls par la caméra du téléphone';

  @override
  String tagPulseCameraValue(int bpm) {
    return 'pouls par la caméra du téléphone $bpm';
  }

  @override
  String get tagCorrected => 'saisie corrigée';

  @override
  String get tagEnteredLater => 'saisie après coup';

  @override
  String get correct => 'Corriger';

  @override
  String get tagFasting => 'à jeun';

  @override
  String get tagBeforeMeal => 'avant un repas';

  @override
  String get tagAfterMeal => 'après un repas';

  @override
  String get tagAfterMedication => 'après les médicaments';

  @override
  String get tagAfterExercise => 'après un effort';

  @override
  String get tagOtherTime => 'autre moment';

  @override
  String get nothingToSummarise => 'Rien à synthétiser pour l\'instant';

  @override
  String get nothingToSummariseNote =>
      'Après quelques mesures, vos moyennes et vos tendances apparaîtront ici.';

  @override
  String get avgBloodPressure => 'Tension moyenne';

  @override
  String get avgGlucose => 'Glycémie moyenne';

  @override
  String get totalReadings => 'Nombre de mesures';

  @override
  String readingsLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mesures enregistrées',
      one: 'mesure enregistrée',
    );
    return '$_temp0';
  }

  @override
  String get readingDistribution => 'Répartition des mesures';

  @override
  String get insights => 'Observations';

  @override
  String insightHighShare(int percent) {
    return '$percent % de vos mesures étaient au-dessus de votre objectif à domicile ou hors limites.';
  }

  @override
  String get insightAllInTarget =>
      'Jusqu\'ici, toutes vos mesures sont dans vos objectifs à domicile.';

  @override
  String get insightLogBoth =>
      'Enregistrer la tension et la glycémie ensemble donne le plus d\'informations à votre score de risque.';

  @override
  String get insightFourDays =>
      'Votre niveau de risque est calculé à partir de vos mesures des quatre derniers jours.';

  @override
  String get instructionRed =>
      'Contactez votre centre de santé aujourd\'hui. En cas de douleur dans la poitrine, d\'essoufflement, de faiblesse d\'un côté du corps ou de confusion, allez à l\'hôpital immédiatement.';

  @override
  String get instructionYellow =>
      'Au-dessus de votre objectif à domicile. Mesurez de nouveau comme indiqué dans le contrôle ci-dessous ; votre clinicien examinera le résultat.';

  @override
  String get conditionHaemodynamic => 'Tension / pouls';

  @override
  String get noData => 'Pas de données';

  @override
  String get noReadingFourDays =>
      'Aucune mesure ces quatre derniers jours — enregistrez une mesure pour voir votre niveau.';

  @override
  String get riskTier => 'Niveau de risque';

  @override
  String get yourLevel => 'Votre niveau';

  @override
  String triageClinician(String level) {
    return 'Triage à domicile des dernières mesures : $level';
  }

  @override
  String get profileOffClinician => ' ; profil de vérification hors objectif';

  @override
  String triagePatient(String level) {
    return 'Vos dernières mesures par rapport à vos objectifs à domicile : $level';
  }

  @override
  String get profileOffPatient =>
      ' ; votre contrôle est au-dessus de l\'objectif';

  @override
  String get higherRiskThanLast =>
      'Vos mesures récentes suggèrent un risque plus élevé que la dernière valeur seule.';

  @override
  String conditionProbability(
    String condition,
    String percent,
    String tier,
    String model,
  ) {
    return '$condition : probabilité calibrée de $percent % d\'une valeur élevée ou critique à la prochaine mesure ($tier ; $model)';
  }

  @override
  String stateChangeLine(String value, String measure) {
    return 'Changement d\'état, dernières 24 h par rapport aux trois jours précédents : $value ($measure)';
  }

  @override
  String get sourceOnlineClinician =>
      'Modèle de risque (en ligne) combiné au triage à domicile ; le modèle peut relever le niveau, jamais l\'abaisser.';

  @override
  String get sourceOnlinePatient =>
      'Vérifié avec vos mesures et le modèle de risque.';

  @override
  String sourceOfflineClinician(String reason) {
    return 'Triage à domicile seul ($reason).';
  }

  @override
  String get offline => 'hors ligne';

  @override
  String get sourceOfflinePatient =>
      'Vérifié sur votre téléphone à partir de vos mesures.';

  @override
  String get provisionalCutpoints =>
      'Les seuils de niveau du modèle sont provisoires jusqu\'à leur fixation avec le clinicien.';

  @override
  String get evolution => 'Évolution';

  @override
  String get evolutionNote =>
      'Dernières 24 heures comparées aux trois jours précédents';

  @override
  String get evolutionEmpty =>
      'Pas encore assez de mesures : enregistrez des mesures sur plusieurs jours pour voir leur évolution.';

  @override
  String get stable => 'stable';

  @override
  String get trendTitle => 'Tendance de la systolique — 14 derniers jours';

  @override
  String get homeTargetBadge => 'Objectif à domicile < 135/85';

  @override
  String get noBpIn14Days => 'Aucune mesure de tension ces 14 derniers jours';

  @override
  String get greenBandNote =>
      'Bande verte : votre objectif à domicile pour le chiffre du haut, de 110 à 134 mmHg (avec le chiffre du bas sous 85). Garder votre tension dans cette zone diminue le risque d\'AVC et de maladie cardiaque.';

  @override
  String get routineNote =>
      'Rythme habituel : la tension deux fois par semaine, matin et soir, avec deux mesures à chaque fois ; la glycémie une fois par semaine, à jeun et 90 minutes après le déjeuner. Mesurez plus souvent quand l\'application demande un contrôle.';

  @override
  String get actionNone => 'Aucun changement nécessaire';

  @override
  String get actionAdvice => 'Conseil de votre clinicien';

  @override
  String get actionTreatmentChange =>
      'Votre clinicien a ajusté votre traitement';

  @override
  String get actionConsultation => 'Votre clinicien souhaite vous voir';

  @override
  String get actionReferral =>
      'Vous êtes orienté vers une prise en charge complémentaire';

  @override
  String get reviewed => 'Examinée';

  @override
  String get fromYourClinician => 'De votre clinicien';

  @override
  String alertReviewed(String date, String reviewed) {
    return 'Alerte du $date, examinée le $reviewed';
  }

  @override
  String get sourceRule => 'Règle des recommandations';

  @override
  String get sourceModel => 'Modèle de risque';

  @override
  String get sourceNonTransmission => 'Aucune mesure reçue';

  @override
  String get verdictConfirmed => 'Vraie alerte';

  @override
  String get verdictNotSignificant => 'Fausse alerte';

  @override
  String get verdictUncertain => 'Incertain';

  @override
  String get clinicalActionNone => 'Aucune action';

  @override
  String get clinicalActionAdvice => 'Conseil';

  @override
  String get clinicalActionTreatment => 'Changement de dose ou de médicament';

  @override
  String get clinicalActionConsultation => 'Consultation';

  @override
  String get clinicalActionReferral => 'Orientation';

  @override
  String checkupPeriodSuffix(int days) {
    return ' (délai de suivi $days jours)';
  }

  @override
  String noReadingSince(String date, String period) {
    return 'Aucune mesure depuis le $date$period';
  }

  @override
  String get noReadingInPeriod => 'Aucune mesure dans le délai de suivi';

  @override
  String noReadingForDays(int days) {
    return 'Aucune mesure depuis plus de $days jours';
  }

  @override
  String bpProfileOff(String sbp, String dbp, String readings, String days) {
    return 'Profil sur 7 jours hors objectif : moyenne $sbp/$dbp mmHg sur $readings mesures, $days jours';
  }

  @override
  String glucoseProfileOff(String before, String after) {
    return 'Profil glycémique hors objectif : moyenne $before avant et $after mmol/L après les repas';
  }

  @override
  String triggerPulse(String value) {
    return 'pouls $value bpm';
  }

  @override
  String triggerGlucose(String value) {
    return 'glycémie $value mmol/L';
  }

  @override
  String get trendRising => 'en hausse';

  @override
  String get trendFalling => 'en baisse';

  @override
  String get trendTooFew => 'trop peu de mesures';

  @override
  String get escalated => 'Transmise';

  @override
  String get neverReviewed => 'jamais examiné';

  @override
  String daysSinceReview(int days) {
    return '$days j depuis le dernier examen';
  }

  @override
  String get escalatedToYou =>
      'Transmise à vous comme suppléant : patient d\'un autre clinicien';

  @override
  String trendLine(String sbp, String glucose) {
    return 'Tendance sur 14 jours : systolique $sbp, glycémie $glucose';
  }

  @override
  String thresholdsLine(String version) {
    return 'Seuils $version';
  }

  @override
  String modelSuffix(String version) {
    return ' · modèle $version';
  }

  @override
  String probabilitySuffix(String percent) {
    return ' · P(alerte) calibrée $percent %';
  }

  @override
  String get verdict => 'Verdict';

  @override
  String get eventOpen => 'Ouverte';

  @override
  String reviewedSuffix(String date) {
    return ' · examinée le $date';
  }

  @override
  String verdictNotSaved(String error) {
    return 'Impossible d\'enregistrer le verdict : $error';
  }

  @override
  String get actionTaken => 'Action prise';

  @override
  String get verdictCommentHint =>
      'Commentaire (facultatif) — sert de note clinique';

  @override
  String get sendCommentToPatient => 'Envoyer le commentaire au patient';

  @override
  String get saving => 'Enregistrement…';

  @override
  String get closeAlert => 'Clore l\'alerte';

  @override
  String get ageNotRecorded => 'âge non renseigné';

  @override
  String ageBand(int low, int high) {
    return '$low–$high ans';
  }

  @override
  String get messagePatient => 'Écrire au patient';

  @override
  String get readingHistoryTitle => 'Historique des mesures';

  @override
  String get noClinicalInfo =>
      'Aucune information clinique enregistrée pour ce patient pour l\'instant.';

  @override
  String get conditions => 'Pathologies';

  @override
  String get medications => 'Traitements';

  @override
  String readingsNotLoaded(String error) {
    return 'Impossible de charger les mesures.\n$error';
  }

  @override
  String get patientNoReadings =>
      'Ce patient n\'a encore enregistré aucune mesure.';

  @override
  String get provReplaced => 'remplacée par une correction';

  @override
  String get provCorrection => 'correction d\'une saisie antérieure';

  @override
  String provSecondOfTwo(String first) {
    return 'seconde de deux mesures (première $first)';
  }

  @override
  String provEntered(String date) {
    return 'saisie le $date';
  }

  @override
  String provQuality(String flag) {
    return 'contrôle qualité : $flag';
  }

  @override
  String get bpmByCamera => 'bpm par la caméra du téléphone';

  @override
  String get checkupPeriod => 'Délai de suivi';

  @override
  String periodDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get currentSuffix => '  (actuel)';

  @override
  String get alertsAndVerdicts => 'Alertes et verdicts';

  @override
  String checkupEvery(int days) {
    return 'Suivi tous les $days j';
  }

  @override
  String get defaultSuffix => ' (par défaut)';

  @override
  String alertsNotLoaded(String error) {
    return 'Impossible de charger les alertes : $error';
  }

  @override
  String get noAlertForPatient => 'Aucune alerte enregistrée pour ce patient.';

  @override
  String get noClinicianWithCode => 'Aucun clinicien n\'a ce code.';

  @override
  String get ownCode => 'C\'est votre propre code.';

  @override
  String get enterYourName => 'Veuillez saisir votre nom.';

  @override
  String get ageRange => 'Veuillez saisir un âge entre 1 et 120.';

  @override
  String get profileUpdated => 'Profil mis à jour';

  @override
  String get editProfileTitle => 'Modifier le profil';

  @override
  String get aboutYou => 'Vous';

  @override
  String get age => 'Âge';

  @override
  String get sex => 'Sexe';

  @override
  String get bloodType => 'Groupe sanguin';

  @override
  String get medical => 'Médical';

  @override
  String get conditionsHint =>
      'Une par ligne\nex. Hypertension\nDiabète de type 2';

  @override
  String get currentMedicationsField => 'Traitements en cours';

  @override
  String get medicationsHint => 'Un par ligne\nex. Amlodipine 5 mg';

  @override
  String get emergencyContact => 'Contact d\'urgence';

  @override
  String get saveChanges => 'Enregistrer';

  @override
  String get managedByCareTeam => 'Géré par votre équipe soignante';

  @override
  String get accountType => 'Type de compte';

  @override
  String get patient => 'Patient';

  @override
  String get assignedClinician => 'Clinicien attribué';

  @override
  String get linked => 'Rattaché';

  @override
  String get notSet => 'Non renseigné';

  @override
  String get noBackCamera =>
      'Ce téléphone n\'a pas de caméra arrière pour mesurer le pouls.';

  @override
  String cameraNotStarted(String error) {
    return 'La caméra n\'a pas pu démarrer : $error';
  }

  @override
  String get cameraNotAllowed =>
      'TeleMonitor n\'est pas autorisé à utiliser la caméra. Autorisez-le dans les réglages du téléphone (Applications, TeleMonitor, Autorisations), puis réessayez.';

  @override
  String cameraNotStartedCode(String code) {
    return 'La caméra n\'a pas pu démarrer ($code).';
  }

  @override
  String get pulseWithCamera => 'Pouls avec la caméra';

  @override
  String get noFlash =>
      'Le flash n\'a pas pu s\'allumer : mesurez près d\'une lumière vive.';

  @override
  String get pulseHowTo =>
      'Restez assis. Couvrez la caméra arrière et le flash avec le bout de votre index, sans appuyer, et restez immobile environ 20 secondes. Le flash éclaire votre doigt et la caméra suit le sang qu\'apporte chaque battement du cœur. Aucune photo ni vidéo n\'est conservée.';

  @override
  String get pulseFingerMoved =>
      'Votre doigt a bougé : la mesure recommence. Couvrez la caméra et le flash.';

  @override
  String get pulseCover =>
      'Couvrez la caméra et le flash avec le bout du doigt.';

  @override
  String get pulseStarting => 'Démarrage de la caméra…';

  @override
  String get pulseFingerDetected => 'Doigt détecté. Restez immobile…';

  @override
  String get pulseMeasuring =>
      'Mesure en cours. Restez immobile et respirez normalement.';

  @override
  String get pulseResultNote =>
      'Mesuré avec la caméra du téléphone. Il est montré à vous et à votre clinicien à titre indicatif : le pouls de votre tensiomètre reste la référence, et les alertes utilisent les mesures de votre tensiomètre.';

  @override
  String get pulseVeryLow =>
      'Ce pouls est très bas. Asseyez-vous, reposez-vous cinq minutes et mesurez de nouveau ; si votre tensiomètre affiche un pouls, saisissez-le aussi. Si vous vous sentez mal (douleur dans la poitrine, essoufflement, malaise), allez sans attendre au centre de santé le plus proche.';

  @override
  String get pulseVeryHigh =>
      'Ce pouls est très élevé. Asseyez-vous, reposez-vous cinq minutes et mesurez de nouveau ; si votre tensiomètre affiche un pouls, saisissez-le aussi. Si vous vous sentez mal (douleur dans la poitrine, essoufflement, malaise), allez sans attendre au centre de santé le plus proche.';

  @override
  String get useThisValue => 'Utiliser cette valeur';

  @override
  String get pulseFailed =>
      'Le signal n\'était pas assez stable pour donner un pouls. Gardez le doigt immobile et appuyez légèrement : appuyer fort bloque le sang. Des doigts froids donnent un signal faible ; réchauffez d\'abord votre main. Si cela échoue encore, utilisez le pouls de votre tensiomètre.';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String photoOf(String name) {
    return 'Photo de $name';
  }

  @override
  String get profilePhoto => 'Photo de profil';

  @override
  String get photoNoteClinician =>
      'Facultatif. Vos patients la voient à côté de vos messages et savent ainsi qui les suit.';

  @override
  String get photoNotePatient =>
      'Facultatif. Seuls vous et votre clinicien pouvez la voir ; elle aide votre clinicien à vous reconnaître au centre de santé. Vous pouvez la retirer à tout moment.';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get chooseFromGallery => 'Choisir dans la galerie';

  @override
  String get removePhoto => 'Retirer la photo';

  @override
  String get photoRemoved => 'Photo retirée.';

  @override
  String get photoSaved => 'Photo enregistrée.';

  @override
  String photoNotUpdated(String error) {
    return 'Impossible de mettre à jour la photo : $error';
  }

  @override
  String get notAnImage =>
      'Ce fichier n\'est pas une image lisible par l\'application.';

  @override
  String get photoTooLarge =>
      'Cette photo est trop lourde. Veuillez en choisir une autre.';

  @override
  String get noEnrolmentCode =>
      'Aucun code d\'inscription n\'a encore été attribué à votre compte. Contactez l\'administrateur du système — sans code, les patients ne peuvent pas s\'inscrire auprès de vous.';

  @override
  String get yourEnrolmentCode => 'Votre code d\'inscription';

  @override
  String get codeCopied => 'Code copié';

  @override
  String get copy => 'Copier';

  @override
  String get giveCodeNote =>
      'Donnez ce code à un patient pour qu\'il s\'inscrive et vous soit rattaché.';

  @override
  String get bpCheckTitle => 'Contrôle de la tension sur 7 jours';

  @override
  String get glucoseCheckTitle => 'Contrôle de la glycémie sur une journée';

  @override
  String get bpCheckHow =>
      'Chaque matin et chaque soir pendant 7 jours : asseyez-vous et reposez-vous 5 minutes, puis prenez deux mesures à une minute d\'intervalle et enregistrez-les toutes les deux.';

  @override
  String get glucoseCheckHow =>
      'Pendant une journée : avant et 90 minutes après chacun de vos trois repas (6 mesures). Choisissez « Avant un repas » ou « Environ 90 minutes après un repas » en enregistrant chacune.';

  @override
  String bpCheckProgress(int readings, int expected, String days, String date) {
    return '$readings mesures sur $expected · $days · jusqu\'au $date';
  }

  @override
  String glucoseCheckProgress(int before, int after, String date) {
    return 'Avant les repas : $before sur 3 · après les repas : $after sur 3 · jusqu\'au $date';
  }

  @override
  String bpCheckMean(String value) {
    return 'Moyenne $value mmHg (objectif sous 135/85)';
  }

  @override
  String meanBeforeMeals(String value) {
    return 'avant les repas : $value mmol/L (objectif 7 ou moins)';
  }

  @override
  String meanAfterMeals(String value) {
    return 'après les repas : $value mmol/L (objectif 10 ou moins)';
  }

  @override
  String averageOf(String value) {
    return 'Moyenne $value';
  }

  @override
  String joinedBySemicolon(String first, String second) {
    return '$first ; $second';
  }

  @override
  String get checkInProgressClinician => 'En cours.';

  @override
  String get checkOffTargetClinician =>
      'Hors objectif : téléconsultation (événement rouge dans la file).';

  @override
  String get checkOffTargetPatient =>
      'Votre moyenne est au-dessus de l\'objectif. Votre clinicien a le résultat ; contactez votre centre de santé.';

  @override
  String get checkOnTargetClinician => 'Dans l\'objectif.';

  @override
  String get checkOnTargetPatient =>
      'Votre moyenne est dans l\'objectif. Continuez à mesurer comme d\'habitude.';

  @override
  String get checkIncompleteClinician =>
      'Incomplet : trop peu de mesures pour conclure.';

  @override
  String get checkIncompletePatient =>
      'Pas assez de mesures pour conclure. Contactez votre centre de santé ou recommencez le contrôle.';

  @override
  String get inProgress => 'En cours';

  @override
  String get aboveTarget => 'Au-dessus de l\'objectif';

  @override
  String get onTarget => 'Dans l\'objectif';

  @override
  String get incomplete => 'Incomplet';

  @override
  String get noClinicianYet => 'Aucun clinicien rattaché pour l\'instant';

  @override
  String get noClinicianYetNote =>
      'Saisissez le code que vous donne votre médecin pour commencer à échanger avec lui.';

  @override
  String get connectToAClinician => 'Se rattacher à un clinicien';

  @override
  String couldNotSend(String error) {
    return 'Envoi impossible : $error';
  }

  @override
  String messagesNotLoaded(String error) {
    return 'Impossible de charger les messages.\n$error';
  }

  @override
  String get noMessagesYet =>
      'Aucun message pour l\'instant.\nCommencez la conversation ci-dessous.';

  @override
  String get typeAMessage => 'Écrivez un message...';

  @override
  String get presenceOffline => 'Hors ligne';

  @override
  String get presenceOnline => 'En ligne';

  @override
  String lastSeenMinutes(int n) {
    return 'Vu il y a $n min';
  }

  @override
  String lastSeenHours(int n) {
    return 'Vu il y a $n h';
  }

  @override
  String get lastSeenYesterday => 'Vu hier';

  @override
  String lastSeenDays(int n) {
    return 'Vu il y a $n jours';
  }

  @override
  String get noClinicianConnected => 'Aucun clinicien rattaché';

  @override
  String get noClinicianConnectedNote =>
      'Vous pouvez déjà enregistrer des mesures, mais personne ne les examine encore. Saisissez le code que vous donne votre médecin pour vous rattacher.';

  @override
  String get findCareNearYou => 'Trouver des soins près de vous';

  @override
  String get findHospitalNearYou => 'Trouver un hôpital près de vous';

  @override
  String get tapCategory =>
      'Appuyez sur une catégorie pour voir ce qui se trouve à proximité dans Google Maps.';

  @override
  String get careUrgentNote =>
      'Vos mesures récentes sont dans une zone qui demande de l\'attention. Si vous vous sentez mal, allez à l\'hôpital plutôt que d\'attendre votre prochain rendez-vous.';

  @override
  String get mapsNotOpened =>
      'Impossible d\'ouvrir Maps sur cet appareil. Recherchez « pharmacie près de moi » dans votre navigateur.';

  @override
  String get locationNote =>
      'TeleMonitor n\'accède pas à votre position et ne la conserve pas. La recherche est faite par Google Maps sur votre appareil.';

  @override
  String get carePharmacy => 'Pharmacie';

  @override
  String get careHospital => 'Hôpital';

  @override
  String get careClinic => 'Clinique / centre de santé';

  @override
  String get careLaboratory => 'Laboratoire';

  @override
  String get carePharmacyNote =>
      'Retirer des médicaments, ou faire contrôler votre tension — beaucoup de pharmacies le proposent.';

  @override
  String get careHospitalNote =>
      'Pour les soins urgents, ou quand vos mesures sont dans la zone élevée ou critique.';

  @override
  String get careClinicNote =>
      'Pour une consultation de routine ou une visite de suivi.';

  @override
  String get careLaboratoryNote =>
      'Pour la glycémie, l\'HbA1c et les autres analyses de laboratoire.';

  @override
  String get latestReadingNeedsAttention =>
      'Votre dernière mesure demande de l\'attention';

  @override
  String get careKinds => 'Pharmacies, cliniques, hôpitaux et laboratoires';

  @override
  String get assistantGreeting =>
      'Bonjour. Je peux vous expliquer vos mesures, répondre à des questions générales sur la tension artérielle et le diabète, et vous aider à savoir si quelque chose nécessite un médecin.\n\nJe ne peux pas donner de conseil sur les médicaments — seul votre clinicien peut le faire.';

  @override
  String get healthAssistant => 'Assistant santé';

  @override
  String get notYourDoctor => 'Automatique — ne remplace pas votre médecin';

  @override
  String get assistantDisclaimer =>
      'Informations générales uniquement. Il ne peut ni poser de diagnostic ni conseiller sur les médicaments. En cas d\'urgence, allez dans un établissement de santé.';

  @override
  String get askHealthQuestion => 'Posez une question de santé...';

  @override
  String get askHealthAssistant => 'Interroger l\'assistant santé';

  @override
  String get understandReadings => 'Comprendre vos mesures et votre maladie';

  @override
  String get assistantOffline =>
      'L\'assistant a besoin d\'une connexion Internet. Vos mesures restent enregistrées et seront synchronisées dès votre retour en ligne.';

  @override
  String get assistantBusy =>
      'L\'assistant est occupé pour le moment. Veuillez réessayer dans quelques minutes.';

  @override
  String get assistantBlocked =>
      'Je ne peux pas répondre à cela. Si cela concerne votre santé, parlez-en à votre clinicien.';

  @override
  String get assistantError =>
      'Un problème est survenu en contactant l\'assistant. Veuillez réessayer.';

  @override
  String get suggestReadings => 'Que veulent dire mes dernières mesures ?';

  @override
  String get suggestDanger => 'Pourquoi l\'hypertension est-elle dangereuse ?';

  @override
  String get suggestFood => 'À quels aliments dois-je faire attention ?';

  @override
  String get suggestHowOften => 'À quelle fréquence dois-je mesurer ?';

  @override
  String get open => 'Ouvrir';

  @override
  String get riskServiceNotConfigured => 'service de risque non configuré';

  @override
  String get riskServiceUnreachable => 'service de risque injoignable';

  @override
  String get termsS1Title => 'Ce qu\'est TeleMonitor';

  @override
  String get termsS1P1 =>
      'TeleMonitor vous aide à suivre votre tension artérielle et votre glycémie à domicile avec votre clinicien. Vous saisissez vos mesures ; l\'application les compare à vos objectifs à domicile et votre clinicien examine les alertes.';

  @override
  String get termsS1P2 =>
      'TeleMonitor ne remplace pas une consultation et n\'est pas un service d\'urgence. Il ne modifie jamais votre traitement : seul votre clinicien le peut. Si vous vous sentez très mal, allez au centre de santé ou à l\'hôpital le plus proche sans attendre de réponse dans l\'application.';

  @override
  String get termsS2Title => 'Les informations conservées par l\'application';

  @override
  String get termsS2B1 => '• Votre compte : nom et adresse e-mail.';

  @override
  String get termsS2B2 =>
      '• Votre profil, si vous le remplissez : âge, sexe, taille, poids, pathologies, traitements, téléphone, contact d\'urgence et une photo facultative.';

  @override
  String get termsS2B3 =>
      '• Vos mesures (tension artérielle, pouls, glycémie, moment de la mesure et vos notes), les alertes qu\'elles déclenchent et l\'examen qu\'en fait votre clinicien.';

  @override
  String get termsS2B4 =>
      '• Si vous mesurez votre pouls avec la caméra du téléphone, le pouls obtenu : les images de la caméra sont lues sur le téléphone puis effacées aussitôt, jamais conservées ni envoyées.';

  @override
  String get termsS2B5 =>
      '• Les messages que vous échangez avec votre clinicien.';

  @override
  String get termsS2B6 =>
      '• Ce dont le service a besoin pour fonctionner : votre dernière utilisation de l\'application et l\'adresse servant à envoyer les notifications à votre téléphone.';

  @override
  String get termsS3Title => 'Qui peut les voir';

  @override
  String get termsS3B1 => '• Vous.';

  @override
  String get termsS3B2 =>
      '• Le clinicien auquel vous êtes rattaché, et le collègue qu\'il désigne pour le remplacer quand une alerte attend trop longtemps.';

  @override
  String get termsS3B3 =>
      '• L\'administrateur du système, uniquement pour assurer son fonctionnement.';

  @override
  String get termsS3P1 =>
      'Vos informations sont stockées sur les serveurs Google Firebase et circulent chiffrées. Des règles d\'accès ne laissent chacun voir que ce qu\'il est autorisé à voir.';

  @override
  String get termsS3P2 =>
      'Quand vous utilisez l\'assistant santé, votre question, votre âge, votre sexe, vos pathologies, vos traitements et vos mesures récentes sont envoyés au service Gemini de Google pour préparer la réponse, jamais votre nom ni vos coordonnées. Ne saisissez pas votre nom ni d\'autres informations personnelles dans l\'assistant.';

  @override
  String get termsS4Title => 'La recherche, seulement si vous êtes d\'accord';

  @override
  String get termsS4P1 =>
      'Si vous cochez la case recherche, vos informations peuvent aussi servir à la recherche médicale sur le suivi à domicile de l\'hypertension et du diabète, menée par le projet TeleMonitor du laboratoire GISDIA, École Nationale Supérieure Polytechnique de Douala (ENSPD), Université de Douala.';

  @override
  String get termsS4P2 =>
      'Avant toute utilisation, votre nom, votre e-mail, vos numéros de téléphone, votre contact d\'urgence, votre photo, vos messages et vos notes sont retirés, et votre compte est remplacé par un code. Les résultats ne sont publiés que sous forme de chiffres portant sur des groupes de patients, où personne ne peut être reconnu.';

  @override
  String get termsS4P3 =>
      'Refuser ne change rien à vos soins. Vous pouvez changer d\'avis à tout moment dans votre profil ; vos informations sont alors exclues des nouveaux extraits de recherche.';

  @override
  String get termsS5Title => 'Vos droits';

  @override
  String get termsS5P1 =>
      'En vertu de la loi n° 2024/017 du 23 décembre 2024 relative à la protection des données à caractère personnel au Cameroun, vous pouvez consulter vos informations (l\'application vous les montre), les faire corriger, retirer votre consentement à la recherche et demander la suppression de votre compte et de vos informations. Pour une suppression ou toute question, adressez-vous à votre clinicien ou à l\'administrateur.';

  @override
  String get termsS6Title => 'Protéger votre compte';

  @override
  String get termsS6P1 =>
      'Gardez votre mot de passe pour vous. Confirmez votre adresse e-mail : c\'est le seul moyen de choisir un nouveau mot de passe si vous oubliez le vôtre. Sur un téléphone partagé, déconnectez-vous quand vous avez terminé.';

  @override
  String get termsS7Title => 'Modification de ces conditions';

  @override
  String get termsS7P1 =>
      'Si ces conditions changent, l\'application vous montre la nouvelle version et vous demande de l\'accepter avant de continuer.';

  @override
  String termsVersionOf(String date) {
    return 'Version du $date';
  }

  @override
  String get updatedTerms => 'Conditions d\'utilisation mises à jour';

  @override
  String get termsChanged =>
      'Les conditions ont changé. Veuillez les lire et les accepter pour continuer.';

  @override
  String get readAndAcceptTerms =>
      'Veuillez lire les conditions d\'utilisation et les accepter pour continuer.';

  @override
  String get acceptAndContinue => 'Accepter et continuer';

  @override
  String messageNotSent(String error) {
    return 'Un message n\'a pas été envoyé : $error';
  }

  @override
  String verdictNotSavedServer(String error) {
    return 'Un verdict n\'a pas été enregistré : $error';
  }
}
