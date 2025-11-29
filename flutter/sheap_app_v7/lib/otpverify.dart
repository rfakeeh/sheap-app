import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

//import '../background.dart';
import '../dropdowns.dart';
import '../buttons.dart';
import '../utils/helpers.dart';

import '../home.dart';

import '../models/user_model.dart';
import '../services/orchestrator.dart';

enum VerificationMode { signUp, signIn }

class OTPVerifyPage extends StatefulWidget {
  final String verificationId;
  final VerificationMode mode;
  final AppUser user;

  const OTPVerifyPage({
    required this.user,
    required this.verificationId,
    required this.mode,
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
  final Orchestrator _orchestrator = Orchestrator();

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

  // Redirect to home page
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

  // This is "Confirm" function
  Future<void> _confirmOTP(bool isArabic) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // (Simulation: We assume OTP code is correct)

      if (widget.mode == VerificationMode.signUp) {
        // Determine locale for logic
        // Assuming you have a way to check locale, e.g., from context or a global variable
        bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

        // Generate the "Base" name (The one we *want* to use)
        String desiredName = isArabic
            ? "مجموعة ${Helpers.getFirstAndLastName(widget.user.fullName)}"
            : "${Helpers.getFirstAndLastName(widget.user.fullName)}'s Group";

        // --- CALL SERVICE ---
        // The service will handle the uniqueness check and the transaction
        await _orchestrator.signUp(
          fullName: widget.user.fullName,
          nationalId: widget.user.nationalId,
          phoneNumber: widget.user.phoneNumber,
          baseGroupName: desiredName,
          isArabic: isArabic,
        );
      }

      // --- THIS IS THE LOGIN PERSISTENCE ---
      // Save the user's phone to local storage
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('loggedInUserPhone', widget.user.phoneNumber);
      // --- END PERSISTENCE ---

      // simulate OTP verification and redirects to home page
      _startTimerLoader(widget.user);
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
        inputFormatters: [EnglishDigitsFormatter()],
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
            borderSide: const BorderSide(color: Color(0xFF73CF96)),
          ),
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
                              widget.user.phoneNumber,
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
                            _isLoading
                                ? Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.otpVerifying,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14.0,
                                        color: Color(0xFF94979C),
                                      ),
                                    ),
                                  )
                                : Align(
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
                            // if (_isLoading) _buildLoadingUI(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: PrimaryButton(
                      onPressed: () {
                        _confirmOTP(isArabic);
                      },
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
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
