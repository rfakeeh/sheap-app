import 'package:flutter/material.dart';
//import 'package:provider/provider.dart';
//import 'package:sheap_app_v3/providers/language_provider.dart';
import 'package:sheap_app_v3/l10n/app_localizations.dart';

import 'package:sheap_app_v3/background.dart';
import 'package:sheap_app_v3/dropdowns.dart';
import 'package:sheap_app_v3/logo.dart';
import 'package:sheap_app_v3/buttons.dart';

import 'package:sheap_app_v3/signup.dart';
import 'package:sheap_app_v3/signin.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    //final langProvider = Provider.of<LanguageProvider>(context);
    //bool isArabic = langProvider.locale.languageCode == 'ar';

    return Scaffold(
      //appBar: AppBar(title: Text('Welcome')),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            GradientBackground(),
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
                      alignment: Alignment.center,
                      child: LogoImage(),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: PrimaryButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SignUpPage()),
                        );
                      },
                      child: Text(
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
                          MaterialPageRoute(builder: (context) => SignInPage()),
                        );
                      },
                      child: Text(
                        AppLocalizations.of(context)!.signIn,
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
