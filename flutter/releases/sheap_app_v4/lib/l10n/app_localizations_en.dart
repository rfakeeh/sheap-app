// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get signUp => 'Sign Up';

  @override
  String get signIn => 'Sign In';

  @override
  String get welcomePage => 'Welcome Page';

  @override
  String get home => 'Home';

  @override
  String get mapView => 'Map View';

  @override
  String get fillFields => 'Please fill the following fields';

  @override
  String get userName => 'Username';

  @override
  String get usernameHint => 'three-part name';

  @override
  String get userId => 'ID / Iqama number';

  @override
  String get userIdHint => '12*********';

  @override
  String get userPhone => 'Phone number';

  @override
  String get userPhoneHint => '+966 502 178 700';

  @override
  String get signUpTerms =>
      'By signing up, I agree to the app\'s Terms of Service and Privacy Policy.';

  @override
  String get signInTerms =>
      'By signing in, I agree to the app\'s Terms of Service and Privacy Policy.';

  @override
  String get otpVerify => 'OTP Verification';

  @override
  String get otpVerifyPhone =>
      'A verification code will be sent to your mobile';

  @override
  String get otpVerifyChangePhone => 'Change mobile number';

  @override
  String get otpVerifyReset => 'Didn\'t receive the code? Resend in';

  @override
  String get otpVerifyAskReset => 'Resend OTP code ?';

  @override
  String get otpVerifySeconds => 'seconds';

  @override
  String get otpVerifySigning => 'Signing in...';

  @override
  String get otpVerifyConfirm => 'Confirm OTP';
}
