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
import '../models/user_model.dart';
import '../repositories/user_repository.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _nationalIdCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  final UserRepository _userRepository = UserRepository();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _nationalIdCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
    });

    // Get the data from the text fields
    // NOTE: Firebase Auth requires the FULL phone number,
    // including the country code. We'll assume '+966' for Saudi Arabia.
    final String username = _usernameCtrl.text.trim();
    final String nationalId = _nationalIdCtrl.text.trim();
    final String phone = _phoneCtrl.text.trim();
    final String phoneNumber = phone;

    if (username.isEmpty || nationalId.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.fillAllFields)),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // 1. Use the repository to try and fetch the user
      final existingUser = await _userRepository.getUser(phoneNumber);

      // 2. Check if the result is NOT null (meaning a user WAS found)
      if (existingUser != null) {
        Helpers.showBottomModal(
          context: context,
          page: FullScreenModal(
            icon: Icons.close,
            outerColor: const Color(0xFFFFE6E6),
            innerColor: const Color(0xFFE53935),
            message: AppLocalizations.of(context)!.userExists,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final AppUser newUser = AppUser(
        fullName: username,
        nationalId: nationalId,
        phoneNumber: phoneNumber,
        createdAt: DateTime.now(),
      );
      setState(() {
        _isLoading = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPVerifyPage(
            user: newUser,
            verificationId: "1234",
            mode: VerificationMode.signUp,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("An error occurred: $e")));
    }
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
                              AppLocalizations.of(context)!.signUp,
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
                                AppLocalizations.of(context)!.userName,
                                style: TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(height: 5),
                            TextFormField(
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                              controller: _usernameCtrl,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                hint: Text(
                                  AppLocalizations.of(context)!.usernameHint,
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
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                            SizedBox(height: 20.0),
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
                              controller: _nationalIdCtrl,
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
                                AppLocalizations.of(context)!.signUpTerms,
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
                      onPressed: _signUp,
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              AppLocalizations.of(context)!.signUp,
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WelcomePage(),
                          ),
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
