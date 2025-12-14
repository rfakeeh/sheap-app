import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sheap_app_v3/models/alert_model.dart';
import 'package:sheap_app_v3/models/group_model.dart';
import 'package:sheap_app_v3/models/user_model.dart';

import '../background.dart';
import '../buttons.dart';
import '../modal.dart';

import '../providers/language_provider.dart';

import '../l10n/app_localizations.dart';

import '../repositories/user_repository.dart';
import '../repositories/group_repository.dart';
import '../repositories/alert_repository.dart';

import '../utils/helpers.dart';

import '../services/orchestrator.dart';

import 'exceptions/invite_exception.dart';
import 'exceptions/alert_exception.dart';

class BroadcastAlertPage extends StatefulWidget {
  final GroupModel group;
  final AppUser user;

  const BroadcastAlertPage({
    super.key,
    required this.group,
    required this.user,
  });

  @override
  State<BroadcastAlertPage> createState() => _BroadcastAlertPageState();
}

class _BroadcastAlertPageState extends State<BroadcastAlertPage> {
  static const int kMaxChars = 60;
  final _messageCtrl = TextEditingController();
  bool _isLoading = false;
  int _charCount = 0;

  final _userRepo = UserRepository();
  final _groupRepo = GroupRepository();
  final _alertRepo = AlertRepository();
  final _orchestrator = Orchestrator();

  @override
  void initState() {
    super.initState();
    _messageCtrl.addListener(_onMessageChanged);
  }

  void _onMessageChanged() {
    // This counts EVERYTHING (spaces + punctuation included)
    final count = _messageCtrl.text.characters.length;
    if (count != _charCount) {
      setState(() => _charCount = count);
    }
  }

  @override
  void dispose() {
    _messageCtrl.removeListener(_onMessageChanged);
    _messageCtrl.dispose();
    super.dispose();
  }

  void _clearMessage() {
    _messageCtrl
        .clear(); // This will also trigger the listener and update counter
    FocusScope.of(context).unfocus(); // optional: close keyboard
  }

