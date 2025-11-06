import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> getLanguage() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('language');
}

Future<void> saveLanguage(String languageCode) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('language', languageCode);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? savedLanguage = await getLanguage();

  if (savedLanguage == null) {
    final Locale systemLocale =
        WidgetsBinding.instance.platformDispatcher.locale;
    savedLanguage = systemLocale.languageCode;
    await saveLanguage(savedLanguage);
  }

  final String message = (savedLanguage == 'en') ? 'Welcome' : 'السلام عليكم';

  print('=======================================');
  print('Final Language Used: $savedLanguage');
  print('Message: $message');
  print('=======================================');

  runApp(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-1.5, 1.5),
                  radius: 1.5,
                  colors: [Color(0xAAA0F0FF), Colors.white],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.all(110.0),
                    child: Image(image: AssetImage('images/logo.png')),
                  ),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
