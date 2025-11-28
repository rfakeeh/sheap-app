import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../l10n/app_localizations.dart';
import '../background.dart';

class ShowQRPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const ShowQRPage({super.key, required this.groupId, required this.groupName});

  @override
  State<ShowQRPage> createState() => _ShowQRPageState();
}

class _ShowQRPageState extends State<ShowQRPage> {
  @override
  Widget build(BuildContext context) {
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
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  // ===== MIDDLE SECTION =====
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ////////////////////// BEGIN TO REMOVE ////

                        // ===== TITLE =====
                        Text(
                          AppLocalizations.of(context)!.showQR,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 30),

                        // ===== GROUP NAME =====
                        Text(
                          widget.groupName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 10),

                        // ===== QR SECTION =====
                        Container(
                          padding: EdgeInsets.all(10),
                          child: QrImageView(
                            data: widget.groupId,
                            version: QrVersions.auto,
                            size: 225.0,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.circle,
                              color: Color(0xFF3C32A3),
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.circle,
                              color: Color(0xFF3C32A3),
                            ),
                          ),
                        ),

                        // ===== SHARE BUTTON =====
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.share,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(
                              Icons.ios_share,
                              size: 18,
                              color: Colors.black,
                            ),
                          ],
                        ),
                        SizedBox(height: 30),

                        // ===== BOTTOM MESSAGE =====
                        Text(
                          AppLocalizations.of(context)!.scanQrToJoin,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF825EF6),
                          ),
                        ),

                        ////////////////////// END TO REMOVE ////
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
