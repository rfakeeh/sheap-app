import 'package:flutter/material.dart';
//import 'package:provider/provider.dart';
//import 'package:sheap_app_v3/providers/language_provider.dart';
import 'package:sheap_app_v3/l10n/app_localizations.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

//import 'package:sheap_app_v3/background.dart';
import 'package:sheap_app_v3/dropdowns.dart';
import 'package:sheap_app_v3/buttons.dart';

import 'package:sheap_app_v3/home.dart';

import 'package:sheap_app_v3/models/user_model.dart';

enum VerificationMode { signUp, signIn }

class OTPVerifyPage extends StatefulWidget {
  final String verificationId;
  final VerificationMode mode;
  final AppUser? user;
  final String phoneNumber;

  const OTPVerifyPage({
    required this.verificationId,
    required this.mode,
    required this.phoneNumber,
    this.user,
    super.key,
  });

  @override
  State<OTPVerifyPage> createState() => _OTPVerifyPageState();
}

class _OTPVerifyPageState extends State<OTPVerifyPage> {
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;
  late Timer _timerResend;
  Timer? _timerLoader;
  int _timeLeft = 30;
  bool _isLoading = false;

  void _startTimerResend() {
    _timerResend = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timerResend.cancel();
        }
      });
    });
  }

  // 6.8: Redirect to main page
  void _startTimerLoader(AppUser user) {
    _timerLoader?.cancel();
    _timerLoader = Timer(Duration(seconds: 5), () {
      // 5-second fake load
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomePage(user: user)),
          (route) => false, // Clear all pages behind it
        );
      }
    });
  }

  // 3. This is our NEW "Confirm" function
  Future<void> _confirmOTP() async {
    setState(() {
      _isLoading = true;
    });
    AppUser? userToLogin;

    try {
      // (Simulation: We assume OTP code is correct)

      if (widget.mode == VerificationMode.signIn) {
        // --- SIGN IN LOGIC ---
        // 6.3: Check if user exists
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.phoneNumber)
            .get();

        // Success: Get the user object from Firestore
        userToLogin = AppUser.fromFirestore(doc);
      } else if (widget.mode == VerificationMode.signUp &&
          widget.user != null) {
        // --- SIGN UP LOGIC ---
        // 3.3: Create the new user
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user!.phone)
            .set(widget.user!.toJson());

        // Success: The user object is the one passed from the sign up page
        userToLogin = widget.user;
      }

      // 6.7: Auto-Login (Simulated)
      if (userToLogin != null) {
        // --- THIS IS THE LOGIN PERSISTENCE ---
        // Save the user's phone to local storage
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('loggedInUserPhone', userToLogin.phone);
        // --- END PERSISTENCE ---

        _startTimerLoader(userToLogin);
      } else {
        // This case should not be hit, but it's good to have
        setState(() {
          _isLoading = false;
        });
      }
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
  void initState() {
    super.initState();
    _focusNodes = List.generate(4, (index) => FocusNode());
    _controllers = List.generate(4, (index) => TextEditingController());
    _startTimerResend();
    _timerLoader?.cancel();
  }

  void _resendOTPCode() {
    setState(() {
      _timeLeft = 30;
    });
    _startTimerResend();
  }

  Widget _buildLoadingUI() {
    return Container(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //CircularProgressIndicator(color: Color(0xFF44B36B)),
            Image.asset('assets/images/spinner.gif', width: 60, height: 60),
            SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.otpVerifySigning,
              style: TextStyle(fontSize: 16, color: Color(0xFF414651)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timerResend.cancel();
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _nextField(String value, int index) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 70,
      height: 70,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        onChanged: (value) => _nextField(value, index),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF7F56D9),
        ),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: InputDecoration(
          counterText: "",
          hintText: "-",
          hintStyle: TextStyle(color: Color(0xFFD5D7DA)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: const BorderSide(color: Color(0xFF5A4BDE)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //final langProvider = Provider.of<LanguageProvider>(context);
    //bool isArabic = langProvider.locale.languageCode == 'ar';

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
                              AppLocalizations.of(context)!.otpVerify,
                              style: TextStyle(
                                fontSize: 34.0,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3C32A3),
                              ),
                            ),
                            SizedBox(height: 10.0),
                            Text(
                              AppLocalizations.of(context)!.otpVerifyPhone,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF626262),
                              ),
                            ),
                            Text(
                              widget.phoneNumber,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF626262),
                              ),
                            ),
                            SizedBox(height: 20),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                )!.otpVerifyChangePhone,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF825EF6),
                                ),
                              ),
                            ),
                            SizedBox(height: 40),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildOtpBox(0),
                                  SizedBox(width: 5), // 5 pixel space
                                  _buildOtpBox(1),
                                  SizedBox(width: 5), // 5 pixel space
                                  _buildOtpBox(2),
                                  SizedBox(width: 5), // 5 pixel space
                                  _buildOtpBox(3),
                                ],
                              ),
                            ),
                            SizedBox(height: 40.0),
                            if (!_isLoading)
                              Align(
                                alignment: Alignment.center,
                                child: _timeLeft == 0
                                    ? TextButton(
                                        onPressed: _resendOTPCode,
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.otpVerifyAskReset,
                                          style: TextStyle(
                                            fontSize: 14.0,
                                            color: Color(0xFF5A4BDE),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    // Otherwise, show the countdown
                                    : Text(
                                        "${AppLocalizations.of(context)!.otpVerifyReset} $_timeLeft ${AppLocalizations.of(context)!.otpVerifySeconds}",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14.0,
                                          color: Color(0xFF94979C),
                                        ),
                                      ),
                              ),
                            SizedBox(height: 40.0),
                            if (_isLoading) _buildLoadingUI(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!_isLoading)
                    Container(
                      margin: EdgeInsets.all(8.0),
                      alignment: Alignment.center,
                      child: PrimaryButton(
                        onPressed: _confirmOTP,
                        child: Text(
                          AppLocalizations.of(context)!.otpVerifyConfirm,
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
