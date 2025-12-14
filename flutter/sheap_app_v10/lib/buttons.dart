import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class PrimaryButton extends ElevatedButton {
  PrimaryButton({
    super.key,
    required super.onPressed,
    required super.child,
    super.onLongPress,
    super.focusNode,
    super.autofocus,
    super.clipBehavior,
  }) : super(
         style: ElevatedButton.styleFrom(
           backgroundColor: Color(0xFF3C32A3),
           foregroundColor: Color(0xFFFFFFFF),
           minimumSize: Size(double.infinity, 50),
           shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(14),
           ),
           side: const BorderSide(
             color: Color(0xFF825EF6), // Color of the border
             width: 1.0, // Thickness of the border
           ),
           elevation: 2,
         ),
       );
}

class SecondaryButton extends ElevatedButton {
  SecondaryButton({
    super.key,
    required super.onPressed,
    required super.child,
    super.onLongPress,
    super.focusNode,
    super.autofocus,
    super.clipBehavior,
  }) : super(
         style: ElevatedButton.styleFrom(
           backgroundColor: Color(0xFFF3F3F9),
           foregroundColor: Color(0xFF3C32A3),
           minimumSize: Size(double.infinity, 50),
           shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(14),
           ),
           side: const BorderSide(
             color: Color(0xFF825EF6), // Color of the border
             width: 1.0, // Thickness of the border
           ),
           elevation: 2,
         ),
       );
}

class EmergencySOSButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isSosActive;
  final bool isSosLoading;

  const EmergencySOSButton({
    super.key,
    required this.onPressed,
    this.isSosActive = false,
    this.isSosLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10, top: 15),
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              //color: !isSosActive ? Colors.red : Color(0xFFFCECEC),
              color: Colors.red,
              boxShadow: [
                if (isSosActive)
                  const BoxShadow(
                    blurStyle: BlurStyle.solid,
                    color: Colors.redAccent,
                    blurRadius: 25,
                    spreadRadius: 5,
                  )
                else
                  const BoxShadow(
                    blurStyle: BlurStyle.solid,
                    color: Color(0xFFEDA4A4),
                    blurRadius: 5,
                    spreadRadius: 5,
                  ),
              ],
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sos,
                  //color: !isSosActive ? Colors.white : Colors.red,
                  color: Colors.white,
                  size: 25,
                ),
                SizedBox(height: 2),
                Text(
                  !isSosLoading
                      ? !isSosActive
                            ? AppLocalizations.of(context)!.sendSos
                            : AppLocalizations.of(context)!.cancelSos
                      : AppLocalizations.of(context)!.loading,
                  //!isActive ? 'Send' : 'Cancel',
                  style: TextStyle(
                    //color: !isSosActive ? Colors.white : Colors.red,
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/*
class EmergencySOSButton extends StatefulWidget {
  const EmergencySOSButton({super.key});

  @override
  State<EmergencySOSButton> createState() => _EmergencySOSButtonState();
}

class _EmergencySOSButtonState extends State<EmergencySOSButton> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.only(bottom: 5.0, top: 15.0),
        padding: EdgeInsets.all(10.0),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red,
          boxShadow: [
            if (true)
              BoxShadow(
                blurRadius: 20,
                blurStyle: BlurStyle.normal,
                color: Colors.red,
                offset: Offset.zero,
                spreadRadius: 2,
              ),
          ],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sos, color: Colors.white, size: 30),
            Text(
              'إرسال',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/
