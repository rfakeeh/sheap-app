import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';

//import '../background.dart';
import '../dropdowns.dart';
import '../buttons.dart';
import '../modal.dart';

import '../utils/helpers.dart';

import '../otpverify.dart';
import '../repositories/user_repository.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  final UserRepository _userRepository = UserRepository();

  @override
  void dispose() {
    _idCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
    });

    final String id = _idCtrl.text.trim();
    final String phone = _phoneCtrl.text.trim();
    final String phoneNumber = phone;

    if (id.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.fillAllFields)),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // 1. Use the repository to try and fetch the user
    final existingUser = await _userRepository.getUser(phoneNumber);

    // 2. Check if the result is null (meaning a user was NOT found)
    if (existingUser == null) {
      Helpers.showBottomModal(
        context: context,
        page: FullScreenModal(
          icon: Icons.close,
          outerColor: const Color(0xFFFFE6E6),
          innerColor: const Color(0xFFE53935),
          message: AppLocalizations.of(context)!.incorrectFields,
        ),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OTPVerifyPage(
          user: existingUser,
          verificationId: "1234",
          mode: VerificationMode.signIn,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    bool isArabic = langProvider.locale.languageCode == 'ar';

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            //GradientBackground(),
            Container(
              margin: EdgeInsets.all(25.0),
              child: Column(
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: LanguageDropdown(),
                        ),
                        Expanded(child: Align(child: Text(''))),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Image.asset(
                            "assets/images/name.png",
                            height:
                                MediaQuery.of(context).size.height *
                                0.045, // 6% of screen height
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SingleChildScrollView(
                        //padding: EdgeInsets.symmetric(horizontal: 15.0),
                        child: Column(
                          children: [
                            Text(
                              AppLocalizations.of(context)!.signIn,
                              style: TextStyle(
                                fontSize: 34.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 10.0),
                            Text(
                              AppLocalizations.of(context)!.fillFields,
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF626262),
                              ),
                            ),
                            SizedBox(height: 40),
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                AppLocalizations.of(context)!.userId,
                                style: TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                ),
                                textDirection: TextDirection.ltr,
                                textAlign: isArabic
                                    ? TextAlign.right
                                    : TextAlign.left,
                              ),
                            ),
                            SizedBox(height: 5),
                            TextFormField(
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                              controller: _idCtrl,
                              inputFormatters: [
                                EnglishDigitsFormatter(),
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                              keyboardType: TextInputType.number,
                              obscureText: false,
                              decoration: InputDecoration(
                                hint: Text(
                                  AppLocalizations.of(context)!.userIdHint,
                                  textDirection: TextDirection.ltr,
                                  textAlign: isArabic
                                      ? TextAlign.right
                                      : TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    color: Color(0xFF85888E),
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18.0),
                                  borderSide: BorderSide(
                                    color: Color(0xFFD0D5DD),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18.0),
                                  borderSide: BorderSide(
                                    color: Color(0xFFD0D5DD),
                                  ),
                                ),
                                prefixIcon: Icon(Icons.credit_card),
                              ),
                            ),
                            SizedBox(height: 20.0),
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                AppLocalizations.of(context)!.userPhone,
                                style: TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                ),
                                textDirection: TextDirection.ltr,
                                textAlign: isArabic
                                    ? TextAlign.right
                                    : TextAlign.left,
                              ),
                            ),
                            SizedBox(height: 5),
                            TextFormField(
                              textDirection: TextDirection.ltr,
                              textAlign: isArabic
                                  ? TextAlign.right
                                  : TextAlign.left,
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                              controller: _phoneCtrl,
                              inputFormatters: [
                                EnglishDigitsFormatter(),
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hint: Text(
                                  AppLocalizations.of(context)!.userPhoneHint,
                                  textDirection: TextDirection.ltr,
                                  textAlign: isArabic
                                      ? TextAlign.right
                                      : TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    color: Color(0xFF85888E),
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18.0),
                                  borderSide: BorderSide(
                                    color: Color(0xFFD0D5DD),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18.0),
                                  borderSide: BorderSide(
                                    color: Color(0xFFD0D5DD),
                                  ),
                                ),
                                prefixIcon: Icon(Icons.phone_iphone),
                              ),
                            ),
                            SizedBox(height: 40.0),
                            Align(
                              alignment: Alignment.center,
                              child: Text(
                                AppLocalizations.of(context)!.signInTerms,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14.0),
                              ),
                            ),
                            SizedBox(height: 40.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.all(5.0),
                    alignment: Alignment.center,
                    child: PrimaryButton(
                      onPressed: _signIn,
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              AppLocalizations.of(context)!.signIn,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 20.0,
                              ),
                            ),
                    ),
                  ),
                  /*
                  Container(
                    margin: EdgeInsets.all(5.0),
                    alignment: Alignment.center,
                    child: SecondaryButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WelcomePage(),
                          ),
                          (route) => false,
                        );
                      },
                      child: Text(
                        AppLocalizations.of(context)!.back,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 20.0,
                        ),
                      ),
                    ),
                  ),
                  */
                  SizedBox(width: double.infinity),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
