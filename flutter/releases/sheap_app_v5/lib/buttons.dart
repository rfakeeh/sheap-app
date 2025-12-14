import 'package:flutter/material.dart';

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
           backgroundColor: Color.fromRGBO(60, 50, 163, 1),
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
