import 'package:flutter/material.dart';
import '../utils/helpers.dart';

class AppAlert extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final String message;
  final List<Widget> actions;
  final Color iconColor;
  final Color contentColor;
  final Color borderColor;
  final Color backgroundColor;

  const AppAlert({
    super.key,
    this.icon = Icons.warning_amber_rounded,
    this.title = "",
    required this.time,
    required this.message,
    this.actions = const [],
    this.iconColor = const Color(0xFFB71C1C), // red border
    this.contentColor = const Color(0xFFB71C1C), // red border
    this.borderColor = const Color(0xFFF2C8C8), // red border
    this.backgroundColor = const Color(0xFFFCECEC), // darker red bg
  });

  @override
  Widget build(BuildContext context) {
    // Make responsive behavior for small widths
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      color: backgroundColor,
      margin: EdgeInsets.only(top: 0, bottom: 10),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 5.0),
        child: Row(
          children: [
            // Column 1: Icon
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              child: Column(
                children: [
                  Icon(icon, size: 35, color: iconColor),
                  Text(
                    time,
                    style: TextStyle(color: contentColor, fontSize: 8),
                  ),
                ],
              ),
            ),

            // Column 2: Message content (expandable)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        color: contentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  SizedBox(height: 3),
                  // Body (may wrap)
                  Text(
                    message,
                    style: TextStyle(color: contentColor, fontSize: 10),
                  ),
                  SizedBox(height: 6),
                ],
              ),
            ),

            // Column 3: Controls (buttons)
            // Use a Column to stack buttons vertically on narrow screens,
            // but keep in a Row for wide layout if needed.
            if (actions.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 1.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions.map((w) => w).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
