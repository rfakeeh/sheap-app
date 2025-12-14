import 'package:flutter/material.dart';

class LogoImage extends StatelessWidget {
  const LogoImage({super.key});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.5, // Take 60% of the screen width
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain, // Keep aspect ratio
      ),
    );
  }
}
