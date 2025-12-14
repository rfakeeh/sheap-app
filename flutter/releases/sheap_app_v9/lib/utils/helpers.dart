import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_model.dart';
import '../models/group_model.dart';

import '../repositories/user_repository.dart';

// Helper to generate initials (Works for English & Arabic)
class Helpers {
  static String getInitials(String name) {
    if (name.isEmpty) return "?";

    List<String> nameParts = name.trim().split(RegExp(r'\s+'));

    // First initial
    String firstInitial = nameParts[0].substring(0, 1);

    String lastInitial = "";
    if (nameParts.length > 1) {
      String lastName = nameParts.last.trim();
      // Remove Arabic Al-Ta3reef "ال" if valid
      if (lastName.startsWith("ال")) {
        String withoutAl = lastName.substring(2); // Remove "ال"
        // Only remove "ال" if remaining length ≥ 2 letters
        if (withoutAl.length >= 2) {
          lastName = withoutAl;
        }
      }

      if (lastName.isNotEmpty) {
        lastInitial = lastName.substring(0, 1);
      }
    }

    return "$firstInitial $lastInitial".toUpperCase();
  }

  static String getInitials1(String name) {
    if (name.isEmpty) return "?";
    List<String> nameParts = name.trim().split(RegExp(r'\s+'));
    String firstInitial = nameParts[0].isNotEmpty
        ? nameParts[0].substring(0, 1)
        : "";
    String lastInitial = " ";
    if (nameParts.length > 1) {
      String lastName = nameParts.last;
      if (lastName.isNotEmpty) {
        lastInitial += lastName.substring(0, 1);
      }
    }
    return (firstInitial + lastInitial).toUpperCase();
  }

  static String getFirstAndLastName(String fullName) {
    if (fullName.isEmpty) return "";

    List<String> nameParts = fullName.trim().split(RegExp(r'\s+'));

    if (nameParts.isEmpty) {
      return "";
    } else if (nameParts.length == 1) {
      // Only one name part (e.g., "Khalid")
      return nameParts[0];
    } else {
      // More than one name part, take the first and the last
      String firstName = nameParts.first;
      String lastName = nameParts.last;
      return "$firstName $lastName";
    }
  }

  static Future<List<AppUser>> fetchGroupMembersDetails(
    GroupModel group,
  ) async {
    UserRepository userRepository = UserRepository();
    List<Future<AppUser?>> futures = [];

    for (String memberId in group.memberIds) {
      futures.add(userRepository.getUser(memberId));
    }

    // Wait for all user fetch requests to complete
    List<AppUser?> users = await Future.wait(futures);

    // Filter out any nulls in case a user wasn't found
    return users.whereType<AppUser>().toList();
  }

  static Future<T?> showBottomModal<T>({
    required BuildContext context,
    required Widget page,
    //List<Widget>? bottomActions,
    VoidCallback? onClose,
    bool showCloseButton = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true, // Crucial for full height
      useSafeArea: true, // Respect SafeArea in the modal itself
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent, // Important for the look
      builder: (context) => page,
    );
  }

  static String toSentenceCase(String text) {
    if (text.isEmpty) return text;

    String lower = text.trim();

    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < lower.length; i++) {
      String char = lower[i];

      if (capitalizeNext && RegExp(r'[A-Za-z]').hasMatch(char)) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
      }

      // Capitalize after period + space
      if (char == '.' || char == '!' || char == '?') {
        capitalizeNext = true;
      }
    }

    return buffer.toString();
  }

  static String timeAgo(DateTime dateTime, {bool isArabic = true}) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return isArabic ? 'الآن' : 'Just now';
    }
    if (difference.inMinutes < 60) {
      final m = difference.inMinutes;
      return isArabic ? 'منذ $m دقيقة' : '$m minutes ago';
    }
    if (difference.inHours < 24) {
      final h = difference.inHours;
      return isArabic ? 'منذ $h ساعة' : '$h hours ago';
    }
    if (difference.inDays < 30) {
      final d = difference.inDays;
      return isArabic ? 'منذ $d يوم' : '$d days ago';
    }
    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return isArabic ? 'منذ $months شهر' : '$months months ago';
    }
    final years = (difference.inDays / 365).floor();
    return isArabic ? 'منذ $years سنة' : '$years years ago';
  }
}

class EnglishDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text;
    const arabicNumbers = '٠١٢٣٤٥٦٧٨٩';
    const englishNumbers = '0123456789';
    for (int i = 0; i < arabicNumbers.length; i++) {
      newText = newText.replaceAll(arabicNumbers[i], englishNumbers[i]);
    }
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class SmartColorGenerator {
  static const List<Color> basePalette = [
    Color(0xFF3C32A3),
    Color(0xFF825EF6),
    Color(0xFF42D3D8),
    Color(0xFF73CF96),
    Color(0xFF94979C),
  ];

  static Color getColor(int index) {
    Color baseColor = basePalette[index % basePalette.length];
    int cycle = index ~/ basePalette.length;
    if (cycle == 0) {
      return baseColor;
    } else {
      HSLColor hsl = HSLColor.fromColor(baseColor);
      double lightnessAdjustment = (cycle * 0.1).clamp(0.0, 0.4);
      double newLightness = (hsl.lightness > 0.5)
          ? (hsl.lightness - lightnessAdjustment).clamp(0.2, 0.9)
          : (hsl.lightness + lightnessAdjustment).clamp(0.2, 0.9);
      return hsl.withLightness(newLightness).toColor();
    }
  }
}