  Future<void> _send() async {
    // Show loading spinner
    setState(() => _isLoading = true);

    final message = _messageCtrl.text.trim();

    // Basic validation: message must not be empty
    if (message.isEmpty) {
      _showAlert(AppLocalizations.of(context)!.enterBroadcastMessage);
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Determine receivers
      final isCreator = widget.user.phoneNumber == widget.group.creatorId;
      final isLeader = widget.user.phoneNumber == widget.group.leaderId;
      final isAllVisible = widget.group.trackingMode == TrackingMode.allVisible;
      final receivers = <String>{};

      if (isCreator || isLeader || isAllVisible) {
        receivers.addAll(widget.group.memberIds);
      } else {
        receivers.add(widget.group.leaderId);
      }
      receivers.remove(widget.user.phoneNumber);

      if (receivers.isEmpty) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        Helpers.showBottomModal(
          context: context,
          page: FullScreenModal(
            icon: Icons.close,
            outerColor: const Color(0xFFFFE6E6),
            innerColor: const Color(0xFFE53935),
            message: AppLocalizations.of(context)!.sosRequestNoVisibleMembers,
          ),
        );
        return;
      }

      for (final receiverId in receivers) {
        // Call alert repository (centralized business logic)
        await _alertRepo.sendAlert(
          groupId: widget.group.groupId,
          type: AlertType.broadcast,
          senderId: widget.user.phoneNumber,
          message: message,
          requiresAction: false,
          receiverId: receiverId,
          payload: {
            "senderName": Helpers.getFirstAndLastName(widget.user.fullName),
            "groupName": widget.group.groupName,
          },
        );
      }

      // On success: stop loading, close page, show success modal
      setState(() => _isLoading = false);
      Navigator.pop(context);

      Helpers.showBottomModal(
        context: context,
        page: FullScreenModal(
          icon: Icons.check,
          message: AppLocalizations.of(context)!.broadcastSent,
        ),
      );
    } catch (e) {
      // Any unexpected error (network, Firestore, etc.)
      setState(() => _isLoading = false);
      Navigator.pop(context);
      Helpers.showBottomModal(
        context: context,
        page: FullScreenModal(
          icon: Icons.close,
          outerColor: const Color(0xFFFFE6E6),
          innerColor: const Color(0xFFE53935),
          message: e.toString(),
        ),
      );
    }
  }

  /*
  Future<void> _broadcast() async {
    // Show loading spinner
    setState(() => _isLoading = true);

    final message = _messageCtrl.text.trim();

    // Basic validation: message must not be empty
    if (message.isEmpty) {
      _showAlert(AppLocalizations.of(context)!.enterBroadcastMessage);
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Call orchestrator (centralized business logic)
      await _orchestrator.inviteMemberToGroup(
        groupId: widget.groupId,
        creatorId: group.creatorId, // current group creator phone
        creatorName: widget.username, // display name in payload
        targetPhone: phone,
      );

      // On success: stop loading, close page, show success modal
      setState(() => _isLoading = false);
      Navigator.pop(context);

      Helpers.showBottomModal(
        context: context,
        page: FullScreenModal(
          icon: Icons.check,
          message: AppLocalizations.of(context)!.invitationSent,
        ),
      );
    } on InviteException catch (e) {
      // Stop loading when a domain error occurs
      setState(() => _isLoading = false);

      // Map error codes to localized messages
      switch (e.code) {
        case InviteErrorCodes.userNotFound:
          //_showAlert(AppLocalizations.of(context)!.numberNotRegistered);
          Helpers.showBottomModal(
            context: context,
            page: FullScreenModal(
              icon: Icons.close,
              outerColor: const Color(0xFFFFE6E6),
              innerColor: const Color(0xFFE53935),
              message: AppLocalizations.of(context)!.numberNotRegistered,
            ),
          );
          break;

        case InviteErrorCodes.groupNotFound:
          _showAlert(AppLocalizations.of(context)!.groupNotFound);
          break;

        case InviteErrorCodes.alreadyMember:
          // Here we follow your previous UX with a bottom full-screen modal
          Helpers.showBottomModal(
            context: context,
            page: FullScreenModal(
              icon: Icons.close,
              outerColor: const Color(0xFFFFE6E6),
              innerColor: const Color(0xFFE53935),
              message: AppLocalizations.of(context)!.userAlreadyMember,
            ),
          );
          break;

        default:
          _showAlert(AppLocalizations.of(context)!.invitationFailed);
      }
    } on AlertException catch (e) {
      // Stop loading when a domain error occurs
      setState(() => _isLoading = false);

      switch (e.code) {
        case AlertErrorCodes.duplicatePendingAlert:
          Helpers.showBottomModal(
            context: context,
            page: FullScreenModal(
              icon: Icons.close,
              outerColor: const Color(0xFFFFE6E6),
              innerColor: const Color(0xFFE53935),
              message: AppLocalizations.of(context)!.invitationAlreadySent,
            ),
          );
          break;

        default:
          _showAlert(AppLocalizations.of(context)!.invitationFailed);
      }
    } catch (e) {
      // Any unexpected error (network, Firestore, etc.)
      setState(() => _isLoading = false);
      _showAlert(AppLocalizations.of(context)!.invitationFailed);
    }
  }
  */

  void _showAlert(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /*
  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }
  */

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.locale.languageCode == 'ar';

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
                    child: Align(
                      alignment: AlignmentGeometry.center,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ===== TITLE =====
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.sendBroadcastMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 30),

                            // ===== TEXT LABEL =====
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                AppLocalizations.of(context)!.messageText,
                                style: TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: isArabic
                                    ? TextAlign.right
                                    : TextAlign.left,
                              ),
                            ),
                            SizedBox(height: 5),

                            // ===== TEXT FIELD =====
                            /*
                            TextFormField(
                              textAlign: isArabic
                                  ? TextAlign.right
                                  : TextAlign.left,
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                              controller: _messageCtrl,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(kMaxChars),
                              ],
                              maxLines: 2,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                hint: Text(
                                  AppLocalizations.of(context)!.messageTextHint,
                                  textAlign: isArabic
                                      ? TextAlign.right
                                      : TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    color: Color(0xFF85888E),
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18.0),
                                  borderSide: BorderSide(
                                    color: Color(0xFFD0D5DD),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18.0),
                                  borderSide: BorderSide(
                                    color: Color(0xFFD0D5DD),
                                  ),
                                ),
                                prefixIcon: Icon(Icons.emergency_share),
                                suffixIcon: Icon(Icons.close),
                              ),
                            ),
                            */
                            TextFormField(
                              textAlignVertical: TextAlignVertical.center,
                              textAlign: isArabic
                                  ? TextAlign.right
                                  : TextAlign.left,
                              style: const TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                              ),
                              controller: _messageCtrl,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(kMaxChars),
                              ],
                              maxLines: 1,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                // Important: makes prefix/suffix sit at the top for multiline
                                alignLabelWithHint: true,

                                hintText: AppLocalizations.of(
                                  context,
                                )!.messageTextHint,
                                hintStyle: const TextStyle(
                                  fontSize: 14.0,
                                  color: Color(0xFF85888E),
                                ),

                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18.0),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD0D5DD),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18.0),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD0D5DD),
                                  ),
                                ),

                                // TOP-aligned prefix icon
                                prefixIcon: Icon(Icons.emergency_share),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),

                                // TOP-aligned clickable suffix icon (clear)
                                suffixIcon: (_messageCtrl.text.isEmpty)
                                    ? null
                                    : IconButton(
                                        tooltip: isArabic ? "مسح" : "Clear",
                                        icon: const Icon(Icons.close),
                                        onPressed: _clearMessage,
                                      ),
                                suffixIconConstraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),

                                // Optional: makes text padding look balanced with top icons
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                            ),

                            SizedBox(height: 10),

                            /// counter
                            /// const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${_charCount}/$kMaxChars",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: (_charCount >= kMaxChars)
                                        ? Colors.red
                                        : const Color(0xFF85888E),
                                  ),
                                ),
                                Text(
                                  "${kMaxChars - _charCount} ${isArabic ? "متبقي" : "left"}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: (_charCount >= kMaxChars)
                                        ? Colors.red
                                        : const Color(0xFF85888E),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 30),

                            // ===== BOTTOM MESSAGE =====
                            Text(
                              AppLocalizations.of(context)!.makeItShort,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF825EF6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ===== BOTTOM BUTTON =====
                  Container(
                    margin: EdgeInsets.all(8.0),
                    alignment: Alignment.bottomCenter,
                    child: PrimaryButton(
                      onPressed: _send,
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              AppLocalizations.of(context)!.sendSos,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20.0,
                              ),
                            ),
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
