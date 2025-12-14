import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';

class LanguageDropdown extends StatelessWidget {
  const LanguageDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, _) {
        return DropdownButton<Locale>(
          dropdownColor: Colors.white,
          focusColor: Colors.white,
          value: langProvider.locale, // always synced with provider
          style: const TextStyle(color: Colors.black),
          iconEnabledColor: Colors.black,
          items: const [
            DropdownMenuItem(value: Locale('en'), child: Text('E')),
            DropdownMenuItem(value: Locale('ar'), child: Text('ع')),
          ],
          onChanged: (Locale? newLocale) {
            if (newLocale != null) {
              // Just call provider; Consumer will rebuild automatically
              langProvider.setLocale(newLocale);
            }
          },
        );
      },
    );
  }
}
