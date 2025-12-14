import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../home.dart';
import '../welcome.dart';
import '../repositories/user_repository.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final UserRepository _userRepository = UserRepository();

  late final Future<AppUser?> _loginFuture;

  // This function checks local storage for a saved user's phone
  Future<AppUser?> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userPhone = prefs.getString('loggedInUserPhone');

    if (userPhone == null) {
      return null; // Not logged in
    }

    try {
      // Fetch user from Firestore
      return _userRepository.getUser(userPhone);
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    // Run the check ONCE only; future will be reused across rebuilds
    _loginFuture = _checkLoginStatus();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: _loginFuture, // ⬅ نفس الـ future دائماً
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return HomePage(user: snapshot.data!);
        }

        return const WelcomePage();
      },
    );
  }
}
