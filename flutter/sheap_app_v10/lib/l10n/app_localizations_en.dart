// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get signUp => 'Sign Up';

  @override
  String get signIn => 'Sign In';

  @override
  String get welcomePage => 'Welcome Page';

  @override
  String get home => 'Home';

  @override
  String get mapView => 'Map View';

  @override
  String get fillFields => 'Please fill the following fields';

  @override
  String get userName => 'Username';

  @override
  String get usernameHint => 'three-part name';

  @override
  String get userId => 'National ID / Iqama number';

  @override
  String get userIdHint => '12*********';

  @override
  String get userPhone => 'Phone number';

  @override
  String get userPhoneHint => '+966502178700';

  @override
  String get signUpTerms =>
      'By signing up, I agree to the app\'s Terms of Service and Privacy Policy.';

  @override
  String get signInTerms =>
      'By signing in, I agree to the app\'s Terms of Service and Privacy Policy.';

  @override
  String get otpVerify => 'OTP Verification';

  @override
  String get otpVerifyPhone =>
      'A verification code will be sent to your mobile';

  @override
  String get otpVerifyChangePhone => 'Change mobile number';

  @override
  String get otpVerifyReset => 'Didn\'t receive the code? Resend in';

  @override
  String get otpVerifyAskReset => 'Resend OTP code ?';

  @override
  String get otpVerifySeconds => 'seconds';

  @override
  String get otpVerifySigning => 'Signing in ';

  @override
  String get otpVerifying => 'VerIfying OTP ';

  @override
  String get otpVerifyConfirm => 'Confirm OTP';

  @override
  String get fillAllFields => 'Please fill all fields.';

  @override
  String get incorrectFields => 'Incorrect ID or phone number.';

  @override
  String get userExists => 'A user with this phone number already exists!';

  @override
  String get signOut => 'Sign Out';

  @override
  String get welcome => 'Welcome, ';

  @override
  String get back => 'Back';

  @override
  String get loading => 'Loading ';

  @override
  String get locationServiceDisabled => 'Location service is disabled.';

  @override
  String get permissionsDenied => 'Permissions are denied.';

  @override
  String get location => 'Location';

  @override
  String get locations => 'Locations';

  @override
  String get group => 'Group';

  @override
  String get groups => 'Groups';

  @override
  String get the => 'The ';

  @override
  String get my => 'My';

  @override
  String get holy => 'Holy';

  @override
  String get important => 'Important';

  @override
  String get holyLocations => 'Holy Locations';

  @override
  String get hajjLocations => 'Hajj Locations';

  @override
  String get search => 'Search ';

  @override
  String get noResults => 'No results found.';

  @override
  String get createdGroups => 'You have created';

  @override
  String get createNewGroup => 'Add  Group';

  @override
  String get noCreatedGroups => 'You don\'t have any groups.';

  @override
  String get joinedGroups => 'You have joined';

  @override
  String get joinNewGroup => 'Join Group';

  @override
  String get noJoinedGroups => 'You haven\'t joined any active groups yet.';

  @override
  String get trackingOn => 'Tracking On';

  @override
  String get enableTracking => 'Activate Tracking';

  @override
  String get trackingOff => 'Tracking Off';

  @override
  String get disableTracking => 'Deactivate Tracking';

  @override
  String get leader => 'Leader';

  @override
  String get allMembersSafe => 'All members are safe.';

  @override
  String get outsideGeofence => 'member(s) are outside geofence';

  @override
  String get sentSOS => 'member(s) have sent SOS';

  @override
  String get and => 'and';

  @override
  String get edit => 'Edit Group';

  @override
  String get delete => 'Delete Group';

  @override
  String get exit => 'Exit Group';

  @override
  String get navigateToDestination => 'To Destination';

  @override
  String get destination => 'To';

  @override
  String get navigateToLeader => 'To Leader';

  @override
  String get alertGroup => 'Alert Group';

  @override
  String get showQR => 'Show Group QR';

  @override
  String get addMemberByPhone => 'Invite By Phone Number';

  @override
  String get addMemberByQR => 'Invite By QR Code';

  @override
  String get scanQrToJoin => 'Scan this QR to join the group';

  @override
  String get share => 'Share';

  @override
  String get add => 'Add';

  @override
  String get inviteMember => 'Invite Member';

  @override
  String get memberAcceptance =>
      'An invitation will be sent. The member must accept to join.';

  @override
  String get enterPhoneNumber => 'Please enter a phone number.';

  @override
  String get numberNotRegistered => 'This number is not registered in the app.';

  @override
  String get groupNotFound => 'Group not found.';

  @override
  String get userAlreadyMember => 'This user is already a member of the group.';

  @override
  String get receivedGroupInvitation => 'Has invited you to';

  @override
  String get rejectedGroupInvitation => 'Has rejected your invitation to join';

  @override
  String get acceptedGroupInvitation => 'Has accepted your invitation to join';

  @override
  String get sentSosRequest => 'An SOS request was sent by this member';

  @override
  String get clickToHelpOrDismiss =>
      'Click to navigate to member for help or dismiss.';

  @override
  String get leftGroup => 'Has left';

  @override
  String get joinedGroup => 'Has joined';

  @override
  String get viaQR => 'via QR.';

  @override
  String get doYouWantToJoin => 'Would you like to join?';

  @override
  String get invitationSent => 'Invitation sent successfully.';

  @override
  String get invitationAlreadySent =>
      'You have already sent an invitation to this member. Please wait for their response.';

  @override
  String get invitationFailed => 'Failed to send invitation. Please try again.';

  @override
  String get confirmDelete => 'Are you sure you want to delete';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get cancel => 'Cancel';

  @override
  String get questionMark => '?';

  @override
  String get groupDeleted => 'Group deleted successfully.';

  @override
  String get groupDeletedFailed => 'Failed to delete group.';

  @override
  String get joinSuccess => 'You are currently a member of the group.';

  @override
  String get joinAlreadyMember => 'You are already a member of the group.';

  @override
  String get scanQR => 'Scan QR to join a group';

  @override
  String get confirmJoinGroup => 'Join this group?';

  @override
  String get groupId => 'Group ID';

  @override
  String get confirmExit => 'Are you sure you want to exit the group?';

  @override
  String get exitSuccess => 'You have exited the group';

  @override
  String get exitFailed => 'Failed to exit group';

  @override
  String get unknownAddress => 'Unknown Address';

  @override
  String get confirmSosRequest => 'Are you sure you want to send SOS alert';

  @override
  String get groupLeader => 'group\'s leader';

  @override
  String get allMembers => 'all group members';

  @override
  String get thisGroup => 'this group';

  @override
  String get sosRequestFailed => 'Failed to send SOS alert. Try again.';

  @override
  String get sosRequestAlreadySent =>
      'You have already sent a pending SOS request. Please wait for their response.';

  @override
  String get sosRequestSuccess => 'SOS request sent successfully.';

  @override
  String get sosRequestSent => 'You have sent an SOS request';

  @override
  String get cancelSosRequest =>
      'Please wait for help or click to cancel SOS request.';

  @override
  String get cancelSosRequestSuccess => 'SOS request cancelled successfully.';

  @override
  String get sosRequestCancelled => 'SOS request was cancelled by this member';

  @override
  String get confirmCancelSosRequest =>
      'Are you sure you want to cancel SOS request?';

  @override
  String get confirmNavigateMemberLocation =>
      'Are you sure you want to navigate to this member\'s location?';

  @override
  String get onTheWay => 'Currently is on the way';

  @override
  String get toYou => 'to you';

  @override
  String get to => 'to';

  @override
  String get toMember => 'to member';

  @override
  String get inGroup => 'in';

  @override
  String get youOnTheWay => 'You are currently on the way';

  @override
  String get clickIfArrivedOrToCancel =>
      'Click if you arrived at location or wish to cancel help.';

  @override
  String get confirmArrivedSosSenderLocation =>
      'Are you sure you have arrived at member\'s location?';

  @override
  String get confirmCancelSosSenderHelp =>
      'Are you sure you want to stop heading to the SOS request sender?';

  @override
  String get arrivedSosMemberSuccess =>
      'Thanks God for safe arrival. Thank you for your help.';

  @override
  String get onTheWayArrived => 'Currently is at ';

  @override
  String get yourLocation => 'your location';

  @override
  String get clickIfYouAreSafeOrDismiss =>
      'Click if you are safe or to dismiss.';

  @override
  String get theMemberLocation => 'the location of member';

  @override
  String get confirmYouAreSafe => 'Are you sure you are safe currently?';

  @override
  String get sosMemberSafeSuccess => 'Thanks God you are safe currently.';

  @override
  String get isSafe => 'This member is currently safe.';

  @override
  String get cancelSosMemberOnTheWaySuccess =>
      'You cancelled your way to the SOS requester.';

  @override
  String get onTheWayCancelled => 'Have cancelled the way to ';

  @override
  String get nMembers => 'Members';

  @override
  String get nSos => 'SOS Now';

  @override
  String get nOutsideGeofence => 'Outside';

  @override
  String get outOf => '/';

  @override
  String get sendSos => 'Send';

  @override
  String get cancelSos => 'Cancel';

  @override
  String get sosRequestNoVisibleMembers =>
      'There are currently no members to available to receive your SOS alert. Please check that you’re in an active group and try again.';

  @override
  String get enterBroadcastMessage => 'Please enter alert message.';

  @override
  String get sendBroadcastMessage => 'Send an alert to your group';

  @override
  String get messageText => 'Alert message';

  @override
  String get messageTextHint => 'It\'s crowded here. Let\'s head north.';

  @override
  String get makeItShort => 'Please limit your alert to 60 characters';

  @override
  String get broadcastSent => 'Alert sent to group successfully.';
}
