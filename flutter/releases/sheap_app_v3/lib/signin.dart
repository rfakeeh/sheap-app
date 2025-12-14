import 'package:flutter/material.dart';
//import 'package:provider/provider.dart';
//import 'package:sheap_app_v3/providers/language_provider.dart';
import 'package:sheap_app_v3/l10n/app_localizations.dart';

import 'package:sheap_app_v3/background.dart';
import 'package:sheap_app_v3/dropdowns.dart';
import 'package:sheap_app_v3/buttons.dart';

import 'package:sheap_app_v3/welcome.dart';
import 'package:sheap_app_v3/home.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    //final langProvider = Provider.of<LanguageProvider>(context);
    //bool isArabic = langProvider.locale.languageCode == 'ar';

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GradientBackground(),
            Container(
              margin: EdgeInsets.all(25.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: LanguageDropdown(),
                      ),
                      Expanded(child: Align(child: Text(''))),
                      Align(alignment: Alignment.centerRight, child: Text('')),
                    ],
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(AppLocalizations.of(context)!.signIn),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: PrimaryButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => HomePage()),
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
