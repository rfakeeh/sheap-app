import 'package:flutter/material.dart';
import '../background.dart';

class FullScreenModal extends StatelessWidget {
  final String? title;
  final IconData icon;
  final Color outerColor;
  final Color innerColor;
  final String message;
  final List<Widget>? bottomActions;
  final VoidCallback? onClose;
  final bool showCloseButton;

  const FullScreenModal({
    super.key,
    this.title,
    required this.icon,
    this.outerColor = const Color(0xFFEDE7FF),
    this.innerColor = const Color(0xFF7B61FF),
    required this.message,
    this.bottomActions,
    this.onClose,
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    // Check if a modal or route can be popped
    final bool canPop = Navigator.canPop(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GradientBackground(),
            Container(
              margin: EdgeInsets.all(25.0),
              child: Column(
                children: [
                  // ===== TOP SECTION =====
                  Row(
                    children: [
                      if (canPop && onClose == null)
                        IconButton(
                          icon: Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                      Expanded(
                        child: Image.asset(
                          "assets/images/name.png",
                          height:
                              MediaQuery.of(context).size.height *
                              0.045, // 6% of screen height
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (showCloseButton)
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: onClose ?? () => Navigator.pop(context),
                        ),
                    ],
                  ),

                  // ===== MIDDLE SECTION =====
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ===== ICON SECTION =====
                        Container(
                          width: 125,
                          height: 125,
                          decoration: BoxDecoration(
                            color: outerColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            // --- INNER CIRCLE ---
                            child: Container(
                              width: 95,
                              height: 95,
                              decoration: BoxDecoration(
                                color: innerColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: Colors.white, size: 50),
                            ),
                          ),
                        ),
                        SizedBox(height: 40),

                        // ===== BOTTOM MESSAGE =====
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3C32A3),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ===== BOTTOM SECTION =====
                  if (bottomActions != null && bottomActions!.isNotEmpty)
                    Column(children: bottomActions!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
