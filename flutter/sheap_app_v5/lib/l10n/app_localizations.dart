import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @welcomePage.
  ///
  /// In en, this message translates to:
  /// **'Welcome Page'**
  String get welcomePage;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @mapView.
  ///
  /// In en, this message translates to:
  /// **'Map View'**
  String get mapView;

  /// No description provided for @fillFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill the following fields'**
  String get fillFields;

  /// No description provided for @userName.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get userName;

  /// No description provided for @usernameHint.
  ///
  /// In en, this message translates to:
  /// **'three-part name'**
  String get usernameHint;

  /// No description provided for @userId.
  ///
  /// In en, this message translates to:
  /// **'ID / Iqama number'**
  String get userId;

  /// No description provided for @userIdHint.
  ///
  /// In en, this message translates to:
  /// **'12*********'**
  String get userIdHint;

  /// No description provided for @userPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get userPhone;

  /// No description provided for @userPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'+966 502 178 700'**
  String get userPhoneHint;

  /// No description provided for @signUpTerms.
  ///
  /// In en, this message translates to:
  /// **'By signing up, I agree to the app\'s Terms of Service and Privacy Policy.'**
  String get signUpTerms;

  /// No description provided for @signInTerms.
  ///
  /// In en, this message translates to:
  /// **'By signing in, I agree to the app\'s Terms of Service and Privacy Policy.'**
  String get signInTerms;

  /// No description provided for @otpVerify.
  ///
  /// In en, this message translates to:
  /// **'OTP Verification'**
  String get otpVerify;

  /// No description provided for @otpVerifyPhone.
  ///
  /// In en, this message translates to:
  /// **'A verification code will be sent to your mobile'**
  String get otpVerifyPhone;

  /// No description provided for @otpVerifyChangePhone.
  ///
  /// In en, this message translates to:
  /// **'Change mobile number'**
  String get otpVerifyChangePhone;

  /// No description provided for @otpVerifyReset.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code? Resend in'**
  String get otpVerifyReset;

  /// No description provided for @otpVerifyAskReset.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP code ?'**
  String get otpVerifyAskReset;

  /// No description provided for @otpVerifySeconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get otpVerifySeconds;

  /// No description provided for @otpVerifySigning.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get otpVerifySigning;

  /// No description provided for @otpVerifyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm OTP'**
  String get otpVerifyConfirm;

  /// No description provided for @fillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill all fields.'**
  String get fillAllFields;

  /// No description provided for @incorrectFields.
  ///
  /// In en, this message translates to:
  /// **'Incorrect ID or phone number.'**
  String get incorrectFields;

  /// No description provided for @userExists.
  ///
  /// In en, this message translates to:
  /// **'A user with this phone number already exists!'**
  String get userExists;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, '**
  String get welcome;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
