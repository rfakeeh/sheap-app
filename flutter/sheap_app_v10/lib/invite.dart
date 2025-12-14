import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

class InviteMemberPage extends StatefulWidget {
  final String groupId;
  final String username;

  const InviteMemberPage({
    super.key,
    required this.groupId,
    required this.username,
  });

  @override
  State<InviteMemberPage> createState() => _InviteMemberPageState();
}

class _InviteMemberPageState extends State<InviteMemberPage> {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;

  final _userRepo = UserRepository();
  final _groupRepo = GroupRepository();
  final _alertRepo = AlertRepository();
  final _orchestrator = Orchestrator();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    // Show loading spinner
    setState(() => _isLoading = true);

    final phone = _phoneCtrl.text.trim();

    // Basic validation: phone must not be empty
    if (phone.isEmpty) {
      _showAlert(AppLocalizations.of(context)!.enterPhoneNumber);
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load the group to get its name and creator id
      final group = await _groupRepo.getGroupById(widget.groupId);
      if (group == null) {
        setState(() => _isLoading = false);
        _showAlert(AppLocalizations.of(context)!.groupNotFound);
        return;
      }

      // Build localized invitation message
      final message =
          "${AppLocalizations.of(context)!.receivedGroupInvitation} ${group.groupName}. ${AppLocalizations.of(context)!.doYouWantToJoin}";

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
                              AppLocalizations.of(context)!.addMemberByPhone,
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
                                AppLocalizations.of(context)!.userPhone,
                                style: TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                ),
                                textDirection: TextDirection.ltr,
                                textAlign: isArabic
                                    ? TextAlign.right
                                    : TextAlign.left,
                              ),
                            ),
                            SizedBox(height: 5),

                            // ===== TEXT FIELD =====
                            TextFormField(
                              textDirection: TextDirection.ltr,
                              textAlign: isArabic
                                  ? TextAlign.right
                                  : TextAlign.left,
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                              controller: _phoneCtrl,
                              inputFormatters: [
                                EnglishDigitsFormatter(),
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hint: Text(
                                  AppLocalizations.of(context)!.userPhoneHint,
                                  textDirection: TextDirection.ltr,
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
                                prefixIcon: Icon(Icons.phone_iphone),
                              ),
                            ),
                            SizedBox(height: 30),

                            // ===== BOTTOM MESSAGE =====
                            Text(
                              AppLocalizations.of(context)!.memberAcceptance,
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
                      onPressed: _invite,
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              AppLocalizations.of(context)!.inviteMember,
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
