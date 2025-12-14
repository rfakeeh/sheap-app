import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Providers
import '../providers/group_provider.dart';
import '../providers/user_provider.dart';
import '../providers/language_provider.dart';
import '../providers/location_provider.dart';
import '../providers/geocoding_provider.dart';
import '../providers/member_geofence_provider.dart';

import '../authentication.dart';
import '../l10n/app_localizations.dart';

Future<void> main() async {
  // This ensures all Flutter bindings are ready before we load stuff
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        // 1) Language Provider (root locale state)
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(),
        ),

        // 2) Location Provider: tracks current user device location
        ChangeNotifierProvider<LocationProvider>(
          create: (_) => LocationProvider(),
        ),

        // 3) GroupProvider: listens to groups of the current user
        ChangeNotifierProvider<GroupProvider>(create: (_) => GroupProvider()),

        // 4) UserProvider: depends on GroupProvider
        ChangeNotifierProxyProvider<GroupProvider, UserProvider>(
          create: (_) => UserProvider(),
          update: (context, groupProvider, userProvider) {
            userProvider ??= UserProvider();

            final currentPhone = groupProvider.currentUserPhone;
            final groups = groupProvider.allUserGroups;

            userProvider.syncWithGroups(currentPhone, groups);

            return userProvider;
          },
        ),

        // 5) GeocodingProvider: depends on LanguageProvider for locale
        ChangeNotifierProxyProvider<LanguageProvider, GeocodingProvider>(
          create: (_) => GeocodingProvider(),
          update: (context, langProvider, geoProvider) {
            geoProvider ??= GeocodingProvider();
            // Sync locale (so reverse geocoding returns Arabic/English correctly)
            geoProvider.updateLocale(langProvider.locale);
            return geoProvider;
          },
        ),

        // 6) MemberGeofenceProvider
        ChangeNotifierProvider<MemberGeofenceProvider>(
          create: (_) => MemberGeofenceProvider(),
        ),
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
