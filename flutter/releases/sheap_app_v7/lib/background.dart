import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1,
              stops: [0.0, 1.0],
              colors: [
                Color.fromRGBO(45, 152, 156, 0.1),
                Color(0xFFFFFFFF), // Fading to white
              ],
            ),
          ),
        ),
      ],
    );
  }
}
