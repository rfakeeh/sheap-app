// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get signUp => 'التسجيل';

  @override
  String get signIn => 'الدخول';

  @override
  String get welcomePage => 'الشاشة الرئيسية';

  @override
  String get home => 'الرئيسية';

  @override
  String get mapView => 'عرض الخريطة';

  @override
  String get fillFields => 'فضلا ، أدخل البيانات التالية';

  @override
  String get userName => 'اسم المستخدم';

  @override
  String get usernameHint => 'الاسم الثلاثي';

  @override
  String get userId => 'رقم الهوية / الاقامة';

  @override
  String get userIdHint => '12*********';

  @override
  String get userPhone => 'رقم الهاتف';

  @override
  String get userPhoneHint => '+966 502 178 700';

  @override
  String get signUpTerms =>
      'من خلال التسجيل ، فأنا أوافق على شروط الخدمة وسياسة الخصوصية الخاصة بالتطبيق.';

  @override
  String get signInTerms =>
      'من خلال الدخول ، فأنا أوافق على شروط الخدمة وسياسة الخصوصية الخاصة بالتطبيق.';

  @override
  String get otpVerify => 'رمز التحقق';

  @override
  String get otpVerifyPhone => 'سيتم إرسال رمز التحقق إلى رقم جوالك';

  @override
  String get otpVerifyChangePhone => 'تغيير رقم الجوال';

  @override
  String get otpVerifyReset => 'لم يصلك رمز الدخول؟ أعد الإرسال خلال';

  @override
  String get otpVerifyAskReset => 'إعادة الإرسال ؟';

  @override
  String get otpVerifySeconds => 'ثانية';

  @override
  String get otpVerifySigning => 'جاري تسجيل الدخول';

  @override
  String get otpVerifyConfirm => 'تأكيد رمز التحقق';

  @override
  String get fillAllFields => 'فضلا قم بتعبئة جميع البيانات.';

  @override
  String get incorrectFields => 'رقم هاتف أو هوية غير صحيح!';

  @override
  String get userExists => 'رقم الهاتف هذا مسجل مسبقا.';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get welcome => 'مرحبا ، ';
}
