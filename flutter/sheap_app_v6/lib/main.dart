import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import '../providers/language_provider.dart';
import '../providers/location_provider.dart'; // Import the stream file
import '../authentication.dart';
import '../l10n/app_localizations.dart';

Future<void> main() async {
  // This ensures all Flutter bindings are ready before we load stuff
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        // 1. Language Provider
        ChangeNotifierProvider(create: (_) => LanguageProvider()),

        // 2. Location Provider (Now a ChangeNotifier)
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, child) {
        return MaterialApp(
          title: 'SHEAP APP',
          locale: langProvider.locale,
          supportedLocales: const [
            Locale('en', ''), // English
            Locale('ar', ''), // Arabic
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            fontFamily: 'IBMPlexSansArabic',
            scaffoldBackgroundColor: Colors.white,
          ),
          home: AuthWrapper(),
        );
      },
    );
  }
}
