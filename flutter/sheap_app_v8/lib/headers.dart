import 'package:flutter/material.dart';
import '../dropdowns.dart';
import '../utils/helpers.dart';
import '../models/user_model.dart';
import '../l10n/app_localizations.dart';

class HomeHeader extends StatefulWidget {
  final AppUser user;
  final bool isLoading;
  final String? currentAddress;

  const HomeHeader({
    required this.user,
    required this.isLoading,
    this.currentAddress,
    super.key,
  });

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Align(alignment: Alignment.topLeft, child: LanguageDropdown()),
        Expanded(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: ListTile(
              contentPadding: const EdgeInsets.all(10),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFF9F5FF),
                    child: Text(
                      Helpers.getInitials(widget.user.fullName),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7F56D9),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 7,
                      backgroundColor: Color(0xFF12B76A),
                    ),
                  ),
                ],
              ),
              title: Text(
                Helpers.getFirstAndLastName(widget.user.fullName),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // --- UPDATED SUBTITLE FOR LOCATION ---
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.isLoading
                            ? AppLocalizations.of(context)!.loading
                            : widget.currentAddress ?? "",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.notifications_none,
                        color: Colors.black,
                      ),
                      iconSize: 32,
                      onPressed: () {
                        // TODO: Open notifications
                      },
                    ),
                  ),
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      radius: 8,
                      child: Text(
                        "0",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
