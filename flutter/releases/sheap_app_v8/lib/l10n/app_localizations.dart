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
  /// **'+966502178700'**
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
  /// **'Signing in ...'**
  String get otpVerifySigning;

  /// No description provided for @otpVerifying.
  ///
  /// In en, this message translates to:
  /// **'VerIfying OTP ...'**
  String get otpVerifying;

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

  /// No description provided for @yourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location now is in '**
  String get yourLocation;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading ...'**
  String get loading;

  /// No description provided for @locationServiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location service is disabled.'**
  String get locationServiceDisabled;

  /// No description provided for @permissionsDenied.
  ///
  /// In en, this message translates to:
  /// **'Permissions are denied.'**
  String get permissionsDenied;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get locations;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @the.
  ///
  /// In en, this message translates to:
  /// **'The '**
  String get the;

  /// No description provided for @my.
  ///
  /// In en, this message translates to:
  /// **'My'**
  String get my;

  /// No description provided for @holy.
  ///
  /// In en, this message translates to:
  /// **'Holy'**
  String get holy;

  /// No description provided for @important.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get important;

  /// No description provided for @holyLocations.
  ///
  /// In en, this message translates to:
  /// **'Holy Locations'**
  String get holyLocations;

  /// No description provided for @hajjLocations.
  ///
  /// In en, this message translates to:
  /// **'Hajj Locations'**
  String get hajjLocations;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search ...'**
  String get search;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get noResults;

  /// No description provided for @createdGroups.
  ///
  /// In en, this message translates to:
  /// **'You have created'**
  String get createdGroups;

  /// No description provided for @createNewGroup.
  ///
  /// In en, this message translates to:
  /// **'Add  Group'**
  String get createNewGroup;

  /// No description provided for @noCreatedGroups.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any groups.'**
  String get noCreatedGroups;

  /// No description provided for @joinedGroups.
  ///
  /// In en, this message translates to:
  /// **'You have joined'**
  String get joinedGroups;

  /// No description provided for @joinNewGroup.
  ///
  /// In en, this message translates to:
  /// **'Join Group'**
  String get joinNewGroup;

  /// No description provided for @noJoinedGroups.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t joined any active groups yet.'**
  String get noJoinedGroups;

  /// No description provided for @trackingOn.
  ///
  /// In en, this message translates to:
  /// **'Tracking On'**
  String get trackingOn;

  /// No description provided for @enableTracking.
  ///
  /// In en, this message translates to:
  /// **'Activate Tracking'**
  String get enableTracking;

  /// No description provided for @trackingOff.
  ///
  /// In en, this message translates to:
  /// **'Tracking Off'**
  String get trackingOff;

  /// No description provided for @disableTracking.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Tracking'**
  String get disableTracking;

  /// No description provided for @leader.
  ///
  /// In en, this message translates to:
  /// **'Leader'**
  String get leader;

  /// No description provided for @allMembersSafe.
  ///
  /// In en, this message translates to:
  /// **'All members are safe.'**
  String get allMembersSafe;

  /// No description provided for @outsideGeofence.
  ///
  /// In en, this message translates to:
  /// **'member(s) are outside geofence'**
  String get outsideGeofence;

  /// No description provided for @sentSOS.
  ///
  /// In en, this message translates to:
  /// **'member(s) have sent SOS'**
  String get sentSOS;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get and;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit Group'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete Group'**
  String get delete;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit Group'**
  String get exit;

  /// No description provided for @navigateToDestination.
  ///
  /// In en, this message translates to:
  /// **'To Destination'**
  String get navigateToDestination;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get destination;

  /// No description provided for @navigateToLeader.
  ///
  /// In en, this message translates to:
  /// **'To Leader'**
  String get navigateToLeader;

  /// No description provided for @alertGroup.
  ///
  /// In en, this message translates to:
  /// **'Alert Group'**
  String get alertGroup;

  /// No description provided for @showQR.
  ///
  /// In en, this message translates to:
  /// **'Show Group QR'**
  String get showQR;

  /// No description provided for @addMemberByPhone.
  ///
  /// In en, this message translates to:
  /// **'Invite By Phone Number'**
  String get addMemberByPhone;

  /// No description provided for @addMemberByQR.
  ///
  /// In en, this message translates to:
  /// **'Invite By QR Code'**
  String get addMemberByQR;

  /// No description provided for @scanQrToJoin.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR to join the group'**
  String get scanQrToJoin;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @inviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite Member'**
  String get inviteMember;

  /// No description provided for @memberAcceptance.
  ///
  /// In en, this message translates to:
  /// **'An invitation will be sent. The member must accept to join.'**
  String get memberAcceptance;

  /// No description provided for @enterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a phone number.'**
  String get enterPhoneNumber;

  /// No description provided for @numberNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'This number is not registered in the app.'**
  String get numberNotRegistered;

  /// No description provided for @groupNotFound.
  ///
  /// In en, this message translates to:
  /// **'Group not found.'**
  String get groupNotFound;

  /// No description provided for @userAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'This user is already a member of the group.'**
  String get userAlreadyMember;

  /// No description provided for @receivedGroupInvitation.
  ///
  /// In en, this message translates to:
  /// **'You received a new group invitation.'**
  String get receivedGroupInvitation;

  /// No description provided for @invitationSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent successfully.'**
  String get invitationSent;

  /// No description provided for @invitationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send invitation. Please try again.'**
  String get invitationFailed;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
  String get confirmDelete;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @questionMark.
  ///
  /// In en, this message translates to:
  /// **'?'**
  String get questionMark;

  /// No description provided for @groupDeleted.
  ///
  /// In en, this message translates to:
  /// **'Group deleted successfully.'**
  String get groupDeleted;

  /// No description provided for @groupDeletedFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete group.'**
  String get groupDeletedFailed;

  /// No description provided for @joinSuccess.
  ///
  /// In en, this message translates to:
  /// **'You are now a member of the group.'**
  String get joinSuccess;

  /// No description provided for @joinAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You are already a member of the group.'**
  String get joinAlreadyMember;

  /// No description provided for @scanQR.
  ///
  /// In en, this message translates to:
  /// **'Scan QR to join a group'**
  String get scanQR;

  /// No description provided for @confirmJoinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join this group?'**
  String get confirmJoinGroup;

  /// No description provided for @groupId.
  ///
  /// In en, this message translates to:
  /// **'Group ID'**
  String get groupId;

  /// No description provided for @confirmExit.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit the group?'**
  String get confirmExit;

  /// No description provided for @exitSuccess.
  ///
  /// In en, this message translates to:
  /// **'You have exited the group'**
  String get exitSuccess;

  /// No description provided for @exitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to exit group'**
  String get exitFailed;

  /// No description provided for @unknownAddress.
  ///
  /// In en, this message translates to:
  /// **'Unknown Address'**
  String get unknownAddress;
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
