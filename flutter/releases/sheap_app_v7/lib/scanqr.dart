import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/app_localizations.dart';
import '../background.dart';
import '../buttons.dart';

class ScanQRPage extends StatefulWidget {
  final Function(String groupId) onScanned;

  const ScanQRPage({super.key, required this.onScanned});

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage> {
  bool scanned = false;
  final MobileScannerController controller = MobileScannerController();
  String? lastCode;

  /*
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) async {
              if (scanned) return;
              scanned = true;

              final barcode = capture.barcodes.first;
              final raw = barcode.rawValue;

              controller.stop();

              final confirmed = await _showConfirmJoinModal(context, raw);

              if (confirmed == true) {
                widget.onScanned(raw!);
                Navigator.pop(context); // leave scan page
              } else {
                scanned = false;
                controller.start();
              }
            },
          ),
        ],
      ),
    );
  }
  */

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
                          AppLocalizations.of(context)!.scanQR,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),

                        // ===== CAMERA FRAME =====
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Color(0xFF825EF6),
                              width: 5,
                            ),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Stack(
                              children: [
                                // CAMERA VIEW
                                MobileScanner(
                                  controller: controller,

                                  onDetect: (capture) async {
                                    if (scanned) return;

                                    final barcode = capture.barcodes.first;
                                    final raw = barcode.rawValue;
                                    if (raw == null) return;

                                    scanned = true;
                                    controller.stop();
                                    lastCode = raw;

                                    final confirmed =
                                        await _showConfirmJoinModal(
                                          context,
                                          raw,
                                        );

                                    if (confirmed == true) {
                                      widget.onScanned(
                                        raw,
                                      ); // safe (raw is string here)
                                      Navigator.pop(context);
                                    } else {
                                      scanned = false;
                                      controller.start();
                                    }
                                  },
                                ),

                                // SCAN LINE ANIMATION
                                Positioned.fill(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: Duration(seconds: 2),
                                    curve: Curves.easeInOut,
                                    builder: (context, value, child) {
                                      return Align(
                                        alignment: Alignment(
                                          0,
                                          (value * 2) - 1,
                                        ),
                                        child: Container(
                                          height: 4,
                                          width: double.infinity,
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      );
                                    },
                                    onEnd: () {
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 25),

                        // ===== HINT MESSAGE =====
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

  Future<bool?> _showConfirmJoinModal(BuildContext context, String? groupId) {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.60,
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.qr_code, size: 40, color: Colors.deepPurple),
              SizedBox(height: 15),
              Text(
                AppLocalizations.of(context)!.confirmJoinGroup,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                "${AppLocalizations.of(context)!.groupId}\n$groupId",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              Spacer(),
              Container(
                margin: EdgeInsets.all(8.0),
                alignment: Alignment.center,
                child: PrimaryButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    AppLocalizations.of(context)!.yes,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 20.0,
                    ),
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.all(8.0),
                alignment: Alignment.center,
                child: SecondaryButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    AppLocalizations.of(context)!.cancel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 20.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
