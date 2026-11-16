import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageNote.
  ///
  /// In en, this message translates to:
  /// **'Notifications and emails come in this language too.'**
  String get languageNote;

  /// No description provided for @loginMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Please enter both email and password.'**
  String get loginMissingFields;

  /// No description provided for @resetLinkSentGeneric.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for that address, a reset link has been sent. Check your inbox, and the spam folder too.'**
  String get resetLinkSentGeneric;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Chronic Disease Telemonitoring'**
  String get appTagline;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @createAccountLink.
  ///
  /// In en, this message translates to:
  /// **'New patient? Create an account'**
  String get createAccountLink;

  /// No description provided for @sameLogin.
  ///
  /// In en, this message translates to:
  /// **'Patients and clinicians use the same login'**
  String get sameLogin;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the email address of your account and we will send you a link to choose a new password. No access to that email? Ask your clinician: the administrator can reset it.'**
  String get resetPasswordIntro;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @sendLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get sendLink;

  /// No description provided for @noProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'No profile found for this account.'**
  String get noProfileTitle;

  /// No description provided for @noProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Add a Firestore document at users/{uid} with an email, name, and role field to finish setting up this account.'**
  String noProfileBody(String uid);

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeAuto;

  /// No description provided for @themeFollowsDevice.
  ///
  /// In en, this message translates to:
  /// **'Following your device setting.'**
  String get themeFollowsDevice;

  /// No description provided for @themeAlwaysDark.
  ///
  /// In en, this message translates to:
  /// **'Always dark, whatever your device is set to.'**
  String get themeAlwaysDark;

  /// No description provided for @themeAlwaysLight.
  ///
  /// In en, this message translates to:
  /// **'Always light, whatever your device is set to.'**
  String get themeAlwaysLight;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @medicalConditions.
  ///
  /// In en, this message translates to:
  /// **'Medical Conditions'**
  String get medicalConditions;

  /// No description provided for @currentMedications.
  ///
  /// In en, this message translates to:
  /// **'Current Medications'**
  String get currentMedications;

  /// No description provided for @physicalInfo.
  ///
  /// In en, this message translates to:
  /// **'Physical Info'**
  String get physicalInfo;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergency;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @clinician.
  ///
  /// In en, this message translates to:
  /// **'Clinician'**
  String get clinician;

  /// No description provided for @assigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assigned;

  /// No description provided for @notYetAssigned.
  ///
  /// In en, this message translates to:
  /// **'Not yet assigned'**
  String get notYetAssigned;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @termsAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get termsAccepted;

  /// No description provided for @termsAcceptedOn.
  ///
  /// In en, this message translates to:
  /// **'Accepted {date}'**
  String termsAcceptedOn(String date);

  /// No description provided for @privacyAndConsent.
  ///
  /// In en, this message translates to:
  /// **'Privacy and consent'**
  String get privacyAndConsent;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get termsOfUse;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @researchUseTitle.
  ///
  /// In en, this message translates to:
  /// **'Use of my data for research'**
  String get researchUseTitle;

  /// No description provided for @researchUseNote.
  ///
  /// In en, this message translates to:
  /// **'Without your name, contact details, photo or messages. Your care is the same either way.'**
  String get researchUseNote;

  /// No description provided for @researchConsentGiven.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Your data, without your name or contact details, may be used for research.'**
  String get researchConsentGiven;

  /// No description provided for @researchConsentWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Done. Your data will be left out of new research extracts.'**
  String get researchConsentWithdrawn;

  /// No description provided for @savedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved on the phone. It will be sent when you are back online.'**
  String get savedOffline;

  /// No description provided for @choiceNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Could not save your choice: {error}'**
  String choiceNotSaved(String error);

  /// No description provided for @resetLinkSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to {email} to choose a new password. Look in the spam folder too.'**
  String resetLinkSentTo(String email);

  /// No description provided for @changeProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get changeProfilePhoto;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{age} yrs'**
  String ageYears(int age);

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @sexOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get sexOther;

  /// No description provided for @completeProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get completeProfile;

  /// No description provided for @completeProfileNote.
  ///
  /// In en, this message translates to:
  /// **'Adding your conditions, medications and emergency contact helps your clinician interpret your readings.'**
  String get completeProfileNote;

  /// No description provided for @addDetails.
  ///
  /// In en, this message translates to:
  /// **'Add details'**
  String get addDetails;

  /// No description provided for @signOutButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutButton;

  /// No description provided for @notificationsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked on this phone. Allow them for TeleMonitor in the phone\'s settings (Apps, TeleMonitor, Notifications).'**
  String get notificationsBlocked;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get notificationsOn;

  /// No description provided for @notificationsTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Off: turn on'**
  String get notificationsTurnOn;

  /// No description provided for @alternateRemoved.
  ///
  /// In en, this message translates to:
  /// **'Alternate removed.'**
  String get alternateRemoved;

  /// No description provided for @alternateNamed.
  ///
  /// In en, this message translates to:
  /// **'{name} is now your alternate.'**
  String alternateNamed(String name);

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String couldNotSave(String error);

  /// No description provided for @conversationNotOpened.
  ///
  /// In en, this message translates to:
  /// **'This conversation could not be opened.'**
  String get conversationNotOpened;

  /// No description provided for @myPatients.
  ///
  /// In en, this message translates to:
  /// **'My Patients'**
  String get myPatients;

  /// No description provided for @myPhoto.
  ///
  /// In en, this message translates to:
  /// **'My photo'**
  String get myPhoto;

  /// No description provided for @alternateClinician.
  ///
  /// In en, this message translates to:
  /// **'Alternate clinician'**
  String get alternateClinician;

  /// No description provided for @queueTab.
  ///
  /// In en, this message translates to:
  /// **'Queue ({count})'**
  String queueTab(int count);

  /// No description provided for @patientsTab.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get patientsTab;

  /// No description provided for @queueNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load the queue.'**
  String get queueNotLoaded;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No alert to review.'**
  String get queueEmpty;

  /// No description provided for @queueEmptyNote.
  ///
  /// In en, this message translates to:
  /// **'Yellow and red readings, model alerts and patients who stopped sending readings appear here, the most urgent first.'**
  String get queueEmptyNote;

  /// No description provided for @patientsNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load patients.'**
  String get patientsNotLoaded;

  /// No description provided for @noPatientsYet.
  ///
  /// In en, this message translates to:
  /// **'No patients connected yet.'**
  String get noPatientsYet;

  /// No description provided for @noPatientsYetNote.
  ///
  /// In en, this message translates to:
  /// **'Share the code above with a patient so they can register and be linked to you.'**
  String get noPatientsYetNote;

  /// No description provided for @noReadingsYet.
  ///
  /// In en, this message translates to:
  /// **'No readings yet'**
  String get noReadingsYet;

  /// No description provided for @readingLogged.
  ///
  /// In en, this message translates to:
  /// **'Reading logged'**
  String get readingLogged;

  /// No description provided for @noAlternate.
  ///
  /// In en, this message translates to:
  /// **'No alternate named. Alerts you leave unreviewed are escalated to nobody.'**
  String get noAlternate;

  /// No description provided for @currentAlternate.
  ///
  /// In en, this message translates to:
  /// **'Current alternate: {name}.'**
  String currentAlternate(String name);

  /// No description provided for @colleagueCode.
  ///
  /// In en, this message translates to:
  /// **'Colleague\'s enrolment code'**
  String get colleagueCode;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @enterFullName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name.'**
  String get enterFullName;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get enterEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Please choose a password of at least 6 characters.'**
  String get passwordTooShort;

  /// No description provided for @codeNotRecognisedSignup.
  ///
  /// In en, this message translates to:
  /// **'That code was not recognised. Check it, or clear the field and connect to your clinician later.'**
  String get codeNotRecognisedSignup;

  /// No description provided for @acceptTermsFirst.
  ///
  /// In en, this message translates to:
  /// **'Please read and accept the terms of use to create your account.'**
  String get acceptTermsFirst;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @joinCareTeam.
  ///
  /// In en, this message translates to:
  /// **'Join your care team'**
  String get joinCareTeam;

  /// No description provided for @joinCareTeamNote.
  ///
  /// In en, this message translates to:
  /// **'Create your account to start recording readings. You can connect to a clinician now or later.'**
  String get joinCareTeamNote;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Jean Mbarga'**
  String get fullNameHint;

  /// No description provided for @emailUseNote.
  ///
  /// In en, this message translates to:
  /// **'Use an address you can open: we send a link to confirm it, and it is how you set a new password if you forget yours.'**
  String get emailUseNote;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get passwordHint;

  /// No description provided for @clinicianCode.
  ///
  /// In en, this message translates to:
  /// **'Clinician code'**
  String get clinicianCode;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'(optional)'**
  String get optional;

  /// No description provided for @clinicianCodeNote.
  ///
  /// In en, this message translates to:
  /// **'Have one from your doctor? Enter it to connect straight away. You can also skip this and connect later from your profile.'**
  String get clinicianCodeNote;

  /// No description provided for @clinicianCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. MBARGA-4F7K'**
  String get clinicianCodeHint;

  /// No description provided for @haveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccountSignIn;

  /// No description provided for @clinicianAccountsNote.
  ///
  /// In en, this message translates to:
  /// **'Clinician accounts are created by the administrator, not here.'**
  String get clinicianAccountsNote;

  /// No description provided for @checkingCode.
  ///
  /// In en, this message translates to:
  /// **'Checking code…'**
  String get checkingCode;

  /// No description provided for @willBeLinkedTo.
  ///
  /// In en, this message translates to:
  /// **'You will be linked to {name}'**
  String willBeLinkedTo(String name);

  /// No description provided for @codeNotRecognised.
  ///
  /// In en, this message translates to:
  /// **'Code not recognised'**
  String get codeNotRecognised;

  /// No description provided for @acceptTermsTick.
  ///
  /// In en, this message translates to:
  /// **'I have read and I accept the terms of use and the privacy notice.'**
  String get acceptTermsTick;

  /// No description provided for @readTheTerms.
  ///
  /// In en, this message translates to:
  /// **'Read the terms'**
  String get readTheTerms;

  /// No description provided for @researchTick.
  ///
  /// In en, this message translates to:
  /// **'Optional: my data, without my name, contact details, photo or messages, may be used for medical research. My care is the same if I say no, and I can change this later in my profile.'**
  String get researchTick;

  /// No description provided for @emailConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Email address confirmed. Thank you.'**
  String get emailConfirmed;

  /// No description provided for @emailNotConfirmedYet.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed yet. Open the link in the email, then tap this button again.'**
  String get emailNotConfirmedYet;

  /// No description provided for @emailSentCheckSpam.
  ///
  /// In en, this message translates to:
  /// **'Email sent. It can take a few minutes; look in the spam folder too.'**
  String get emailSentCheckSpam;

  /// No description provided for @emailSentRecently.
  ///
  /// In en, this message translates to:
  /// **'An email was sent a moment ago. Please wait a few minutes before asking again.'**
  String get emailSentRecently;

  /// No description provided for @yourAddress.
  ///
  /// In en, this message translates to:
  /// **'your address'**
  String get yourAddress;

  /// No description provided for @confirmEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email address'**
  String get confirmEmailTitle;

  /// No description provided for @confirmEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to {email}. Open it to confirm the address: it is the only way to set a new password if you forget yours.'**
  String confirmEmailBody(String email);

  /// No description provided for @sendItAgain.
  ///
  /// In en, this message translates to:
  /// **'Send it again'**
  String get sendItAgain;

  /// No description provided for @iveConfirmedIt.
  ///
  /// In en, this message translates to:
  /// **'I\'ve confirmed it'**
  String get iveConfirmedIt;

  /// No description provided for @yourClinician.
  ///
  /// In en, this message translates to:
  /// **'Your clinician'**
  String get yourClinician;

  /// No description provided for @clinicianCodeNotRecognised.
  ///
  /// In en, this message translates to:
  /// **'That clinician code was not recognised. Check it with your doctor, or leave it blank and connect later.'**
  String get clinicianCodeNotRecognised;

  /// No description provided for @accountNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Your account could not be set up. Please try again. ({error})'**
  String accountNotSetUp(String error);

  /// No description provided for @mustBeSignedIn.
  ///
  /// In en, this message translates to:
  /// **'You must be signed in to do this.'**
  String get mustBeSignedIn;

  /// No description provided for @alreadyConnected.
  ///
  /// In en, this message translates to:
  /// **'Your account is already connected to a clinician. Contact your care team if this needs to change.'**
  String get alreadyConnected;

  /// No description provided for @codeNotRecognisedCheck.
  ///
  /// In en, this message translates to:
  /// **'That code was not recognised. Please check it with your doctor.'**
  String get codeNotRecognisedCheck;

  /// No description provided for @couldNotConnect.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to that clinician. ({error})'**
  String couldNotConnect(String error);

  /// No description provided for @wrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get wrongCredentials;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'That email address doesn\'t look right.'**
  String get invalidEmail;

  /// No description provided for @emailInUse.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for that email. Try signing in.'**
  String get emailInUse;

  /// No description provided for @accountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get accountDisabled;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts — please wait a moment and try again.'**
  String get tooManyAttempts;

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get noInternet;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed ({code}).'**
  String signInFailed(String code);

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrong;

  /// No description provided for @confirmClinician.
  ///
  /// In en, this message translates to:
  /// **'Confirm your clinician'**
  String get confirmClinician;

  /// No description provided for @confirmClinicianBody.
  ///
  /// In en, this message translates to:
  /// **'You will be connected to {name}. They will be able to see the readings you record.\n\nThis cannot be changed from the app afterwards — contact your care team if you need it corrected.'**
  String confirmClinicianBody(String name);

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to {name}'**
  String connectedTo(String name);

  /// No description provided for @connectToClinician.
  ///
  /// In en, this message translates to:
  /// **'Connect to your clinician'**
  String get connectToClinician;

  /// No description provided for @enterClinicianCode.
  ///
  /// In en, this message translates to:
  /// **'Enter your clinician code'**
  String get enterClinicianCode;

  /// No description provided for @askDoctorForCode.
  ///
  /// In en, this message translates to:
  /// **'Ask your doctor for their code. It looks something like MBARGA-4F7K.'**
  String get askDoctorForCode;

  /// No description provided for @noCodeYetNote.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have a code yet? You can keep recording your readings without one. They are saved to your account and your clinician will see them from the day you connect.'**
  String get noCodeYetNote;

  /// No description provided for @logAReading.
  ///
  /// In en, this message translates to:
  /// **'Log a reading'**
  String get logAReading;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning,'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon,'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening,'**
  String get goodEvening;

  /// No description provided for @alertBpRed.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure or pulse out of range — contact your health centre today'**
  String get alertBpRed;

  /// No description provided for @alertGlucoseRed.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose out of range — contact your health centre today'**
  String get alertGlucoseRed;

  /// No description provided for @alertBpYellow.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure above your home target — see the 7-day check below'**
  String get alertBpYellow;

  /// No description provided for @alertGlucoseYellow.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose above your target — see the one-day check below'**
  String get alertGlucoseYellow;

  /// No description provided for @readingsPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reading is saved on your phone and will be sent when you are online.} other{{count} readings are saved on your phone and will be sent when you are online.}}'**
  String readingsPending(int count);

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String minutesAgo(int n);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String hoursAgo(int n);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String daysAgo(int n);

  /// No description provided for @todayAt.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String todayAt(String time);

  /// No description provided for @yesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String yesterdayAt(String time);

  /// No description provided for @dateAt.
  ///
  /// In en, this message translates to:
  /// **'{date}, {time}'**
  String dateAt(String date, String time);

  /// No description provided for @bloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure'**
  String get bloodPressure;

  /// No description provided for @bloodGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose'**
  String get bloodGlucose;

  /// No description provided for @pulse.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get pulse;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'camera'**
  String get camera;

  /// No description provided for @lastReading.
  ///
  /// In en, this message translates to:
  /// **'Last reading'**
  String get lastReading;

  /// No description provided for @noneYet.
  ///
  /// In en, this message translates to:
  /// **'none yet'**
  String get noneYet;

  /// No description provided for @recentReadings.
  ///
  /// In en, this message translates to:
  /// **'Recent Readings'**
  String get recentReadings;

  /// No description provided for @noReadingsLoggedYet.
  ///
  /// In en, this message translates to:
  /// **'No readings logged yet'**
  String get noReadingsLoggedYet;

  /// No description provided for @noValuesRecorded.
  ///
  /// In en, this message translates to:
  /// **'No values recorded'**
  String get noValuesRecorded;

  /// No description provided for @levelGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get levelGreen;

  /// No description provided for @levelYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get levelYellow;

  /// No description provided for @levelRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get levelRed;

  /// No description provided for @notMeasured.
  ///
  /// In en, this message translates to:
  /// **'Not measured'**
  String get notMeasured;

  /// No description provided for @ctxFasting.
  ///
  /// In en, this message translates to:
  /// **'Fasting (before breakfast)'**
  String get ctxFasting;

  /// No description provided for @ctxBeforeMeal.
  ///
  /// In en, this message translates to:
  /// **'Before a meal'**
  String get ctxBeforeMeal;

  /// No description provided for @ctxAfterMeal.
  ///
  /// In en, this message translates to:
  /// **'About 90 minutes after a meal'**
  String get ctxAfterMeal;

  /// No description provided for @ctxAfterMedication.
  ///
  /// In en, this message translates to:
  /// **'After medication'**
  String get ctxAfterMedication;

  /// No description provided for @ctxAfterExercise.
  ///
  /// In en, this message translates to:
  /// **'After exercise'**
  String get ctxAfterExercise;

  /// No description provided for @ctxRandom.
  ///
  /// In en, this message translates to:
  /// **'Other / not sure'**
  String get ctxRandom;

  /// No description provided for @bpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid blood pressure values{which}.'**
  String bpInvalid(String which);

  /// No description provided for @sbpOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Systolic {value}{which} is outside the plausible range ({min}–{max} mmHg). Please re-check the reading.'**
  String sbpOutOfRange(int value, String which, int min, int max);

  /// No description provided for @dbpOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Diastolic {value}{which} is outside the plausible range ({min}–{max} mmHg). Please re-check the reading.'**
  String dbpOutOfRange(int value, String which, int min, int max);

  /// No description provided for @pulsePressureTooLow.
  ///
  /// In en, this message translates to:
  /// **'Systolic ({sbp}) should be at least {gap} higher than diastolic ({dbp}){which}. Please re-check the reading.'**
  String pulsePressureTooLow(int sbp, int gap, int dbp, String which);

  /// No description provided for @hrInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid heart rate{which}.'**
  String hrInvalid(String which);

  /// No description provided for @hrOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Heart rate {value}{which} is outside the plausible range ({min}–{max} bpm). Please re-check the reading.'**
  String hrOutOfRange(int value, String which, int min, int max);

  /// No description provided for @readingInFuture.
  ///
  /// In en, this message translates to:
  /// **'The time of the reading cannot be in the future.'**
  String get readingInFuture;

  /// No description provided for @backdateLimit.
  ///
  /// In en, this message translates to:
  /// **'A reading can be dated at most {days} days back.'**
  String backdateLimit(int days);

  /// No description provided for @whichReading.
  ///
  /// In en, this message translates to:
  /// **' (reading {n})'**
  String whichReading(int n);

  /// No description provided for @glucoseInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid glucose value.'**
  String get glucoseInvalid;

  /// No description provided for @glucoseOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Glucose {value} is outside the plausible range ({min}–{max} mmol/L). Check your units — this app uses mmol/L, not mg/dL.'**
  String glucoseOutOfRange(String value, String min, String max);

  /// No description provided for @glucoseNeedsContext.
  ///
  /// In en, this message translates to:
  /// **'Choose when the glucose was measured: your target depends on the meal.'**
  String get glucoseNeedsContext;

  /// No description provided for @againstHomeTargets.
  ///
  /// In en, this message translates to:
  /// **'Against your home targets'**
  String get againstHomeTargets;

  /// No description provided for @previewBp.
  ///
  /// In en, this message translates to:
  /// **'BP: {sbp}/{dbp} mmHg'**
  String previewBp(String sbp, String dbp);

  /// No description provided for @previewGlucoseNoContext.
  ///
  /// In en, this message translates to:
  /// **'Glucose: {value} mmol/L. Choose the measurement context below.'**
  String previewGlucoseNoContext(String value);

  /// No description provided for @previewGlucose.
  ///
  /// In en, this message translates to:
  /// **'Glucose: {value} mmol/L'**
  String previewGlucose(String value);

  /// No description provided for @readingRejected.
  ///
  /// In en, this message translates to:
  /// **'A reading was not accepted by the server: {error}'**
  String readingRejected(String error);

  /// No description provided for @outOfRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'This reading is out of range'**
  String get outOfRangeTitle;

  /// No description provided for @iUnderstand.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get iUnderstand;

  /// No description provided for @readingSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Reading saved on your phone. It will be sent when you are online.'**
  String get readingSavedOffline;

  /// No description provided for @readingSaved.
  ///
  /// In en, this message translates to:
  /// **'Reading saved.'**
  String get readingSaved;

  /// No description provided for @correctAReading.
  ///
  /// In en, this message translates to:
  /// **'Correct a Reading'**
  String get correctAReading;

  /// No description provided for @logAReadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Log a Reading'**
  String get logAReadingTitle;

  /// No description provided for @measurementType.
  ///
  /// In en, this message translates to:
  /// **'Measurement type'**
  String get measurementType;

  /// No description provided for @whenTaken.
  ///
  /// In en, this message translates to:
  /// **'When was it taken?'**
  String get whenTaken;

  /// No description provided for @readingNumber.
  ///
  /// In en, this message translates to:
  /// **'Reading {n}'**
  String readingNumber(int n);

  /// No description provided for @reading2Kept.
  ///
  /// In en, this message translates to:
  /// **'Reading 2 — kept'**
  String get reading2Kept;

  /// No description provided for @bpMmHg.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure (mmHg)'**
  String get bpMmHg;

  /// No description provided for @unitsNote.
  ///
  /// In en, this message translates to:
  /// **'Pressures in mmHg, pulse in beats per minute.'**
  String get unitsNote;

  /// No description provided for @glucoseMmol.
  ///
  /// In en, this message translates to:
  /// **'Blood Glucose (mmol/L)'**
  String get glucoseMmol;

  /// No description provided for @example.
  ///
  /// In en, this message translates to:
  /// **'e.g. {value}'**
  String example(String value);

  /// No description provided for @glucoseExample.
  ///
  /// In en, this message translates to:
  /// **'6.1'**
  String get glucoseExample;

  /// No description provided for @glucose.
  ///
  /// In en, this message translates to:
  /// **'Glucose'**
  String get glucose;

  /// No description provided for @measurementContext.
  ///
  /// In en, this message translates to:
  /// **'Measurement context'**
  String get measurementContext;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Taken after morning medication...'**
  String get notesHint;

  /// No description provided for @saveCorrection.
  ///
  /// In en, this message translates to:
  /// **'Save Correction'**
  String get saveCorrection;

  /// No description provided for @saveReading.
  ///
  /// In en, this message translates to:
  /// **'Save Reading'**
  String get saveReading;

  /// No description provided for @correctThisReading.
  ///
  /// In en, this message translates to:
  /// **'Correct this reading'**
  String get correctThisReading;

  /// No description provided for @enterYourReading.
  ///
  /// In en, this message translates to:
  /// **'Enter your reading'**
  String get enterYourReading;

  /// No description provided for @correctionNote.
  ///
  /// In en, this message translates to:
  /// **'Your corrected values replace the old ones on your screens. The old entry stays in your record, marked as corrected, so your clinician can see both.'**
  String get correctionNote;

  /// No description provided for @entryNote.
  ///
  /// In en, this message translates to:
  /// **'Type the values shown on your blood pressure monitor or glucometer. For blood pressure, sit and rest for five minutes, then take two readings one minute apart: the second is the one kept.'**
  String get entryNote;

  /// No description provided for @pulseCameraOptional.
  ///
  /// In en, this message translates to:
  /// **'Pulse with the phone camera (optional)'**
  String get pulseCameraOptional;

  /// No description provided for @pulseByCamera.
  ///
  /// In en, this message translates to:
  /// **'Pulse by camera: {bpm} bpm'**
  String pulseByCamera(int bpm);

  /// No description provided for @cameraPulseNote.
  ///
  /// In en, this message translates to:
  /// **'Right after your monitor\'s reading, you can also measure your pulse with the camera and flash. It is for information: the alerts use your monitor\'s values.'**
  String get cameraPulseNote;

  /// No description provided for @cameraPulseInfo.
  ///
  /// In en, this message translates to:
  /// **'For information, beside your monitor\'s pulse.'**
  String get cameraPulseInfo;

  /// No description provided for @measure.
  ///
  /// In en, this message translates to:
  /// **'Measure'**
  String get measure;

  /// No description provided for @measureAgain.
  ///
  /// In en, this message translates to:
  /// **'Measure again'**
  String get measureAgain;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier…'**
  String get earlier;

  /// No description provided for @twoBpReadings.
  ///
  /// In en, this message translates to:
  /// **'Two blood pressure readings'**
  String get twoBpReadings;

  /// No description provided for @twoBpNote.
  ///
  /// In en, this message translates to:
  /// **'One minute apart; the second is kept.'**
  String get twoBpNote;

  /// No description provided for @systolic.
  ///
  /// In en, this message translates to:
  /// **'Systolic'**
  String get systolic;

  /// No description provided for @diastolic.
  ///
  /// In en, this message translates to:
  /// **'Diastolic'**
  String get diastolic;

  /// No description provided for @pulseOptional.
  ///
  /// In en, this message translates to:
  /// **'Pulse (optional)'**
  String get pulseOptional;

  /// No description provided for @measureBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get measureBoth;

  /// No description provided for @measureBp.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure'**
  String get measureBp;

  /// No description provided for @contextRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose (required for glucose)'**
  String get contextRequired;

  /// No description provided for @optionalWord.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optionalWord;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @readingHistory.
  ///
  /// In en, this message translates to:
  /// **'Reading History'**
  String get readingHistory;

  /// No description provided for @readingsTab.
  ///
  /// In en, this message translates to:
  /// **'Readings'**
  String get readingsTab;

  /// No description provided for @summaryTab.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summaryTab;

  /// No description provided for @historyEmptyNote.
  ///
  /// In en, this message translates to:
  /// **'Your readings will appear here once you log your first one. Tap the + button on the home screen to start.'**
  String get historyEmptyNote;

  /// No description provided for @noReadingsMatch.
  ///
  /// In en, this message translates to:
  /// **'No readings match this filter'**
  String get noReadingsMatch;

  /// No description provided for @noReadingsMatchNote.
  ///
  /// In en, this message translates to:
  /// **'Try another filter to see the rest of your history.'**
  String get noReadingsMatchNote;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @tagPending.
  ///
  /// In en, this message translates to:
  /// **'saved on your phone, not sent yet'**
  String get tagPending;

  /// No description provided for @tagSecondOfTwo.
  ///
  /// In en, this message translates to:
  /// **'second of two readings'**
  String get tagSecondOfTwo;

  /// No description provided for @tagPulseCamera.
  ///
  /// In en, this message translates to:
  /// **'pulse by phone camera'**
  String get tagPulseCamera;

  /// No description provided for @tagPulseCameraValue.
  ///
  /// In en, this message translates to:
  /// **'pulse by phone camera {bpm}'**
  String tagPulseCameraValue(int bpm);

  /// No description provided for @tagCorrected.
  ///
  /// In en, this message translates to:
  /// **'corrected entry'**
  String get tagCorrected;

  /// No description provided for @tagEnteredLater.
  ///
  /// In en, this message translates to:
  /// **'entered later'**
  String get tagEnteredLater;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correct;

  /// No description provided for @tagFasting.
  ///
  /// In en, this message translates to:
  /// **'fasting'**
  String get tagFasting;

  /// No description provided for @tagBeforeMeal.
  ///
  /// In en, this message translates to:
  /// **'before a meal'**
  String get tagBeforeMeal;

  /// No description provided for @tagAfterMeal.
  ///
  /// In en, this message translates to:
  /// **'after a meal'**
  String get tagAfterMeal;

  /// No description provided for @tagAfterMedication.
  ///
  /// In en, this message translates to:
  /// **'after medication'**
  String get tagAfterMedication;

  /// No description provided for @tagAfterExercise.
  ///
  /// In en, this message translates to:
  /// **'after exercise'**
  String get tagAfterExercise;

  /// No description provided for @tagOtherTime.
  ///
  /// In en, this message translates to:
  /// **'other time'**
  String get tagOtherTime;

  /// No description provided for @nothingToSummarise.
  ///
  /// In en, this message translates to:
  /// **'Nothing to summarise yet'**
  String get nothingToSummarise;

  /// No description provided for @nothingToSummariseNote.
  ///
  /// In en, this message translates to:
  /// **'Once you have logged a few readings, your averages and patterns will appear here.'**
  String get nothingToSummariseNote;

  /// No description provided for @avgBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Avg blood pressure'**
  String get avgBloodPressure;

  /// No description provided for @avgGlucose.
  ///
  /// In en, this message translates to:
  /// **'Avg glucose'**
  String get avgGlucose;

  /// No description provided for @totalReadings.
  ///
  /// In en, this message translates to:
  /// **'Total readings'**
  String get totalReadings;

  /// No description provided for @readingsLogged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{reading logged} other{readings logged}}'**
  String readingsLogged(int count);

  /// No description provided for @readingDistribution.
  ///
  /// In en, this message translates to:
  /// **'Reading distribution'**
  String get readingDistribution;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @insightHighShare.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of your readings were above your home target or out of range.'**
  String insightHighShare(int percent);

  /// No description provided for @insightAllInTarget.
  ///
  /// In en, this message translates to:
  /// **'All your readings so far have been within your home targets.'**
  String get insightAllInTarget;

  /// No description provided for @insightLogBoth.
  ///
  /// In en, this message translates to:
  /// **'Logging blood pressure and glucose together gives your risk score the most to work with.'**
  String get insightLogBoth;

  /// No description provided for @insightFourDays.
  ///
  /// In en, this message translates to:
  /// **'Your risk tier is worked out from your readings of the last four days.'**
  String get insightFourDays;

  /// No description provided for @instructionRed.
  ///
  /// In en, this message translates to:
  /// **'Contact your health centre today. If you feel chest pain, breathlessness, weakness on one side or confusion, go to the hospital now.'**
  String get instructionRed;

  /// No description provided for @instructionYellow.
  ///
  /// In en, this message translates to:
  /// **'Above your home target. Measure again as shown in the check below; your clinician will review the result.'**
  String get instructionYellow;

  /// No description provided for @conditionHaemodynamic.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure / pulse'**
  String get conditionHaemodynamic;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @noReadingFourDays.
  ///
  /// In en, this message translates to:
  /// **'No reading in the last four days — log a reading to see your level.'**
  String get noReadingFourDays;

  /// No description provided for @riskTier.
  ///
  /// In en, this message translates to:
  /// **'Risk tier'**
  String get riskTier;

  /// No description provided for @yourLevel.
  ///
  /// In en, this message translates to:
  /// **'Your level'**
  String get yourLevel;

  /// No description provided for @triageClinician.
  ///
  /// In en, this message translates to:
  /// **'Home triage of the last readings: {level}'**
  String triageClinician(String level);

  /// No description provided for @profileOffClinician.
  ///
  /// In en, this message translates to:
  /// **'; verification profile off target'**
  String get profileOffClinician;

  /// No description provided for @triagePatient.
  ///
  /// In en, this message translates to:
  /// **'Your last readings against your home targets: {level}'**
  String triagePatient(String level);

  /// No description provided for @profileOffPatient.
  ///
  /// In en, this message translates to:
  /// **'; your check came out above target'**
  String get profileOffPatient;

  /// No description provided for @higherRiskThanLast.
  ///
  /// In en, this message translates to:
  /// **'Your recent readings suggest a higher risk than the last value alone.'**
  String get higherRiskThanLast;

  /// No description provided for @conditionProbability.
  ///
  /// In en, this message translates to:
  /// **'{condition}: {percent}% calibrated probability of a high or critical reading at the next measurement ({tier}; {model})'**
  String conditionProbability(
    String condition,
    String percent,
    String tier,
    String model,
  );

  /// No description provided for @stateChangeLine.
  ///
  /// In en, this message translates to:
  /// **'State change, last 24 h against the three days before: {value} ({measure})'**
  String stateChangeLine(String value, String measure);

  /// No description provided for @sourceOnlineClinician.
  ///
  /// In en, this message translates to:
  /// **'Risk model (online) combined with the home triage; the model can raise the tier, never lower it.'**
  String get sourceOnlineClinician;

  /// No description provided for @sourceOnlinePatient.
  ///
  /// In en, this message translates to:
  /// **'Checked with your readings and the risk model.'**
  String get sourceOnlinePatient;

  /// No description provided for @sourceOfflineClinician.
  ///
  /// In en, this message translates to:
  /// **'Home triage only ({reason}).'**
  String sourceOfflineClinician(String reason);

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get offline;

  /// No description provided for @sourceOfflinePatient.
  ///
  /// In en, this message translates to:
  /// **'Checked on your phone from your readings.'**
  String get sourceOfflinePatient;

  /// No description provided for @provisionalCutpoints.
  ///
  /// In en, this message translates to:
  /// **'Model tier cut-points are provisional until set with the clinician.'**
  String get provisionalCutpoints;

  /// No description provided for @evolution.
  ///
  /// In en, this message translates to:
  /// **'Evolution'**
  String get evolution;

  /// No description provided for @evolutionNote.
  ///
  /// In en, this message translates to:
  /// **'Last 24 hours compared with the three days before'**
  String get evolutionNote;

  /// No description provided for @evolutionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not enough readings yet: log readings on several days to see how they change.'**
  String get evolutionEmpty;

  /// No description provided for @stable.
  ///
  /// In en, this message translates to:
  /// **'stable'**
  String get stable;

  /// No description provided for @trendTitle.
  ///
  /// In en, this message translates to:
  /// **'Systolic trend — last 14 days'**
  String get trendTitle;

  /// No description provided for @homeTargetBadge.
  ///
  /// In en, this message translates to:
  /// **'Home target < 135/85'**
  String get homeTargetBadge;

  /// No description provided for @noBpIn14Days.
  ///
  /// In en, this message translates to:
  /// **'No blood pressure reading in the last 14 days'**
  String get noBpIn14Days;

  /// No description provided for @greenBandNote.
  ///
  /// In en, this message translates to:
  /// **'Green band: your home target for the upper number, from 110 to 134 mmHg (with the lower number below 85). Keeping your blood pressure there lowers the risk of stroke and heart disease.'**
  String get greenBandNote;

  /// No description provided for @routineNote.
  ///
  /// In en, this message translates to:
  /// **'Usual routine: blood pressure twice a week, morning and evening, two readings each time; glucose once a week, fasting and 90 minutes after lunch. Measure more often when the app asks for a check.'**
  String get routineNote;

  /// No description provided for @actionNone.
  ///
  /// In en, this message translates to:
  /// **'No change needed'**
  String get actionNone;

  /// No description provided for @actionAdvice.
  ///
  /// In en, this message translates to:
  /// **'Advice from your clinician'**
  String get actionAdvice;

  /// No description provided for @actionTreatmentChange.
  ///
  /// In en, this message translates to:
  /// **'Your clinician adjusted your treatment'**
  String get actionTreatmentChange;

  /// No description provided for @actionConsultation.
  ///
  /// In en, this message translates to:
  /// **'Your clinician asks to see you'**
  String get actionConsultation;

  /// No description provided for @actionReferral.
  ///
  /// In en, this message translates to:
  /// **'You are referred for further care'**
  String get actionReferral;

  /// No description provided for @reviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get reviewed;

  /// No description provided for @fromYourClinician.
  ///
  /// In en, this message translates to:
  /// **'From your clinician'**
  String get fromYourClinician;

  /// No description provided for @alertReviewed.
  ///
  /// In en, this message translates to:
  /// **'Alert of {date}, reviewed {reviewed}'**
  String alertReviewed(String date, String reviewed);

  /// No description provided for @sourceRule.
  ///
  /// In en, this message translates to:
  /// **'Guideline rule'**
  String get sourceRule;

  /// No description provided for @sourceModel.
  ///
  /// In en, this message translates to:
  /// **'Risk model'**
  String get sourceModel;

  /// No description provided for @sourceNonTransmission.
  ///
  /// In en, this message translates to:
  /// **'No readings received'**
  String get sourceNonTransmission;

  /// No description provided for @verdictConfirmed.
  ///
  /// In en, this message translates to:
  /// **'True alert'**
  String get verdictConfirmed;

  /// No description provided for @verdictNotSignificant.
  ///
  /// In en, this message translates to:
  /// **'False alert'**
  String get verdictNotSignificant;

  /// No description provided for @verdictUncertain.
  ///
  /// In en, this message translates to:
  /// **'Uncertain'**
  String get verdictUncertain;

  /// No description provided for @clinicalActionNone.
  ///
  /// In en, this message translates to:
  /// **'No action'**
  String get clinicalActionNone;

  /// No description provided for @clinicalActionAdvice.
  ///
  /// In en, this message translates to:
  /// **'Advice'**
  String get clinicalActionAdvice;

  /// No description provided for @clinicalActionTreatment.
  ///
  /// In en, this message translates to:
  /// **'Dose or drug change'**
  String get clinicalActionTreatment;

  /// No description provided for @clinicalActionConsultation.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get clinicalActionConsultation;

  /// No description provided for @clinicalActionReferral.
  ///
  /// In en, this message translates to:
  /// **'Referral'**
  String get clinicalActionReferral;

  /// No description provided for @checkupPeriodSuffix.
  ///
  /// In en, this message translates to:
  /// **' (checkup period {days} days)'**
  String checkupPeriodSuffix(int days);

  /// No description provided for @noReadingSince.
  ///
  /// In en, this message translates to:
  /// **'No reading since {date}{period}'**
  String noReadingSince(String date, String period);

  /// No description provided for @noReadingInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No reading within the checkup period'**
  String get noReadingInPeriod;

  /// No description provided for @noReadingForDays.
  ///
  /// In en, this message translates to:
  /// **'No reading for more than {days} days'**
  String noReadingForDays(int days);

  /// No description provided for @bpProfileOff.
  ///
  /// In en, this message translates to:
  /// **'7-day profile off target: mean {sbp}/{dbp} mmHg over {readings} readings, {days} days'**
  String bpProfileOff(String sbp, String dbp, String readings, String days);

  /// No description provided for @glucoseProfileOff.
  ///
  /// In en, this message translates to:
  /// **'Glucose profile off target: mean {before} before and {after} mmol/L after meals'**
  String glucoseProfileOff(String before, String after);

  /// No description provided for @triggerPulse.
  ///
  /// In en, this message translates to:
  /// **'pulse {value} bpm'**
  String triggerPulse(String value);

  /// No description provided for @triggerGlucose.
  ///
  /// In en, this message translates to:
  /// **'glucose {value} mmol/L'**
  String triggerGlucose(String value);

  /// No description provided for @trendRising.
  ///
  /// In en, this message translates to:
  /// **'rising'**
  String get trendRising;

  /// No description provided for @trendFalling.
  ///
  /// In en, this message translates to:
  /// **'falling'**
  String get trendFalling;

  /// No description provided for @trendTooFew.
  ///
  /// In en, this message translates to:
  /// **'too few readings'**
  String get trendTooFew;

  /// No description provided for @escalated.
  ///
  /// In en, this message translates to:
  /// **'Escalated'**
  String get escalated;

  /// No description provided for @neverReviewed.
  ///
  /// In en, this message translates to:
  /// **'never reviewed'**
  String get neverReviewed;

  /// No description provided for @daysSinceReview.
  ///
  /// In en, this message translates to:
  /// **'{days} d since last review'**
  String daysSinceReview(int days);

  /// No description provided for @escalatedToYou.
  ///
  /// In en, this message translates to:
  /// **'Escalated to you as alternate: another clinician\'s patient'**
  String get escalatedToYou;

  /// No description provided for @trendLine.
  ///
  /// In en, this message translates to:
  /// **'14-day trend: systolic {sbp}, glucose {glucose}'**
  String trendLine(String sbp, String glucose);

  /// No description provided for @thresholdsLine.
  ///
  /// In en, this message translates to:
  /// **'Thresholds {version}'**
  String thresholdsLine(String version);

  /// No description provided for @modelSuffix.
  ///
  /// In en, this message translates to:
  /// **' · model {version}'**
  String modelSuffix(String version);

  /// No description provided for @probabilitySuffix.
  ///
  /// In en, this message translates to:
  /// **' · calibrated P(alert) {percent}%'**
  String probabilitySuffix(String percent);

  /// No description provided for @verdict.
  ///
  /// In en, this message translates to:
  /// **'Verdict'**
  String get verdict;

  /// No description provided for @eventOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get eventOpen;

  /// No description provided for @reviewedSuffix.
  ///
  /// In en, this message translates to:
  /// **' · reviewed {date}'**
  String reviewedSuffix(String date);

  /// No description provided for @verdictNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Could not save the verdict: {error}'**
  String verdictNotSaved(String error);

  /// No description provided for @actionTaken.
  ///
  /// In en, this message translates to:
  /// **'Action taken'**
  String get actionTaken;

  /// No description provided for @verdictCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional) — serves as the clinical note'**
  String get verdictCommentHint;

  /// No description provided for @sendCommentToPatient.
  ///
  /// In en, this message translates to:
  /// **'Send the comment to the patient'**
  String get sendCommentToPatient;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @closeAlert.
  ///
  /// In en, this message translates to:
  /// **'Close the alert'**
  String get closeAlert;

  /// No description provided for @ageNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'age not recorded'**
  String get ageNotRecorded;

  /// No description provided for @ageBand.
  ///
  /// In en, this message translates to:
  /// **'{low}–{high} yrs'**
  String ageBand(int low, int high);

  /// No description provided for @messagePatient.
  ///
  /// In en, this message translates to:
  /// **'Message patient'**
  String get messagePatient;

  /// No description provided for @readingHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading history'**
  String get readingHistoryTitle;

  /// No description provided for @noClinicalInfo.
  ///
  /// In en, this message translates to:
  /// **'No clinical information recorded for this patient yet.'**
  String get noClinicalInfo;

  /// No description provided for @conditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditions;

  /// No description provided for @medications.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications;

  /// No description provided for @readingsNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load readings.\n{error}'**
  String readingsNotLoaded(String error);

  /// No description provided for @patientNoReadings.
  ///
  /// In en, this message translates to:
  /// **'This patient has not logged any readings yet.'**
  String get patientNoReadings;

  /// No description provided for @provReplaced.
  ///
  /// In en, this message translates to:
  /// **'replaced by a correction'**
  String get provReplaced;

  /// No description provided for @provCorrection.
  ///
  /// In en, this message translates to:
  /// **'correction of an earlier entry'**
  String get provCorrection;

  /// No description provided for @provSecondOfTwo.
  ///
  /// In en, this message translates to:
  /// **'second of two readings (first {first})'**
  String provSecondOfTwo(String first);

  /// No description provided for @provEntered.
  ///
  /// In en, this message translates to:
  /// **'entered {date}'**
  String provEntered(String date);

  /// No description provided for @provQuality.
  ///
  /// In en, this message translates to:
  /// **'quality check: {flag}'**
  String provQuality(String flag);

  /// No description provided for @bpmByCamera.
  ///
  /// In en, this message translates to:
  /// **'bpm by phone camera'**
  String get bpmByCamera;

  /// No description provided for @checkupPeriod.
  ///
  /// In en, this message translates to:
  /// **'Checkup period'**
  String get checkupPeriod;

  /// No description provided for @periodDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String periodDays(int days);

  /// No description provided for @currentSuffix.
  ///
  /// In en, this message translates to:
  /// **'  (current)'**
  String get currentSuffix;

  /// No description provided for @alertsAndVerdicts.
  ///
  /// In en, this message translates to:
  /// **'Alerts and verdicts'**
  String get alertsAndVerdicts;

  /// No description provided for @checkupEvery.
  ///
  /// In en, this message translates to:
  /// **'Checkup every {days} d'**
  String checkupEvery(int days);

  /// No description provided for @defaultSuffix.
  ///
  /// In en, this message translates to:
  /// **' (default)'**
  String get defaultSuffix;

  /// No description provided for @alertsNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load alerts: {error}'**
  String alertsNotLoaded(String error);

  /// No description provided for @noAlertForPatient.
  ///
  /// In en, this message translates to:
  /// **'No alert recorded for this patient.'**
  String get noAlertForPatient;

  /// No description provided for @noClinicianWithCode.
  ///
  /// In en, this message translates to:
  /// **'No clinician has this code.'**
  String get noClinicianWithCode;

  /// No description provided for @ownCode.
  ///
  /// In en, this message translates to:
  /// **'This is your own code.'**
  String get ownCode;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get enterYourName;

  /// No description provided for @ageRange.
  ///
  /// In en, this message translates to:
  /// **'Please enter an age between 1 and 120.'**
  String get ageRange;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileTitle;

  /// No description provided for @aboutYou.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get aboutYou;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @sex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sex;

  /// No description provided for @bloodType.
  ///
  /// In en, this message translates to:
  /// **'Blood type'**
  String get bloodType;

  /// No description provided for @medical.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get medical;

  /// No description provided for @conditionsHint.
  ///
  /// In en, this message translates to:
  /// **'One per line\ne.g. Hypertension\nType 2 Diabetes'**
  String get conditionsHint;

  /// No description provided for @currentMedicationsField.
  ///
  /// In en, this message translates to:
  /// **'Current medications'**
  String get currentMedicationsField;

  /// No description provided for @medicationsHint.
  ///
  /// In en, this message translates to:
  /// **'One per line\ne.g. Amlodipine 5mg'**
  String get medicationsHint;

  /// No description provided for @emergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact'**
  String get emergencyContact;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @managedByCareTeam.
  ///
  /// In en, this message translates to:
  /// **'Managed by your care team'**
  String get managedByCareTeam;

  /// No description provided for @accountType.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get accountType;

  /// No description provided for @patient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patient;

  /// No description provided for @assignedClinician.
  ///
  /// In en, this message translates to:
  /// **'Assigned clinician'**
  String get assignedClinician;

  /// No description provided for @linked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get linked;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @noBackCamera.
  ///
  /// In en, this message translates to:
  /// **'This phone has no back camera to measure the pulse.'**
  String get noBackCamera;

  /// No description provided for @cameraNotStarted.
  ///
  /// In en, this message translates to:
  /// **'The camera could not start: {error}'**
  String cameraNotStarted(String error);

  /// No description provided for @cameraNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'TeleMonitor is not allowed to use the camera. Allow it in the phone settings (Apps, TeleMonitor, Permissions), then try again.'**
  String get cameraNotAllowed;

  /// No description provided for @cameraNotStartedCode.
  ///
  /// In en, this message translates to:
  /// **'The camera could not start ({code}).'**
  String cameraNotStartedCode(String code);

  /// No description provided for @pulseWithCamera.
  ///
  /// In en, this message translates to:
  /// **'Pulse with the camera'**
  String get pulseWithCamera;

  /// No description provided for @noFlash.
  ///
  /// In en, this message translates to:
  /// **'The flash could not be turned on: measure near a bright light.'**
  String get noFlash;

  /// No description provided for @pulseHowTo.
  ///
  /// In en, this message translates to:
  /// **'Stay seated. Cover the back camera and the flash with the tip of your index finger, without pressing, and keep still for about 20 seconds. The flash lights your finger and the camera follows the blood that each heartbeat brings. No picture or video is kept.'**
  String get pulseHowTo;

  /// No description provided for @pulseFingerMoved.
  ///
  /// In en, this message translates to:
  /// **'Your finger moved, so the measurement starts again. Cover the camera and the flash.'**
  String get pulseFingerMoved;

  /// No description provided for @pulseCover.
  ///
  /// In en, this message translates to:
  /// **'Cover the camera and the flash with your fingertip.'**
  String get pulseCover;

  /// No description provided for @pulseStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting the camera…'**
  String get pulseStarting;

  /// No description provided for @pulseFingerDetected.
  ///
  /// In en, this message translates to:
  /// **'Finger detected. Keep still…'**
  String get pulseFingerDetected;

  /// No description provided for @pulseMeasuring.
  ///
  /// In en, this message translates to:
  /// **'Measuring. Keep still and breathe normally.'**
  String get pulseMeasuring;

  /// No description provided for @pulseResultNote.
  ///
  /// In en, this message translates to:
  /// **'Measured with the phone camera. It is shown to you and your clinician for information: your monitor\'s pulse remains the reference, and the alerts use your monitor\'s readings.'**
  String get pulseResultNote;

  /// No description provided for @pulseVeryLow.
  ///
  /// In en, this message translates to:
  /// **'This pulse is very low. Sit, rest for five minutes and measure again; if your monitor shows a pulse, enter it too. If you feel unwell (chest pain, breathlessness, fainting), go to the nearest health centre without waiting.'**
  String get pulseVeryLow;

  /// No description provided for @pulseVeryHigh.
  ///
  /// In en, this message translates to:
  /// **'This pulse is very high. Sit, rest for five minutes and measure again; if your monitor shows a pulse, enter it too. If you feel unwell (chest pain, breathlessness, fainting), go to the nearest health centre without waiting.'**
  String get pulseVeryHigh;

  /// No description provided for @useThisValue.
  ///
  /// In en, this message translates to:
  /// **'Use this value'**
  String get useThisValue;

  /// No description provided for @pulseFailed.
  ///
  /// In en, this message translates to:
  /// **'The signal was not steady enough to give a pulse. Keep the finger still and press lightly: pressing hard stops the blood. Cold fingers give a weak signal; warm your hand first. If it still fails, use your monitor\'s pulse.'**
  String get pulseFailed;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @photoOf.
  ///
  /// In en, this message translates to:
  /// **'Photo of {name}'**
  String photoOf(String name);

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profilePhoto;

  /// No description provided for @photoNoteClinician.
  ///
  /// In en, this message translates to:
  /// **'Optional. Your patients see it beside your messages, so they know who follows them.'**
  String get photoNoteClinician;

  /// No description provided for @photoNotePatient.
  ///
  /// In en, this message translates to:
  /// **'Optional. Only you and your clinician can see it; it helps your clinician recognise you at the health centre. You can remove it at any time.'**
  String get photoNotePatient;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from the gallery'**
  String get chooseFromGallery;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove the photo'**
  String get removePhoto;

  /// No description provided for @photoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Photo removed.'**
  String get photoRemoved;

  /// No description provided for @photoSaved.
  ///
  /// In en, this message translates to:
  /// **'Photo saved.'**
  String get photoSaved;

  /// No description provided for @photoNotUpdated.
  ///
  /// In en, this message translates to:
  /// **'Could not update the photo: {error}'**
  String photoNotUpdated(String error);

  /// No description provided for @notAnImage.
  ///
  /// In en, this message translates to:
  /// **'This file is not an image the app can read.'**
  String get notAnImage;

  /// No description provided for @photoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This photo is too large. Please choose another one.'**
  String get photoTooLarge;

  /// No description provided for @noEnrolmentCode.
  ///
  /// In en, this message translates to:
  /// **'No enrolment code has been issued for your account yet. Contact the system administrator — without one, patients cannot register to you.'**
  String get noEnrolmentCode;

  /// No description provided for @yourEnrolmentCode.
  ///
  /// In en, this message translates to:
  /// **'Your enrolment code'**
  String get yourEnrolmentCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @giveCodeNote.
  ///
  /// In en, this message translates to:
  /// **'Give this code to a patient so they can register and be linked to you.'**
  String get giveCodeNote;

  /// No description provided for @bpCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'7-day blood pressure check'**
  String get bpCheckTitle;

  /// No description provided for @glucoseCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'One-day glucose check'**
  String get glucoseCheckTitle;

  /// No description provided for @bpCheckHow.
  ///
  /// In en, this message translates to:
  /// **'Every morning and every evening for 7 days: sit and rest 5 minutes, then take two readings one minute apart and log both.'**
  String get bpCheckHow;

  /// No description provided for @glucoseCheckHow.
  ///
  /// In en, this message translates to:
  /// **'During one day: before and 90 minutes after each of your three meals (6 readings). Choose \"Before meal\" or \"After meal\" when you log each one.'**
  String get glucoseCheckHow;

  /// No description provided for @bpCheckProgress.
  ///
  /// In en, this message translates to:
  /// **'{readings} of {expected} readings · {days} · until {date}'**
  String bpCheckProgress(int readings, int expected, String days, String date);

  /// No description provided for @glucoseCheckProgress.
  ///
  /// In en, this message translates to:
  /// **'Before meals: {before} of 3 · after meals: {after} of 3 · until {date}'**
  String glucoseCheckProgress(int before, int after, String date);

  /// No description provided for @bpCheckMean.
  ///
  /// In en, this message translates to:
  /// **'Average {value} mmHg (target below 135/85)'**
  String bpCheckMean(String value);

  /// No description provided for @meanBeforeMeals.
  ///
  /// In en, this message translates to:
  /// **'before meals: {value} mmol/L (target 7 or less)'**
  String meanBeforeMeals(String value);

  /// No description provided for @meanAfterMeals.
  ///
  /// In en, this message translates to:
  /// **'after meals: {value} mmol/L (target 10 or less)'**
  String meanAfterMeals(String value);

  /// No description provided for @averageOf.
  ///
  /// In en, this message translates to:
  /// **'Average {value}'**
  String averageOf(String value);

  /// No description provided for @joinedBySemicolon.
  ///
  /// In en, this message translates to:
  /// **'{first}; {second}'**
  String joinedBySemicolon(String first, String second);

  /// No description provided for @checkInProgressClinician.
  ///
  /// In en, this message translates to:
  /// **'In progress.'**
  String get checkInProgressClinician;

  /// No description provided for @checkOffTargetClinician.
  ///
  /// In en, this message translates to:
  /// **'Off target: teleconsultation (red event in the queue).'**
  String get checkOffTargetClinician;

  /// No description provided for @checkOffTargetPatient.
  ///
  /// In en, this message translates to:
  /// **'Your average is above the target. Your clinician has the result; contact your health centre.'**
  String get checkOffTargetPatient;

  /// No description provided for @checkOnTargetClinician.
  ///
  /// In en, this message translates to:
  /// **'On target.'**
  String get checkOnTargetClinician;

  /// No description provided for @checkOnTargetPatient.
  ///
  /// In en, this message translates to:
  /// **'Your average is on target. Keep measuring as usual.'**
  String get checkOnTargetPatient;

  /// No description provided for @checkIncompleteClinician.
  ///
  /// In en, this message translates to:
  /// **'Incomplete: too few readings to conclude.'**
  String get checkIncompleteClinician;

  /// No description provided for @checkIncompletePatient.
  ///
  /// In en, this message translates to:
  /// **'Not enough readings to conclude. Contact your health centre or start the check again.'**
  String get checkIncompletePatient;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgress;

  /// No description provided for @aboveTarget.
  ///
  /// In en, this message translates to:
  /// **'Above target'**
  String get aboveTarget;

  /// No description provided for @onTarget.
  ///
  /// In en, this message translates to:
  /// **'On target'**
  String get onTarget;

  /// No description provided for @incomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get incomplete;

  /// No description provided for @noClinicianYet.
  ///
  /// In en, this message translates to:
  /// **'No clinician connected yet'**
  String get noClinicianYet;

  /// No description provided for @noClinicianYetNote.
  ///
  /// In en, this message translates to:
  /// **'Enter the code your doctor gives you to start a conversation with them.'**
  String get noClinicianYetNote;

  /// No description provided for @connectToAClinician.
  ///
  /// In en, this message translates to:
  /// **'Connect to a clinician'**
  String get connectToAClinician;

  /// No description provided for @couldNotSend.
  ///
  /// In en, this message translates to:
  /// **'Could not send: {error}'**
  String couldNotSend(String error);

  /// No description provided for @messagesNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load messages.\n{error}'**
  String messagesNotLoaded(String error);

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.\nStart the conversation below.'**
  String get noMessagesYet;

  /// No description provided for @typeAMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeAMessage;

  /// No description provided for @presenceOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get presenceOffline;

  /// No description provided for @presenceOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get presenceOnline;

  /// No description provided for @lastSeenMinutes.
  ///
  /// In en, this message translates to:
  /// **'Last seen {n} min ago'**
  String lastSeenMinutes(int n);

  /// No description provided for @lastSeenHours.
  ///
  /// In en, this message translates to:
  /// **'Last seen {n} h ago'**
  String lastSeenHours(int n);

  /// No description provided for @lastSeenYesterday.
  ///
  /// In en, this message translates to:
  /// **'Last seen yesterday'**
  String get lastSeenYesterday;

  /// No description provided for @lastSeenDays.
  ///
  /// In en, this message translates to:
  /// **'Last seen {n} days ago'**
  String lastSeenDays(int n);

  /// No description provided for @noClinicianConnected.
  ///
  /// In en, this message translates to:
  /// **'No clinician connected'**
  String get noClinicianConnected;

  /// No description provided for @noClinicianConnectedNote.
  ///
  /// In en, this message translates to:
  /// **'You can record readings now, but nobody is reviewing them yet. Enter the code your doctor gives you to connect.'**
  String get noClinicianConnectedNote;

  /// No description provided for @findCareNearYou.
  ///
  /// In en, this message translates to:
  /// **'Find care near you'**
  String get findCareNearYou;

  /// No description provided for @findHospitalNearYou.
  ///
  /// In en, this message translates to:
  /// **'Find a hospital near you'**
  String get findHospitalNearYou;

  /// No description provided for @tapCategory.
  ///
  /// In en, this message translates to:
  /// **'Tap a category to see what is nearby in Google Maps.'**
  String get tapCategory;

  /// No description provided for @careUrgentNote.
  ///
  /// In en, this message translates to:
  /// **'Your recent readings are in a range that needs attention. If you feel unwell, go to a hospital rather than waiting for your next appointment.'**
  String get careUrgentNote;

  /// No description provided for @mapsNotOpened.
  ///
  /// In en, this message translates to:
  /// **'Could not open Maps on this device. Please search for \"pharmacie near me\" in your browser.'**
  String get mapsNotOpened;

  /// No description provided for @locationNote.
  ///
  /// In en, this message translates to:
  /// **'TeleMonitor does not access or store your location. The search is handled by Google Maps on your device.'**
  String get locationNote;

  /// No description provided for @carePharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get carePharmacy;

  /// No description provided for @careHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get careHospital;

  /// No description provided for @careClinic.
  ///
  /// In en, this message translates to:
  /// **'Clinic / Health centre'**
  String get careClinic;

  /// No description provided for @careLaboratory.
  ///
  /// In en, this message translates to:
  /// **'Laboratory'**
  String get careLaboratory;

  /// No description provided for @carePharmacyNote.
  ///
  /// In en, this message translates to:
  /// **'Collect medication, or have your blood pressure checked — many pharmacies offer this.'**
  String get carePharmacyNote;

  /// No description provided for @careHospitalNote.
  ///
  /// In en, this message translates to:
  /// **'For urgent care, or when your readings are in the high or critical range.'**
  String get careHospitalNote;

  /// No description provided for @careClinicNote.
  ///
  /// In en, this message translates to:
  /// **'For a routine consultation or follow-up visit.'**
  String get careClinicNote;

  /// No description provided for @careLaboratoryNote.
  ///
  /// In en, this message translates to:
  /// **'For blood glucose, HbA1c and other laboratory tests.'**
  String get careLaboratoryNote;

  /// No description provided for @latestReadingNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Your latest reading needs attention'**
  String get latestReadingNeedsAttention;

  /// No description provided for @careKinds.
  ///
  /// In en, this message translates to:
  /// **'Pharmacies, clinics, hospitals and laboratories'**
  String get careKinds;

  /// No description provided for @assistantGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello. I can explain your readings, answer general questions about blood pressure and diabetes, and help you decide whether something needs a doctor.\n\nI cannot advise on medication — only your clinician can do that.'**
  String get assistantGreeting;

  /// No description provided for @healthAssistant.
  ///
  /// In en, this message translates to:
  /// **'Health Assistant'**
  String get healthAssistant;

  /// No description provided for @notYourDoctor.
  ///
  /// In en, this message translates to:
  /// **'Automated — not your doctor'**
  String get notYourDoctor;

  /// No description provided for @assistantDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'General information only. It cannot diagnose you or advise on medication. For anything urgent, go to a health facility.'**
  String get assistantDisclaimer;

  /// No description provided for @askHealthQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ask a health question...'**
  String get askHealthQuestion;

  /// No description provided for @askHealthAssistant.
  ///
  /// In en, this message translates to:
  /// **'Ask the Health Assistant'**
  String get askHealthAssistant;

  /// No description provided for @understandReadings.
  ///
  /// In en, this message translates to:
  /// **'Understand your readings and your condition'**
  String get understandReadings;

  /// No description provided for @assistantOffline.
  ///
  /// In en, this message translates to:
  /// **'The assistant needs an internet connection. Your readings are still saved and will sync when you are back online.'**
  String get assistantOffline;

  /// No description provided for @assistantBusy.
  ///
  /// In en, this message translates to:
  /// **'The assistant is busy right now. Please try again in a few minutes.'**
  String get assistantBusy;

  /// No description provided for @assistantBlocked.
  ///
  /// In en, this message translates to:
  /// **'I am not able to answer that. If it concerns your health, please speak to your clinician.'**
  String get assistantBlocked;

  /// No description provided for @assistantError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong reaching the assistant. Please try again.'**
  String get assistantError;

  /// No description provided for @suggestReadings.
  ///
  /// In en, this message translates to:
  /// **'What do my last readings mean?'**
  String get suggestReadings;

  /// No description provided for @suggestDanger.
  ///
  /// In en, this message translates to:
  /// **'Why is high blood pressure dangerous?'**
  String get suggestDanger;

  /// No description provided for @suggestFood.
  ///
  /// In en, this message translates to:
  /// **'What foods should I be careful with?'**
  String get suggestFood;

  /// No description provided for @suggestHowOften.
  ///
  /// In en, this message translates to:
  /// **'How often should I measure?'**
  String get suggestHowOften;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @riskServiceNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'risk service not configured'**
  String get riskServiceNotConfigured;

  /// No description provided for @riskServiceUnreachable.
  ///
  /// In en, this message translates to:
  /// **'risk service unreachable'**
  String get riskServiceUnreachable;

  /// No description provided for @termsS1Title.
  ///
  /// In en, this message translates to:
  /// **'What TeleMonitor is'**
  String get termsS1Title;

  /// No description provided for @termsS1P1.
  ///
  /// In en, this message translates to:
  /// **'TeleMonitor helps you follow your blood pressure and blood sugar at home with your clinician. You enter your readings; the app compares them with your home targets and your clinician reviews the alerts.'**
  String get termsS1P1;

  /// No description provided for @termsS1P2.
  ///
  /// In en, this message translates to:
  /// **'TeleMonitor does not replace a consultation and is not an emergency service. It never changes your treatment: only your clinician can. If you feel very unwell, go to the nearest health centre or hospital without waiting for an answer in the app.'**
  String get termsS1P2;

  /// No description provided for @termsS2Title.
  ///
  /// In en, this message translates to:
  /// **'The information the app keeps'**
  String get termsS2Title;

  /// No description provided for @termsS2B1.
  ///
  /// In en, this message translates to:
  /// **'• Your account: name and email address.'**
  String get termsS2B1;

  /// No description provided for @termsS2B2.
  ///
  /// In en, this message translates to:
  /// **'• Your profile, if you fill it in: age, sex, height, weight, conditions, medications, phone, emergency contact and an optional photo.'**
  String get termsS2B2;

  /// No description provided for @termsS2B3.
  ///
  /// In en, this message translates to:
  /// **'• Your readings (blood pressure, heart rate, blood sugar, when you measured and your notes), the alerts they raise and your clinician\'s review of them.'**
  String get termsS2B3;

  /// No description provided for @termsS2B4.
  ///
  /// In en, this message translates to:
  /// **'• If you measure your pulse with the phone camera, the pulse found: the images of the camera are read on the phone and dropped at once, never kept or sent.'**
  String get termsS2B4;

  /// No description provided for @termsS2B5.
  ///
  /// In en, this message translates to:
  /// **'• The messages you exchange with your clinician.'**
  String get termsS2B5;

  /// No description provided for @termsS2B6.
  ///
  /// In en, this message translates to:
  /// **'• What the service needs to work: when you last used the app, and the address used to send notifications to your phone.'**
  String get termsS2B6;

  /// No description provided for @termsS3Title.
  ///
  /// In en, this message translates to:
  /// **'Who can see it'**
  String get termsS3Title;

  /// No description provided for @termsS3B1.
  ///
  /// In en, this message translates to:
  /// **'• You.'**
  String get termsS3B1;

  /// No description provided for @termsS3B2.
  ///
  /// In en, this message translates to:
  /// **'• The clinician you connect to, and the colleague they name to replace them when an alert waits too long.'**
  String get termsS3B2;

  /// No description provided for @termsS3B3.
  ///
  /// In en, this message translates to:
  /// **'• The administrator of the system, only to keep it working.'**
  String get termsS3B3;

  /// No description provided for @termsS3P1.
  ///
  /// In en, this message translates to:
  /// **'Your information is stored on Google Firebase servers and travels encrypted. Access rules let each person see only what they are allowed to see.'**
  String get termsS3P1;

  /// No description provided for @termsS3P2.
  ///
  /// In en, this message translates to:
  /// **'When you use the health assistant, your question, age, sex, conditions, medications and recent readings are sent to Google\'s Gemini service to prepare the answer, never your name or contact details. Do not type your name or other personal details in the assistant.'**
  String get termsS3P2;

  /// No description provided for @termsS4Title.
  ///
  /// In en, this message translates to:
  /// **'Research, only if you agree'**
  String get termsS4Title;

  /// No description provided for @termsS4P1.
  ///
  /// In en, this message translates to:
  /// **'If you tick the research box, your information may also be used for medical research on the home follow-up of hypertension and diabetes, by the TeleMonitor project of the GISDIA laboratory, National Higher Polytechnic School of Douala (ENSPD), University of Douala.'**
  String get termsS4P1;

  /// No description provided for @termsS4P2.
  ///
  /// In en, this message translates to:
  /// **'Before any use, your name, email, phone numbers, emergency contact, photo, messages and notes are removed, and your account is replaced by a code. Results are published only as figures about groups of patients, in which no one can be recognised.'**
  String get termsS4P2;

  /// No description provided for @termsS4P3.
  ///
  /// In en, this message translates to:
  /// **'Saying no changes nothing in your care. You can change your choice at any time in your profile; from then on, your information is left out of new research extracts.'**
  String get termsS4P3;

  /// No description provided for @termsS5Title.
  ///
  /// In en, this message translates to:
  /// **'Your rights'**
  String get termsS5Title;

  /// No description provided for @termsS5P1.
  ///
  /// In en, this message translates to:
  /// **'Under Law No. 2024/017 of 23 December 2024 on the protection of personal data in Cameroon, you can see your information (the app shows it to you), have it corrected, withdraw your research consent, and ask for your account and your information to be deleted. For a deletion or any question, ask your clinician or the administrator.'**
  String get termsS5P1;

  /// No description provided for @termsS6Title.
  ///
  /// In en, this message translates to:
  /// **'Keeping your account safe'**
  String get termsS6Title;

  /// No description provided for @termsS6P1.
  ///
  /// In en, this message translates to:
  /// **'Keep your password to yourself. Confirm your email address: it is the only way to set a new password if you forget yours. On a shared phone, sign out when you finish.'**
  String get termsS6P1;

  /// No description provided for @termsS7Title.
  ///
  /// In en, this message translates to:
  /// **'Changes to these terms'**
  String get termsS7Title;

  /// No description provided for @termsS7P1.
  ///
  /// In en, this message translates to:
  /// **'If these terms change, the app shows you the new version and asks you to accept it before you continue.'**
  String get termsS7P1;

  /// No description provided for @termsVersionOf.
  ///
  /// In en, this message translates to:
  /// **'Version of {date}'**
  String termsVersionOf(String date);

  /// No description provided for @updatedTerms.
  ///
  /// In en, this message translates to:
  /// **'Updated terms of use'**
  String get updatedTerms;

  /// No description provided for @termsChanged.
  ///
  /// In en, this message translates to:
  /// **'The terms have changed. Please read them and accept them to continue.'**
  String get termsChanged;

  /// No description provided for @readAndAcceptTerms.
  ///
  /// In en, this message translates to:
  /// **'Please read the terms of use and accept them to continue.'**
  String get readAndAcceptTerms;

  /// No description provided for @acceptAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Accept and continue'**
  String get acceptAndContinue;

  /// No description provided for @messageNotSent.
  ///
  /// In en, this message translates to:
  /// **'A message was not sent: {error}'**
  String messageNotSent(String error);

  /// No description provided for @verdictNotSavedServer.
  ///
  /// In en, this message translates to:
  /// **'A verdict was not saved: {error}'**
  String verdictNotSavedServer(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
