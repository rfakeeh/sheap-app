import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sheap_app_v3/providers/language_provider.dart';

class LanguageDropdown extends StatefulWidget {
  const LanguageDropdown({super.key});

  @override
  State<LanguageDropdown> createState() => _LanguageDropdownState();
}

class _LanguageDropdownState extends State<LanguageDropdown> {
  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);

    return DropdownButton<Locale>(
      dropdownColor: Colors.white,
      focusColor: Colors.white,
      value: langProvider.locale,
      //elevation: 5,
      style: TextStyle(color: Colors.black),
      iconEnabledColor: Colors.black,
      items: [
        DropdownMenuItem(value: Locale('en'), child: Text('English')),
        DropdownMenuItem(value: Locale('ar'), child: Text('العربية')),
      ],
      onChanged: (Locale? newLocale) {
        if (newLocale != null) {
          // Here we call our "thermostat" to change the language
          setState(() {
            langProvider.setLocale(newLocale);
          });
        }
      },
    );
  }
}
