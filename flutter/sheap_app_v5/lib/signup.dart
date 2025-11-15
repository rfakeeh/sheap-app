import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sheap_app_v3/providers/language_provider.dart';
import 'package:sheap_app_v3/l10n/app_localizations.dart';

//import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

//import 'package:sheap_app_v3/background.dart';
import 'package:sheap_app_v3/dropdowns.dart';
import 'package:sheap_app_v3/buttons.dart';

import 'package:sheap_app_v3/welcome.dart';
import 'package:sheap_app_v3/otpverify.dart';
import 'package:sheap_app_v3/models/user_model.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _idCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
    });

    // 5. Get the data from the text fields
    // NOTE: Firebase Auth requires the FULL phone number,
    // including the country code. We'll assume '+966' for Saudi Arabia.
    final String username = _usernameCtrl.text.trim();
    final String id = _idCtrl.text.trim();
    final String phone = _phoneCtrl.text.trim();
    final String fullPhoneNumber = phone;

    if (username.isEmpty || id.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.fillAllFields)),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(fullPhoneNumber)
          .get();

      if (doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.userExists)),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final newUser = AppUser(
        username: username,
        id: id,
        phone: fullPhoneNumber,
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
            phoneNumber: newUser.phone,
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
                          child: Text(''),
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
                              controller: _idCtrl,
                              keyboardType: TextInputType.number,
                              obscureText: true,
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
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                              controller: _phoneCtrl,
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
                    margin: EdgeInsets.all(8.0),
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
                  Container(
                    margin: EdgeInsets.all(8.0),
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
                        AppLocalizations.of(context)!.welcomePage,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 20.0,
                        ),
                      ),
                    ),
                  ),
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
