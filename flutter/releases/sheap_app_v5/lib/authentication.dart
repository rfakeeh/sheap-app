import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sheap_app_v3/models/user_model.dart';
import 'package:sheap_app_v3/home.dart';
import 'package:sheap_app_v3/welcome.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // This function checks local storage for a saved user
  Future<AppUser?> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // 1. Check for the saved phone number
    String? userPhone = prefs.getString('loggedInUserPhone');

    if (userPhone == null) {
      // Not logged in
      return null;
    }

    // 2. If phone is found, fetch the user data from Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userPhone)
          .get();

      if (doc.exists) {
        // Return the user object
        return AppUser.fromFirestore(doc);
      } else {
        return null; // User was logged in, but data is missing
      }
    } catch (e) {
      return null; // Any error, log them out
    }
  }

  @override
  Widget build(BuildContext context) {
    // FutureBuilder runs the function once and builds UI based on the result
    return FutureBuilder<AppUser?>(
      future: _checkLoginStatus(),
      builder: (context, snapshot) {
        // 1. Still checking...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Function finished and returned a user
        if (snapshot.hasData && snapshot.data != null) {
          // Go to HomePage and PASS the user data
          return HomePage(user: snapshot.data!);
        }

        // 3. Function finished and returned 'null' (no user)
        return const WelcomePage();
      },
    );
  }
}
