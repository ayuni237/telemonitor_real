// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageTitle => 'Language';

  @override
  String get languageNote =>
      'Notifications and emails come in this language too.';

  @override
  String get loginMissingFields => 'Please enter both email and password.';

  @override
  String get resetLinkSentGeneric =>
      'If an account exists for that address, a reset link has been sent. Check your inbox, and the spam folder too.';

  @override
  String get appTagline => 'Chronic Disease Telemonitoring';

  @override
  String get loginWelcome => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to your account';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get signIn => 'Sign In';

  @override
  String get or => 'or';

  @override
  String get createAccountLink => 'New patient? Create an account';

  @override
  String get sameLogin => 'Patients and clinicians use the same login';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetPasswordIntro =>
      'Enter the email address of your account and we will send you a link to choose a new password. No access to that email? Ask your clinician: the administrator can reset it.';

  @override
  String get cancel => 'Cancel';

  @override
  String get sendLink => 'Send link';

  @override
  String get noProfileTitle => 'No profile found for this account.';

  @override
  String noProfileBody(String uid) {
    return 'Add a Firestore document at users/$uid with an email, name, and role field to finish setting up this account.';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeFollowsDevice => 'Following your device setting.';

  @override
  String get themeAlwaysDark => 'Always dark, whatever your device is set to.';

  @override
  String get themeAlwaysLight =>
      'Always light, whatever your device is set to.';

  @override
  String get myProfile => 'My Profile';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get medicalConditions => 'Medical Conditions';

  @override
  String get currentMedications => 'Current Medications';

  @override
  String get physicalInfo => 'Physical Info';

  @override
  String get height => 'Height';

  @override
  String get weight => 'Weight';

  @override
  String get contact => 'Contact';

  @override
  String get phone => 'Phone';

  @override
  String get emergency => 'Emergency';

  @override
  String get account => 'Account';

  @override
  String get clinician => 'Clinician';

  @override
  String get assigned => 'Assigned';

  @override
  String get notYetAssigned => 'Not yet assigned';

  @override
  String get change => 'Change';

  @override
  String get termsAccepted => 'Accepted';

  @override
  String termsAcceptedOn(String date) {
    return 'Accepted $date';
  }

  @override
  String get privacyAndConsent => 'Privacy and consent';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String get read => 'Read';

  @override
  String get researchUseTitle => 'Use of my data for research';

  @override
  String get researchUseNote =>
      'Without your name, contact details, photo or messages. Your care is the same either way.';

  @override
  String get researchConsentGiven =>
      'Thank you. Your data, without your name or contact details, may be used for research.';

  @override
  String get researchConsentWithdrawn =>
      'Done. Your data will be left out of new research extracts.';

  @override
  String get savedOffline =>
      'Saved on the phone. It will be sent when you are back online.';

  @override
  String choiceNotSaved(String error) {
    return 'Could not save your choice: $error';
  }

  @override
  String resetLinkSentTo(String email) {
    return 'We sent a link to $email to choose a new password. Look in the spam folder too.';
  }

  @override
  String get changeProfilePhoto => 'Change profile photo';

  @override
  String ageYears(int age) {
    return '$age yrs';
  }

  @override
  String get sexMale => 'Male';

  @override
  String get sexFemale => 'Female';

  @override
  String get sexOther => 'Other';

  @override
  String get completeProfile => 'Complete your profile';

  @override
  String get completeProfileNote =>
      'Adding your conditions, medications and emergency contact helps your clinician interpret your readings.';

  @override
  String get addDetails => 'Add details';

  @override
  String get signOutButton => 'Sign Out';

  @override
  String get notificationsBlocked =>
      'Notifications are blocked on this phone. Allow them for TeleMonitor in the phone\'s settings (Apps, TeleMonitor, Notifications).';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsOn => 'On';

  @override
  String get notificationsTurnOn => 'Off: turn on';

  @override
  String get alternateRemoved => 'Alternate removed.';

  @override
  String alternateNamed(String name) {
    return '$name is now your alternate.';
  }

  @override
  String couldNotSave(String error) {
    return 'Could not save: $error';
  }

  @override
  String get conversationNotOpened => 'This conversation could not be opened.';

  @override
  String get myPatients => 'My Patients';

  @override
  String get myPhoto => 'My photo';

  @override
  String get alternateClinician => 'Alternate clinician';

  @override
  String queueTab(int count) {
    return 'Queue ($count)';
  }

  @override
  String get patientsTab => 'Patients';

  @override
  String get queueNotLoaded => 'Could not load the queue.';

  @override
  String get queueEmpty => 'No alert to review.';

  @override
  String get queueEmptyNote =>
      'Yellow and red readings, model alerts and patients who stopped sending readings appear here, the most urgent first.';

  @override
  String get patientsNotLoaded => 'Could not load patients.';

  @override
  String get noPatientsYet => 'No patients connected yet.';

  @override
  String get noPatientsYetNote =>
      'Share the code above with a patient so they can register and be linked to you.';

  @override
  String get noReadingsYet => 'No readings yet';

  @override
  String get readingLogged => 'Reading logged';

  @override
  String get noAlternate =>
      'No alternate named. Alerts you leave unreviewed are escalated to nobody.';

  @override
  String currentAlternate(String name) {
    return 'Current alternate: $name.';
  }

  @override
  String get colleagueCode => 'Colleague\'s enrolment code';

  @override
  String get remove => 'Remove';

  @override
  String get save => 'Save';

  @override
  String get enterFullName => 'Please enter your full name.';

  @override
  String get enterEmail => 'Please enter your email address.';

  @override
  String get passwordTooShort =>
      'Please choose a password of at least 6 characters.';

  @override
  String get codeNotRecognisedSignup =>
      'That code was not recognised. Check it, or clear the field and connect to your clinician later.';

  @override
  String get acceptTermsFirst =>
      'Please read and accept the terms of use to create your account.';

  @override
  String get createAccount => 'Create account';

  @override
  String get joinCareTeam => 'Join your care team';

  @override
  String get joinCareTeamNote =>
      'Create your account to start recording readings. You can connect to a clinician now or later.';

  @override
  String get fullName => 'Full name';

  @override
  String get fullNameHint => 'e.g. Jean Mbarga';

  @override
  String get emailUseNote =>
      'Use an address you can open: we send a link to confirm it, and it is how you set a new password if you forget yours.';

  @override
  String get passwordHint => 'At least 6 characters';

  @override
  String get clinicianCode => 'Clinician code';

  @override
  String get optional => '(optional)';

  @override
  String get clinicianCodeNote =>
      'Have one from your doctor? Enter it to connect straight away. You can also skip this and connect later from your profile.';

  @override
  String get clinicianCodeHint => 'e.g. MBARGA-4F7K';

  @override
  String get haveAccountSignIn => 'Already have an account? Sign in';

  @override
  String get clinicianAccountsNote =>
      'Clinician accounts are created by the administrator, not here.';

  @override
  String get checkingCode => 'Checking code…';

  @override
  String willBeLinkedTo(String name) {
    return 'You will be linked to $name';
  }

  @override
  String get codeNotRecognised => 'Code not recognised';

  @override
  String get acceptTermsTick =>
      'I have read and I accept the terms of use and the privacy notice.';

  @override
  String get readTheTerms => 'Read the terms';

  @override
  String get researchTick =>
      'Optional: my data, without my name, contact details, photo or messages, may be used for medical research. My care is the same if I say no, and I can change this later in my profile.';

  @override
  String get emailConfirmed => 'Email address confirmed. Thank you.';

  @override
  String get emailNotConfirmedYet =>
      'Not confirmed yet. Open the link in the email, then tap this button again.';

  @override
  String get emailSentCheckSpam =>
      'Email sent. It can take a few minutes; look in the spam folder too.';

  @override
  String get emailSentRecently =>
      'An email was sent a moment ago. Please wait a few minutes before asking again.';

  @override
  String get yourAddress => 'your address';

  @override
  String get confirmEmailTitle => 'Confirm your email address';

  @override
  String confirmEmailBody(String email) {
    return 'We sent a link to $email. Open it to confirm the address: it is the only way to set a new password if you forget yours.';
  }

  @override
  String get sendItAgain => 'Send it again';

  @override
  String get iveConfirmedIt => 'I\'ve confirmed it';

  @override
  String get yourClinician => 'Your clinician';

  @override
  String get clinicianCodeNotRecognised =>
      'That clinician code was not recognised. Check it with your doctor, or leave it blank and connect later.';

  @override
  String accountNotSetUp(String error) {
    return 'Your account could not be set up. Please try again. ($error)';
  }

  @override
  String get mustBeSignedIn => 'You must be signed in to do this.';

  @override
  String get alreadyConnected =>
      'Your account is already connected to a clinician. Contact your care team if this needs to change.';

  @override
  String get codeNotRecognisedCheck =>
      'That code was not recognised. Please check it with your doctor.';

  @override
  String couldNotConnect(String error) {
    return 'Could not connect to that clinician. ($error)';
  }

  @override
  String get wrongCredentials => 'Incorrect email or password.';

  @override
  String get invalidEmail => 'That email address doesn\'t look right.';

  @override
  String get emailInUse =>
      'An account already exists for that email. Try signing in.';

  @override
  String get accountDisabled => 'This account has been disabled.';

  @override
  String get tooManyAttempts =>
      'Too many attempts — please wait a moment and try again.';

  @override
  String get noInternet => 'No internet connection.';

  @override
  String signInFailed(String code) {
    return 'Sign-in failed ($code).';
  }

  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String get confirmClinician => 'Confirm your clinician';

  @override
  String confirmClinicianBody(String name) {
    return 'You will be connected to $name. They will be able to see the readings you record.\n\nThis cannot be changed from the app afterwards — contact your care team if you need it corrected.';
  }

  @override
  String get connect => 'Connect';

  @override
  String connectedTo(String name) {
    return 'Connected to $name';
  }

  @override
  String get connectToClinician => 'Connect to your clinician';

  @override
  String get enterClinicianCode => 'Enter your clinician code';

  @override
  String get askDoctorForCode =>
      'Ask your doctor for their code. It looks something like MBARGA-4F7K.';

  @override
  String get noCodeYetNote =>
      'Don\'t have a code yet? You can keep recording your readings without one. They are saved to your account and your clinician will see them from the day you connect.';

  @override
  String get logAReading => 'Log a reading';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get navMessages => 'Messages';

  @override
  String get navProfile => 'Profile';

  @override
  String get goodMorning => 'Good morning,';

  @override
  String get goodAfternoon => 'Good afternoon,';

  @override
  String get goodEvening => 'Good evening,';

  @override
  String get alertBpRed =>
      'Blood pressure or pulse out of range — contact your health centre today';

  @override
  String get alertGlucoseRed =>
      'Blood glucose out of range — contact your health centre today';

  @override
  String get alertBpYellow =>
      'Blood pressure above your home target — see the 7-day check below';

  @override
  String get alertGlucoseYellow =>
      'Blood glucose above your target — see the one-day check below';

  @override
  String readingsPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count readings are saved on your phone and will be sent when you are online.',
      one:
          '1 reading is saved on your phone and will be sent when you are online.',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String hoursAgo(int n) {
    return '$n h ago';
  }

  @override
  String daysAgo(int n) {
    return '$n d ago';
  }

  @override
  String todayAt(String time) {
    return 'Today, $time';
  }

  @override
  String yesterdayAt(String time) {
    return 'Yesterday, $time';
  }

  @override
  String dateAt(String date, String time) {
    return '$date, $time';
  }

  @override
  String get bloodPressure => 'Blood pressure';

  @override
  String get bloodGlucose => 'Blood glucose';

  @override
  String get pulse => 'Pulse';

  @override
  String get camera => 'camera';

  @override
  String get lastReading => 'Last reading';

  @override
  String get noneYet => 'none yet';

  @override
  String get recentReadings => 'Recent Readings';

  @override
  String get noReadingsLoggedYet => 'No readings logged yet';

  @override
  String get noValuesRecorded => 'No values recorded';

  @override
  String get levelGreen => 'Green';

  @override
  String get levelYellow => 'Yellow';

  @override
  String get levelRed => 'Red';

  @override
  String get notMeasured => 'Not measured';

  @override
  String get ctxFasting => 'Fasting (before breakfast)';

  @override
  String get ctxBeforeMeal => 'Before a meal';

  @override
  String get ctxAfterMeal => 'About 90 minutes after a meal';

  @override
  String get ctxAfterMedication => 'After medication';

  @override
  String get ctxAfterExercise => 'After exercise';

  @override
  String get ctxRandom => 'Other / not sure';

  @override
  String bpInvalid(String which) {
    return 'Please enter valid blood pressure values$which.';
  }

  @override
  String sbpOutOfRange(int value, String which, int min, int max) {
    return 'Systolic $value$which is outside the plausible range ($min–$max mmHg). Please re-check the reading.';
  }

  @override
  String dbpOutOfRange(int value, String which, int min, int max) {
    return 'Diastolic $value$which is outside the plausible range ($min–$max mmHg). Please re-check the reading.';
  }

  @override
  String pulsePressureTooLow(int sbp, int gap, int dbp, String which) {
    return 'Systolic ($sbp) should be at least $gap higher than diastolic ($dbp)$which. Please re-check the reading.';
  }

  @override
  String hrInvalid(String which) {
    return 'Please enter a valid heart rate$which.';
  }

  @override
  String hrOutOfRange(int value, String which, int min, int max) {
    return 'Heart rate $value$which is outside the plausible range ($min–$max bpm). Please re-check the reading.';
  }

  @override
  String get readingInFuture =>
      'The time of the reading cannot be in the future.';

  @override
  String backdateLimit(int days) {
    return 'A reading can be dated at most $days days back.';
  }

  @override
  String whichReading(int n) {
    return ' (reading $n)';
  }

  @override
  String get glucoseInvalid => 'Please enter a valid glucose value.';

  @override
  String glucoseOutOfRange(String value, String min, String max) {
    return 'Glucose $value is outside the plausible range ($min–$max mmol/L). Check your units — this app uses mmol/L, not mg/dL.';
  }

  @override
  String get glucoseNeedsContext =>
      'Choose when the glucose was measured: your target depends on the meal.';

  @override
  String get againstHomeTargets => 'Against your home targets';

  @override
  String previewBp(String sbp, String dbp) {
    return 'BP: $sbp/$dbp mmHg';
  }

  @override
  String previewGlucoseNoContext(String value) {
    return 'Glucose: $value mmol/L. Choose the measurement context below.';
  }

  @override
  String previewGlucose(String value) {
    return 'Glucose: $value mmol/L';
  }

  @override
  String readingRejected(String error) {
    return 'A reading was not accepted by the server: $error';
  }

  @override
  String get outOfRangeTitle => 'This reading is out of range';

  @override
  String get iUnderstand => 'I understand';

  @override
  String get readingSavedOffline =>
      'Reading saved on your phone. It will be sent when you are online.';

  @override
  String get readingSaved => 'Reading saved.';

  @override
  String get correctAReading => 'Correct a Reading';

  @override
  String get logAReadingTitle => 'Log a Reading';

  @override
  String get measurementType => 'Measurement type';

  @override
  String get whenTaken => 'When was it taken?';

  @override
  String readingNumber(int n) {
    return 'Reading $n';
  }

  @override
  String get reading2Kept => 'Reading 2 — kept';

  @override
  String get bpMmHg => 'Blood Pressure (mmHg)';

  @override
  String get unitsNote => 'Pressures in mmHg, pulse in beats per minute.';

  @override
  String get glucoseMmol => 'Blood Glucose (mmol/L)';

  @override
  String example(String value) {
    return 'e.g. $value';
  }

  @override
  String get glucoseExample => '6.1';

  @override
  String get glucose => 'Glucose';

  @override
  String get measurementContext => 'Measurement context';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get notesHint => 'e.g. Taken after morning medication...';

  @override
  String get saveCorrection => 'Save Correction';

  @override
  String get saveReading => 'Save Reading';

  @override
  String get correctThisReading => 'Correct this reading';

  @override
  String get enterYourReading => 'Enter your reading';

  @override
  String get correctionNote =>
      'Your corrected values replace the old ones on your screens. The old entry stays in your record, marked as corrected, so your clinician can see both.';

  @override
  String get entryNote =>
      'Type the values shown on your blood pressure monitor or glucometer. For blood pressure, sit and rest for five minutes, then take two readings one minute apart: the second is the one kept.';

  @override
  String get pulseCameraOptional => 'Pulse with the phone camera (optional)';

  @override
  String pulseByCamera(int bpm) {
    return 'Pulse by camera: $bpm bpm';
  }

  @override
  String get cameraPulseNote =>
      'Right after your monitor\'s reading, you can also measure your pulse with the camera and flash. It is for information: the alerts use your monitor\'s values.';

  @override
  String get cameraPulseInfo =>
      'For information, beside your monitor\'s pulse.';

  @override
  String get measure => 'Measure';

  @override
  String get measureAgain => 'Measure again';

  @override
  String get now => 'Now';

  @override
  String get earlier => 'Earlier…';

  @override
  String get twoBpReadings => 'Two blood pressure readings';

  @override
  String get twoBpNote => 'One minute apart; the second is kept.';

  @override
  String get systolic => 'Systolic';

  @override
  String get diastolic => 'Diastolic';

  @override
  String get pulseOptional => 'Pulse (optional)';

  @override
  String get measureBoth => 'Both';

  @override
  String get measureBp => 'Blood Pressure';

  @override
  String get contextRequired => 'Choose (required for glucose)';

  @override
  String get optionalWord => 'Optional';

  @override
  String get filterAll => 'All';

  @override
  String get readingHistory => 'Reading History';

  @override
  String get readingsTab => 'Readings';

  @override
  String get summaryTab => 'Summary';

  @override
  String get historyEmptyNote =>
      'Your readings will appear here once you log your first one. Tap the + button on the home screen to start.';

  @override
  String get noReadingsMatch => 'No readings match this filter';

  @override
  String get noReadingsMatchNote =>
      'Try another filter to see the rest of your history.';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get tagPending => 'saved on your phone, not sent yet';

  @override
  String get tagSecondOfTwo => 'second of two readings';

  @override
  String get tagPulseCamera => 'pulse by phone camera';

  @override
  String tagPulseCameraValue(int bpm) {
    return 'pulse by phone camera $bpm';
  }

  @override
  String get tagCorrected => 'corrected entry';

  @override
  String get tagEnteredLater => 'entered later';

  @override
  String get correct => 'Correct';

  @override
  String get tagFasting => 'fasting';

  @override
  String get tagBeforeMeal => 'before a meal';

  @override
  String get tagAfterMeal => 'after a meal';

  @override
  String get tagAfterMedication => 'after medication';

  @override
  String get tagAfterExercise => 'after exercise';

  @override
  String get tagOtherTime => 'other time';

  @override
  String get nothingToSummarise => 'Nothing to summarise yet';

  @override
  String get nothingToSummariseNote =>
      'Once you have logged a few readings, your averages and patterns will appear here.';

  @override
  String get avgBloodPressure => 'Avg blood pressure';

  @override
  String get avgGlucose => 'Avg glucose';

  @override
  String get totalReadings => 'Total readings';

  @override
  String readingsLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'readings logged',
      one: 'reading logged',
    );
    return '$_temp0';
  }

  @override
  String get readingDistribution => 'Reading distribution';

  @override
  String get insights => 'Insights';

  @override
  String insightHighShare(int percent) {
    return '$percent% of your readings were above your home target or out of range.';
  }

  @override
  String get insightAllInTarget =>
      'All your readings so far have been within your home targets.';

  @override
  String get insightLogBoth =>
      'Logging blood pressure and glucose together gives your risk score the most to work with.';

  @override
  String get insightFourDays =>
      'Your risk tier is worked out from your readings of the last four days.';

  @override
  String get instructionRed =>
      'Contact your health centre today. If you feel chest pain, breathlessness, weakness on one side or confusion, go to the hospital now.';

  @override
  String get instructionYellow =>
      'Above your home target. Measure again as shown in the check below; your clinician will review the result.';

  @override
  String get conditionHaemodynamic => 'Blood pressure / pulse';

  @override
  String get noData => 'No data';

  @override
  String get noReadingFourDays =>
      'No reading in the last four days — log a reading to see your level.';

  @override
  String get riskTier => 'Risk tier';

  @override
  String get yourLevel => 'Your level';

  @override
  String triageClinician(String level) {
    return 'Home triage of the last readings: $level';
  }

  @override
  String get profileOffClinician => '; verification profile off target';

  @override
  String triagePatient(String level) {
    return 'Your last readings against your home targets: $level';
  }

  @override
  String get profileOffPatient => '; your check came out above target';

  @override
  String get higherRiskThanLast =>
      'Your recent readings suggest a higher risk than the last value alone.';

  @override
  String conditionProbability(
    String condition,
    String percent,
    String tier,
    String model,
  ) {
    return '$condition: $percent% calibrated probability of a high or critical reading at the next measurement ($tier; $model)';
  }

  @override
  String stateChangeLine(String value, String measure) {
    return 'State change, last 24 h against the three days before: $value ($measure)';
  }

  @override
  String get sourceOnlineClinician =>
      'Risk model (online) combined with the home triage; the model can raise the tier, never lower it.';

  @override
  String get sourceOnlinePatient =>
      'Checked with your readings and the risk model.';

  @override
  String sourceOfflineClinician(String reason) {
    return 'Home triage only ($reason).';
  }

  @override
  String get offline => 'offline';

  @override
  String get sourceOfflinePatient =>
      'Checked on your phone from your readings.';

  @override
  String get provisionalCutpoints =>
      'Model tier cut-points are provisional until set with the clinician.';

  @override
  String get evolution => 'Evolution';

  @override
  String get evolutionNote =>
      'Last 24 hours compared with the three days before';

  @override
  String get evolutionEmpty =>
      'Not enough readings yet: log readings on several days to see how they change.';

  @override
  String get stable => 'stable';

  @override
  String get trendTitle => 'Systolic trend — last 14 days';

  @override
  String get homeTargetBadge => 'Home target < 135/85';

  @override
  String get noBpIn14Days => 'No blood pressure reading in the last 14 days';

  @override
  String get greenBandNote =>
      'Green band: your home target for the upper number, from 110 to 134 mmHg (with the lower number below 85). Keeping your blood pressure there lowers the risk of stroke and heart disease.';

  @override
  String get routineNote =>
      'Usual routine: blood pressure twice a week, morning and evening, two readings each time; glucose once a week, fasting and 90 minutes after lunch. Measure more often when the app asks for a check.';

  @override
  String get actionNone => 'No change needed';

  @override
  String get actionAdvice => 'Advice from your clinician';

  @override
  String get actionTreatmentChange => 'Your clinician adjusted your treatment';

  @override
  String get actionConsultation => 'Your clinician asks to see you';

  @override
  String get actionReferral => 'You are referred for further care';

  @override
  String get reviewed => 'Reviewed';

  @override
  String get fromYourClinician => 'From your clinician';

  @override
  String alertReviewed(String date, String reviewed) {
    return 'Alert of $date, reviewed $reviewed';
  }

  @override
  String get sourceRule => 'Guideline rule';

  @override
  String get sourceModel => 'Risk model';

  @override
  String get sourceNonTransmission => 'No readings received';

  @override
  String get verdictConfirmed => 'True alert';

  @override
  String get verdictNotSignificant => 'False alert';

  @override
  String get verdictUncertain => 'Uncertain';

  @override
  String get clinicalActionNone => 'No action';

  @override
  String get clinicalActionAdvice => 'Advice';

  @override
  String get clinicalActionTreatment => 'Dose or drug change';

  @override
  String get clinicalActionConsultation => 'Consultation';

  @override
  String get clinicalActionReferral => 'Referral';

  @override
  String checkupPeriodSuffix(int days) {
    return ' (checkup period $days days)';
  }

  @override
  String noReadingSince(String date, String period) {
    return 'No reading since $date$period';
  }

  @override
  String get noReadingInPeriod => 'No reading within the checkup period';

  @override
  String noReadingForDays(int days) {
    return 'No reading for more than $days days';
  }

  @override
  String bpProfileOff(String sbp, String dbp, String readings, String days) {
    return '7-day profile off target: mean $sbp/$dbp mmHg over $readings readings, $days days';
  }

  @override
  String glucoseProfileOff(String before, String after) {
    return 'Glucose profile off target: mean $before before and $after mmol/L after meals';
  }

  @override
  String triggerPulse(String value) {
    return 'pulse $value bpm';
  }

  @override
  String triggerGlucose(String value) {
    return 'glucose $value mmol/L';
  }

  @override
  String get trendRising => 'rising';

  @override
  String get trendFalling => 'falling';

  @override
  String get trendTooFew => 'too few readings';

  @override
  String get escalated => 'Escalated';

  @override
  String get neverReviewed => 'never reviewed';

  @override
  String daysSinceReview(int days) {
    return '$days d since last review';
  }

  @override
  String get escalatedToYou =>
      'Escalated to you as alternate: another clinician\'s patient';

  @override
  String trendLine(String sbp, String glucose) {
    return '14-day trend: systolic $sbp, glucose $glucose';
  }

  @override
  String thresholdsLine(String version) {
    return 'Thresholds $version';
  }

  @override
  String modelSuffix(String version) {
    return ' · model $version';
  }

  @override
  String probabilitySuffix(String percent) {
    return ' · calibrated P(alert) $percent%';
  }

  @override
  String get verdict => 'Verdict';

  @override
  String get eventOpen => 'Open';

  @override
  String reviewedSuffix(String date) {
    return ' · reviewed $date';
  }

  @override
  String verdictNotSaved(String error) {
    return 'Could not save the verdict: $error';
  }

  @override
  String get actionTaken => 'Action taken';

  @override
  String get verdictCommentHint =>
      'Comment (optional) — serves as the clinical note';

  @override
  String get sendCommentToPatient => 'Send the comment to the patient';

  @override
  String get saving => 'Saving…';

  @override
  String get closeAlert => 'Close the alert';

  @override
  String get ageNotRecorded => 'age not recorded';

  @override
  String ageBand(int low, int high) {
    return '$low–$high yrs';
  }

  @override
  String get messagePatient => 'Message patient';

  @override
  String get readingHistoryTitle => 'Reading history';

  @override
  String get noClinicalInfo =>
      'No clinical information recorded for this patient yet.';

  @override
  String get conditions => 'Conditions';

  @override
  String get medications => 'Medications';

  @override
  String readingsNotLoaded(String error) {
    return 'Could not load readings.\n$error';
  }

  @override
  String get patientNoReadings =>
      'This patient has not logged any readings yet.';

  @override
  String get provReplaced => 'replaced by a correction';

  @override
  String get provCorrection => 'correction of an earlier entry';

  @override
  String provSecondOfTwo(String first) {
    return 'second of two readings (first $first)';
  }

  @override
  String provEntered(String date) {
    return 'entered $date';
  }

  @override
  String provQuality(String flag) {
    return 'quality check: $flag';
  }

  @override
  String get bpmByCamera => 'bpm by phone camera';

  @override
  String get checkupPeriod => 'Checkup period';

  @override
  String periodDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get currentSuffix => '  (current)';

  @override
  String get alertsAndVerdicts => 'Alerts and verdicts';

  @override
  String checkupEvery(int days) {
    return 'Checkup every $days d';
  }

  @override
  String get defaultSuffix => ' (default)';

  @override
  String alertsNotLoaded(String error) {
    return 'Could not load alerts: $error';
  }

  @override
  String get noAlertForPatient => 'No alert recorded for this patient.';

  @override
  String get noClinicianWithCode => 'No clinician has this code.';

  @override
  String get ownCode => 'This is your own code.';

  @override
  String get enterYourName => 'Please enter your name.';

  @override
  String get ageRange => 'Please enter an age between 1 and 120.';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get editProfileTitle => 'Edit Profile';

  @override
  String get aboutYou => 'About you';

  @override
  String get age => 'Age';

  @override
  String get sex => 'Sex';

  @override
  String get bloodType => 'Blood type';

  @override
  String get medical => 'Medical';

  @override
  String get conditionsHint =>
      'One per line\ne.g. Hypertension\nType 2 Diabetes';

  @override
  String get currentMedicationsField => 'Current medications';

  @override
  String get medicationsHint => 'One per line\ne.g. Amlodipine 5mg';

  @override
  String get emergencyContact => 'Emergency contact';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get managedByCareTeam => 'Managed by your care team';

  @override
  String get accountType => 'Account type';

  @override
  String get patient => 'Patient';

  @override
  String get assignedClinician => 'Assigned clinician';

  @override
  String get linked => 'Linked';

  @override
  String get notSet => 'Not set';

  @override
  String get noBackCamera =>
      'This phone has no back camera to measure the pulse.';

  @override
  String cameraNotStarted(String error) {
    return 'The camera could not start: $error';
  }

  @override
  String get cameraNotAllowed =>
      'TeleMonitor is not allowed to use the camera. Allow it in the phone settings (Apps, TeleMonitor, Permissions), then try again.';

  @override
  String cameraNotStartedCode(String code) {
    return 'The camera could not start ($code).';
  }

  @override
  String get pulseWithCamera => 'Pulse with the camera';

  @override
  String get noFlash =>
      'The flash could not be turned on: measure near a bright light.';

  @override
  String get pulseHowTo =>
      'Stay seated. Cover the back camera and the flash with the tip of your index finger, without pressing, and keep still for about 20 seconds. The flash lights your finger and the camera follows the blood that each heartbeat brings. No picture or video is kept.';

  @override
  String get pulseFingerMoved =>
      'Your finger moved, so the measurement starts again. Cover the camera and the flash.';

  @override
  String get pulseCover =>
      'Cover the camera and the flash with your fingertip.';

  @override
  String get pulseStarting => 'Starting the camera…';

  @override
  String get pulseFingerDetected => 'Finger detected. Keep still…';

  @override
  String get pulseMeasuring => 'Measuring. Keep still and breathe normally.';

  @override
  String get pulseResultNote =>
      'Measured with the phone camera. It is shown to you and your clinician for information: your monitor\'s pulse remains the reference, and the alerts use your monitor\'s readings.';

  @override
  String get pulseVeryLow =>
      'This pulse is very low. Sit, rest for five minutes and measure again; if your monitor shows a pulse, enter it too. If you feel unwell (chest pain, breathlessness, fainting), go to the nearest health centre without waiting.';

  @override
  String get pulseVeryHigh =>
      'This pulse is very high. Sit, rest for five minutes and measure again; if your monitor shows a pulse, enter it too. If you feel unwell (chest pain, breathlessness, fainting), go to the nearest health centre without waiting.';

  @override
  String get useThisValue => 'Use this value';

  @override
  String get pulseFailed =>
      'The signal was not steady enough to give a pulse. Keep the finger still and press lightly: pressing hard stops the blood. Cold fingers give a weak signal; warm your hand first. If it still fails, use your monitor\'s pulse.';

  @override
  String get tryAgain => 'Try again';

  @override
  String photoOf(String name) {
    return 'Photo of $name';
  }

  @override
  String get profilePhoto => 'Profile photo';

  @override
  String get photoNoteClinician =>
      'Optional. Your patients see it beside your messages, so they know who follows them.';

  @override
  String get photoNotePatient =>
      'Optional. Only you and your clinician can see it; it helps your clinician recognise you at the health centre. You can remove it at any time.';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get chooseFromGallery => 'Choose from the gallery';

  @override
  String get removePhoto => 'Remove the photo';

  @override
  String get photoRemoved => 'Photo removed.';

  @override
  String get photoSaved => 'Photo saved.';

  @override
  String photoNotUpdated(String error) {
    return 'Could not update the photo: $error';
  }

  @override
  String get notAnImage => 'This file is not an image the app can read.';

  @override
  String get photoTooLarge =>
      'This photo is too large. Please choose another one.';

  @override
  String get noEnrolmentCode =>
      'No enrolment code has been issued for your account yet. Contact the system administrator — without one, patients cannot register to you.';

  @override
  String get yourEnrolmentCode => 'Your enrolment code';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get copy => 'Copy';

  @override
  String get giveCodeNote =>
      'Give this code to a patient so they can register and be linked to you.';

  @override
  String get bpCheckTitle => '7-day blood pressure check';

  @override
  String get glucoseCheckTitle => 'One-day glucose check';

  @override
  String get bpCheckHow =>
      'Every morning and every evening for 7 days: sit and rest 5 minutes, then take two readings one minute apart and log both.';

  @override
  String get glucoseCheckHow =>
      'During one day: before and 90 minutes after each of your three meals (6 readings). Choose \"Before meal\" or \"After meal\" when you log each one.';

  @override
  String bpCheckProgress(int readings, int expected, String days, String date) {
    return '$readings of $expected readings · $days · until $date';
  }

  @override
  String glucoseCheckProgress(int before, int after, String date) {
    return 'Before meals: $before of 3 · after meals: $after of 3 · until $date';
  }

  @override
  String bpCheckMean(String value) {
    return 'Average $value mmHg (target below 135/85)';
  }

  @override
  String meanBeforeMeals(String value) {
    return 'before meals: $value mmol/L (target 7 or less)';
  }

  @override
  String meanAfterMeals(String value) {
    return 'after meals: $value mmol/L (target 10 or less)';
  }

  @override
  String averageOf(String value) {
    return 'Average $value';
  }

  @override
  String joinedBySemicolon(String first, String second) {
    return '$first; $second';
  }

  @override
  String get checkInProgressClinician => 'In progress.';

  @override
  String get checkOffTargetClinician =>
      'Off target: teleconsultation (red event in the queue).';

  @override
  String get checkOffTargetPatient =>
      'Your average is above the target. Your clinician has the result; contact your health centre.';

  @override
  String get checkOnTargetClinician => 'On target.';

  @override
  String get checkOnTargetPatient =>
      'Your average is on target. Keep measuring as usual.';

  @override
  String get checkIncompleteClinician =>
      'Incomplete: too few readings to conclude.';

  @override
  String get checkIncompletePatient =>
      'Not enough readings to conclude. Contact your health centre or start the check again.';

  @override
  String get inProgress => 'In progress';

  @override
  String get aboveTarget => 'Above target';

  @override
  String get onTarget => 'On target';

  @override
  String get incomplete => 'Incomplete';

  @override
  String get noClinicianYet => 'No clinician connected yet';

  @override
  String get noClinicianYetNote =>
      'Enter the code your doctor gives you to start a conversation with them.';

  @override
  String get connectToAClinician => 'Connect to a clinician';

  @override
  String couldNotSend(String error) {
    return 'Could not send: $error';
  }

  @override
  String messagesNotLoaded(String error) {
    return 'Could not load messages.\n$error';
  }

  @override
  String get noMessagesYet => 'No messages yet.\nStart the conversation below.';

  @override
  String get typeAMessage => 'Type a message...';

  @override
  String get presenceOffline => 'Offline';

  @override
  String get presenceOnline => 'Online';

  @override
  String lastSeenMinutes(int n) {
    return 'Last seen $n min ago';
  }

  @override
  String lastSeenHours(int n) {
    return 'Last seen $n h ago';
  }

  @override
  String get lastSeenYesterday => 'Last seen yesterday';

  @override
  String lastSeenDays(int n) {
    return 'Last seen $n days ago';
  }

  @override
  String get noClinicianConnected => 'No clinician connected';

  @override
  String get noClinicianConnectedNote =>
      'You can record readings now, but nobody is reviewing them yet. Enter the code your doctor gives you to connect.';

  @override
  String get findCareNearYou => 'Find care near you';

  @override
  String get findHospitalNearYou => 'Find a hospital near you';

  @override
  String get tapCategory =>
      'Tap a category to see what is nearby in Google Maps.';

  @override
  String get careUrgentNote =>
      'Your recent readings are in a range that needs attention. If you feel unwell, go to a hospital rather than waiting for your next appointment.';

  @override
  String get mapsNotOpened =>
      'Could not open Maps on this device. Please search for \"pharmacie near me\" in your browser.';

  @override
  String get locationNote =>
      'TeleMonitor does not access or store your location. The search is handled by Google Maps on your device.';

  @override
  String get carePharmacy => 'Pharmacy';

  @override
  String get careHospital => 'Hospital';

  @override
  String get careClinic => 'Clinic / Health centre';

  @override
  String get careLaboratory => 'Laboratory';

  @override
  String get carePharmacyNote =>
      'Collect medication, or have your blood pressure checked — many pharmacies offer this.';

  @override
  String get careHospitalNote =>
      'For urgent care, or when your readings are in the high or critical range.';

  @override
  String get careClinicNote => 'For a routine consultation or follow-up visit.';

  @override
  String get careLaboratoryNote =>
      'For blood glucose, HbA1c and other laboratory tests.';

  @override
  String get latestReadingNeedsAttention =>
      'Your latest reading needs attention';

  @override
  String get careKinds => 'Pharmacies, clinics, hospitals and laboratories';

  @override
  String get assistantGreeting =>
      'Hello. I can explain your readings, answer general questions about blood pressure and diabetes, and help you decide whether something needs a doctor.\n\nI cannot advise on medication — only your clinician can do that.';

  @override
  String get healthAssistant => 'Health Assistant';

  @override
  String get notYourDoctor => 'Automated — not your doctor';

  @override
  String get assistantDisclaimer =>
      'General information only. It cannot diagnose you or advise on medication. For anything urgent, go to a health facility.';

  @override
  String get askHealthQuestion => 'Ask a health question...';

  @override
  String get askHealthAssistant => 'Ask the Health Assistant';

  @override
  String get understandReadings =>
      'Understand your readings and your condition';

  @override
  String get assistantOffline =>
      'The assistant needs an internet connection. Your readings are still saved and will sync when you are back online.';

  @override
  String get assistantBusy =>
      'The assistant is busy right now. Please try again in a few minutes.';

  @override
  String get assistantBlocked =>
      'I am not able to answer that. If it concerns your health, please speak to your clinician.';

  @override
  String get assistantError =>
      'Something went wrong reaching the assistant. Please try again.';

  @override
  String get suggestReadings => 'What do my last readings mean?';

  @override
  String get suggestDanger => 'Why is high blood pressure dangerous?';

  @override
  String get suggestFood => 'What foods should I be careful with?';

  @override
  String get suggestHowOften => 'How often should I measure?';

  @override
  String get open => 'Open';

  @override
  String get riskServiceNotConfigured => 'risk service not configured';

  @override
  String get riskServiceUnreachable => 'risk service unreachable';

  @override
  String get termsS1Title => 'What TeleMonitor is';

  @override
  String get termsS1P1 =>
      'TeleMonitor helps you follow your blood pressure and blood sugar at home with your clinician. You enter your readings; the app compares them with your home targets and your clinician reviews the alerts.';

  @override
  String get termsS1P2 =>
      'TeleMonitor does not replace a consultation and is not an emergency service. It never changes your treatment: only your clinician can. If you feel very unwell, go to the nearest health centre or hospital without waiting for an answer in the app.';

  @override
  String get termsS2Title => 'The information the app keeps';

  @override
  String get termsS2B1 => '• Your account: name and email address.';

  @override
  String get termsS2B2 =>
      '• Your profile, if you fill it in: age, sex, height, weight, conditions, medications, phone, emergency contact and an optional photo.';

  @override
  String get termsS2B3 =>
      '• Your readings (blood pressure, heart rate, blood sugar, when you measured and your notes), the alerts they raise and your clinician\'s review of them.';

  @override
  String get termsS2B4 =>
      '• If you measure your pulse with the phone camera, the pulse found: the images of the camera are read on the phone and dropped at once, never kept or sent.';

  @override
  String get termsS2B5 => '• The messages you exchange with your clinician.';

  @override
  String get termsS2B6 =>
      '• What the service needs to work: when you last used the app, and the address used to send notifications to your phone.';

  @override
  String get termsS3Title => 'Who can see it';

  @override
  String get termsS3B1 => '• You.';

  @override
  String get termsS3B2 =>
      '• The clinician you connect to, and the colleague they name to replace them when an alert waits too long.';

  @override
  String get termsS3B3 =>
      '• The administrator of the system, only to keep it working.';

  @override
  String get termsS3P1 =>
      'Your information is stored on Google Firebase servers and travels encrypted. Access rules let each person see only what they are allowed to see.';

  @override
  String get termsS3P2 =>
      'When you use the health assistant, your question, age, sex, conditions, medications and recent readings are sent to Google\'s Gemini service to prepare the answer, never your name or contact details. Do not type your name or other personal details in the assistant.';

  @override
  String get termsS4Title => 'Research, only if you agree';

  @override
  String get termsS4P1 =>
      'If you tick the research box, your information may also be used for medical research on the home follow-up of hypertension and diabetes, by the TeleMonitor project of the GISDIA laboratory, National Higher Polytechnic School of Douala (ENSPD), University of Douala.';

  @override
  String get termsS4P2 =>
      'Before any use, your name, email, phone numbers, emergency contact, photo, messages and notes are removed, and your account is replaced by a code. Results are published only as figures about groups of patients, in which no one can be recognised.';

  @override
  String get termsS4P3 =>
      'Saying no changes nothing in your care. You can change your choice at any time in your profile; from then on, your information is left out of new research extracts.';

  @override
  String get termsS5Title => 'Your rights';

  @override
  String get termsS5P1 =>
      'Under Law No. 2024/017 of 23 December 2024 on the protection of personal data in Cameroon, you can see your information (the app shows it to you), have it corrected, withdraw your research consent, and ask for your account and your information to be deleted. For a deletion or any question, ask your clinician or the administrator.';

  @override
  String get termsS6Title => 'Keeping your account safe';

  @override
  String get termsS6P1 =>
      'Keep your password to yourself. Confirm your email address: it is the only way to set a new password if you forget yours. On a shared phone, sign out when you finish.';

  @override
  String get termsS7Title => 'Changes to these terms';

  @override
  String get termsS7P1 =>
      'If these terms change, the app shows you the new version and asks you to accept it before you continue.';

  @override
  String termsVersionOf(String date) {
    return 'Version of $date';
  }

  @override
  String get updatedTerms => 'Updated terms of use';

  @override
  String get termsChanged =>
      'The terms have changed. Please read them and accept them to continue.';

  @override
  String get readAndAcceptTerms =>
      'Please read the terms of use and accept them to continue.';

  @override
  String get acceptAndContinue => 'Accept and continue';

  @override
  String messageNotSent(String error) {
    return 'A message was not sent: $error';
  }

  @override
  String verdictNotSavedServer(String error) {
    return 'A verdict was not saved: $error';
  }
}
