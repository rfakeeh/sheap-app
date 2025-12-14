import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/orchestrator.dart';
import '../providers/language_provider.dart';
import '../providers/location_provider.dart';

import '../l10n/app_localizations.dart';
import '../utils/helpers.dart';

import '../models/user_model.dart';
import '../models/group_model.dart';
import '../models/location_model.dart';
import '../models/member_model.dart';

import '../repositories/group_repository.dart';
import '../repositories/location_repository.dart';

import '../buttons.dart';
import '../headers.dart';
import '../welcome.dart';
import '../modal.dart';
import '../showqr.dart';
import '../scanqr.dart';
import '../invite.dart';

class HomePage extends StatefulWidget {
  final AppUser user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GroupRepository _groupRepository = GroupRepository();
  final LocationRepository _locationRepository = LocationRepository();
  final Orchestrator _orchestrator = Orchestrator();

  // Track locale to trigger updates when language changes
  Locale? _lastLocale;

  late TextEditingController _locationFilterController;
  late BuildContext rootContext;

  @override
  void initState() {
    super.initState();
    // Get the saved text from Provider
    final savedText = Provider.of<LocationProvider>(
      context,
      listen: false,
    ).searchQuery;
    // Initialize controller with saved text
    _locationFilterController = TextEditingController(text: savedText);

    // 1. Start Location Logic Immediately
    // We use addPostFrameCallback to safely access the Provider context during init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = Provider.of<LanguageProvider>(context, listen: false).locale;
      // This triggers permission checks and starts the live stream
      Provider.of<LocationProvider>(
        context,
        listen: false,
      ).initializeLocation(lang);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 2. Handle Language Changes
    final currentLocale = Provider.of<LanguageProvider>(context).locale;
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      // If language changed, ask provider to re-translate the address
      Provider.of<LocationProvider>(
        context,
        listen: false,
      ).refreshAddressLocale(currentLocale);
    }
  }

  @override
  void dispose() {
    _locationFilterController.dispose(); // Clean up memory
    super.dispose();
  }

  Future<void> _signOut() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedInUserPhone');
    // Provider handles stream disposal automatically
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => WelcomePage()),
        (route) => false,
      );
    }
  }

  void _onAddGroupPressed(bool isArabic) async {
    String desiredName = isArabic
        ? "مجموعة ${Helpers.getFirstAndLastName(widget.user.fullName)}"
        : "${Helpers.getFirstAndLastName(widget.user.fullName)}'s Group";

    await _orchestrator.createInitialGroupForUser(
      userPhone: widget.user.phoneNumber, // e.g. from SharedPreferences
      baseGroupName: desiredName, // The name typed by user in UI
      isArabic: isArabic, // From LanguageProvider
    );
  }

  void _onJoinGroupPressed() async {
    var permission = await Permission.camera.request();

    if (permission.isDenied || permission.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You must allow camera permission to scan QR.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanQRPage(
          onScanned: (groupId) async {
            await _handleScanQRAndJoinGroup(groupId);
          },
        ),
      ),
    );
  }

  Future<void> _handleScanQRAndJoinGroup(String scannedGroupId) async {
    final group = await _groupRepository.getGroupById(scannedGroupId);

    if (group == null) {
      Helpers.showBottomModal(
        context: context,
        page: FullScreenModal(
          icon: Icons.close,
          outerColor: const Color(0xFFFFE6E6),
          innerColor: const Color(0xFFE53935),
          message: AppLocalizations.of(context)!.groupNotFound,
        ),
      );
      return;
    } else {
      // Check if already member
      if (group.memberIds.contains(widget.user.phoneNumber)) {
        Helpers.showBottomModal(
          context: context,
          page: FullScreenModal(
            icon: Icons.close,
            outerColor: const Color(0xFFFFE6E6),
            innerColor: const Color(0xFFE53935),
            message: AppLocalizations.of(context)!.joinAlreadyMember,
          ),
        );
        return;
      }

      // Join group
      await _groupRepository.joinGroup(
        group: group,
        member: GroupMember(
          phoneNumber: widget.user.phoneNumber,
          roles: [],
          joinedAt: DateTime.now(),
        ),
      );
      // Success
      Helpers.showBottomModal(
        context: context,
        page: FullScreenModal(
          icon: Icons.check,
          message: AppLocalizations.of(context)!.joinSuccess,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    rootContext = context;
    // 3. Watch the LocationProvider
    // Any change (permission granted, new location, address found) triggers a rebuild
    final locationProvider = Provider.of<LocationProvider>(context);
    // Watch the LanguageProvider
    final languageProvider = Provider.of<LanguageProvider>(context);
    bool isArabic = languageProvider.locale.languageCode == 'ar';

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              margin: EdgeInsets.all(25.0),
              child: Column(
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,

                    // --- HEADER SECTION ---
                    child: HomeHeader(
                      user: widget.user,
                      isLoadingLocation: locationProvider.isLoading,
                      // Determine what text to show in the header based on state
                      currentAddress: !locationProvider.serviceEnabled
                          ? AppLocalizations.of(
                              context,
                            )!.locationServiceDisabled
                          : locationProvider.permissionDenied
                          ? AppLocalizations.of(context)!.permissionsDenied
                          : locationProvider.currentAddress,
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,

                      // --- MIDDLE SECTION ---
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            /*
                            Text(
                              "${AppLocalizations.of(context)!.welcome}${widget.user.fullName}!",
                              style:  TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                             SizedBox(height: 10.0),
                            Text(
                              AppLocalizations.of(context)!.yourLocation,
                              style:  TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                             SizedBox(height: 20.0),

                            // --- LIVE LOCATION STATUS UI ---
                            if (!locationProvider.serviceEnabled)
                              Column(
                                children: [
                                   Icon(
                                    Icons.location_off,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                   SizedBox(height: 10),
                                   Text(
                                    "Location Services are disabled.",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Geolocator.openLocationSettings();
                                    },
                                    child:  Text("Enable GPS in Settings"),
                                  ),
                                ],
                              )
                            else if (locationProvider.permissionDenied)
                               Text(
                                "Please enable location permissions in settings to use this feature.",
                                style: TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              )
                            else if (locationProvider.isLoading)
                               CircularProgressIndicator(
                                color: Color(0xFF73CF96),
                              )
                            else
                              Column(
                                children: [
                                  Text(
                                    locationProvider.currentAddress ??
                                        "Locating...",
                                    textAlign: TextAlign.center,
                                    style:  TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF5A4BDE),
                                    ),
                                  ),
                                   SizedBox(height: 5),
                                  if (locationProvider.currentPosition != null)
                                    Text(
                                      "${locationProvider.currentPosition!.latitude.toStringAsFixed(5)}, ${locationProvider.currentPosition!.longitude.toStringAsFixed(5)}",
                                      style:  TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              */
                            SizedBox(height: 10),

                            // --- HOLY LOCATIONS SECTION ---
                            // --- HEADING ---
                            Align(
                              alignment:
                                  languageProvider.locale.languageCode == 'ar'
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Text(
                                AppLocalizations.of(context)!.hajjLocations,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(height: 10),

                            // --- SEARCH BAR ---
                            TextFormField(
                              style: TextStyle(fontSize: 14),
                              controller:
                                  _locationFilterController, // <--- 2. CONNECT THE CONTROLLER
                              onChanged: (value) {
                                // Save to provider
                                Provider.of<LocationProvider>(
                                  context,
                                  listen: false,
                                ).setSearchQuery(value);
                              },
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
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
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey,
                                ),
                                hintText: AppLocalizations.of(context)!.search,
                              ),
                            ),
                            SizedBox(height: 10),

                            // --- HOLY LOCATION LIST ---
                            StreamBuilder<List<AppLocation>>(
                              stream: _locationRepository.getFixedLocations(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return SizedBox();

                                // 1. GET ALL DATA
                                final allLocations = snapshot.data!;

                                // 2. FILTER DATA BASED ON SEARCH QUERY
                                final filteredLocations = allLocations.where((
                                  loc,
                                ) {
                                  final query = _locationFilterController.text
                                      .toLowerCase();
                                  // Check both English and Arabic names
                                  return loc.nameEn.toLowerCase().contains(
                                        query,
                                      ) ||
                                      loc.nameAr.contains(query);
                                }).toList();

                                // 3. SHOW EMPTY STATE IF NO RESULTS
                                if (filteredLocations.isEmpty) {
                                  return Container(
                                    height: 50,
                                    alignment: Alignment.center,
                                    child: Text(
                                      AppLocalizations.of(context)!.noResults,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }

                                return SizedBox(
                                  height: 110,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    // Use filteredLocations instead of snapshot.data
                                    itemCount: filteredLocations.length,
                                    itemBuilder: (context, index) {
                                      final loc = filteredLocations[index];

                                      // DYNAMICALLY CHOOSE NAME BASED ON LANGUAGE
                                      final displayName =
                                          languageProvider
                                                  .locale
                                                  .languageCode ==
                                              'ar'
                                          ? loc.nameAr
                                          : loc.nameEn;

                                      return Container(
                                        width: 140,
                                        margin: EdgeInsets.only(right: 15),
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFF3F0FF),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Color(0xFFE0D9FC),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.place,
                                              color: Color(0xFF825EF6),
                                            ),
                                            SizedBox(height: 5),
                                            Text(
                                              displayName,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),

                            SizedBox(height: 30),

                            // --- MY GROUPS SECTION ---
                            // --- HEADING ---
                            Align(
                              alignment:
                                  languageProvider.locale.languageCode == 'ar'
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Text(
                                AppLocalizations.of(context)!.groups,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(height: 10),

                            // --- GROUPS SECTIONS (Created vs Joined) ---
                            StreamBuilder<List<GroupModel>>(
                              stream: _groupRepository.getUserGroups(
                                widget.user.phoneNumber,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Text(
                                    "Error loading groups: ${snapshot.error}",
                                  );
                                }

                                final allGroups = snapshot.data ?? [];

                                // Filter groups in memory
                                final createdGroups = allGroups
                                    .where(
                                      (g) =>
                                          g.leaderId == widget.user.phoneNumber,
                                    )
                                    .toList();
                                final joinedGroups = allGroups
                                    .where(
                                      (g) =>
                                          g.leaderId != widget.user.phoneNumber,
                                    )
                                    .toList();

                                return Column(
                                  children: [
                                    // 1. CREATED GROUPS SECTION
                                    _buildSectionHeader(
                                      AppLocalizations.of(
                                        context,
                                      )!.createdGroups,
                                      AppLocalizations.of(
                                        context,
                                      )!.createNewGroup,
                                      () => _onAddGroupPressed(isArabic),
                                    ),
                                    if (createdGroups.isEmpty)
                                      _buildEmptyState(
                                        AppLocalizations.of(
                                          context,
                                        )!.noCreatedGroups,
                                      )
                                    else
                                      _buildGroupList(createdGroups),

                                    SizedBox(height: 30),

                                    // 2. JOINED GROUPS SECTION
                                    _buildSectionHeader(
                                      AppLocalizations.of(
                                        context,
                                      )!.joinedGroups,
                                      AppLocalizations.of(
                                        context,
                                      )!.joinNewGroup,
                                      _onJoinGroupPressed,
                                    ),
                                    if (joinedGroups.isEmpty)
                                      _buildEmptyState(
                                        AppLocalizations.of(
                                          context,
                                        )!.noJoinedGroups,
                                      )
                                    else
                                      _buildGroupList(joinedGroups),
                                  ],
                                );
                              },
                            ),

                            SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: PrimaryButton(
                      onPressed: () {
                        // Step 6: Map Navigation
                      },
                      child: Text(
                        AppLocalizations.of(context)!.mapView,
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
                      onPressed: _signOut,
                      child: Text(
                        AppLocalizations.of(context)!.signOut,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 20.0,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: double.infinity),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String buttonLabel,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Color(0xFF828282),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton.icon(
            onPressed: onPressed,
            icon: Icon(Icons.add_circle_outline, size: 18),
            label: Text(
              buttonLabel,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFF5A4BDE),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }

  Widget _buildGroupList(List<GroupModel> groups) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];

        // Use FutureBuilder to fetch member details for this group
        return FutureBuilder<List<AppUser>>(
          future: Helpers.fetchGroupMembersDetails(group),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Show a loading indicator for the group card while fetching members
              return Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Error loading members'),
                ),
              );
            }

            final memberUsers = snapshot.data ?? [];

            // Find the leader user object
            final leaderUser = memberUsers.firstWhere(
              (user) => user.phoneNumber == group.leaderId,
              orElse: () => AppUser(
                // Fallback if leader not found
                phoneNumber: '',
                fullName: 'Unknown Leader',
                nationalId: '',
                createdAt: DateTime.now(),
              ),
            );

            final bool hasGeofence = group.geofenceConfig != null;
            int membersOutsideCount = 0;
            int membersSOSCount = 0;

            final bool isCreator =
                leaderUser.phoneNumber == widget.user.phoneNumber;
            final bool isDisabled = !group.isActive && !isCreator;

            return IgnorePointer(
              ignoring: isDisabled,
              child: Opacity(
                opacity: isDisabled ? 0.35 : 1.0,
                child: Card(
                  color: Color(0xFFF9FAFB),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: group.isActive
                                    ? Color(0xFFECFDF3)
                                    : Colors.grey.shade200,
                                child: Icon(
                                  Icons.group,
                                  color: group.isActive
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // --- DISPLAY GROUP NAME ---
                                    Text(
                                      group.groupName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    // --- DISPLAY LEADER NAME ---
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 4.0,
                                      ),
                                      child: Text(
                                        "${AppLocalizations.of(context)!.leader}: ${Helpers.getFirstAndLastName(leaderUser.fullName)}",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),

                                    // --- DISPLAY ALERTS ---
                                    if (group.isActive)
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 8.0),
                                        child: _buildGroupAlertStatus(
                                          context,
                                          hasGeofence: hasGeofence,
                                          membersOutsideCount:
                                              membersOutsideCount,
                                          membersSOSCount: membersSOSCount,
                                        ),
                                      ),
                                    SizedBox(height: 8),

                                    // --- DISPLAY MEMBER AVATARS ---
                                    _buildMemberAvatars(
                                      context,
                                      group,
                                      memberUsers,
                                      isCreator:
                                          leaderUser.phoneNumber ==
                                          widget.user.phoneNumber,
                                    ),
                                  ],
                                ),
                              ),

                              // --- DISPLAY STATUS CHIP ---
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildStatusChip(group.isActive),

                                  // --- VIEW GROUP DETAILS BUTTON ---
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        // TODO: Navigate to Group Details
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Navigate to Group Details tapped',
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(
                                        20,
                                      ), // Add ripple effect
                                      // Use Container with alignment to center the icon within the expanded space
                                      child: Icon(
                                        Icons.arrow_forward_ios,
                                        size: 24,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),

                        // --- DISPLAY ACTIONS ---
                        _buildGroupActions(
                          context,
                          group,
                          leaderUser.phoneNumber == widget.user.phoneNumber,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        // Green for active, light red for inactive
        color: isActive ? Color(0xFFECFDF3) : Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive
            ? AppLocalizations.of(context)!.trackingOn
            : AppLocalizations.of(context)!.trackingOff,
        style: TextStyle(
          // Darker green for active text, red for inactive text
          color: isActive ? Colors.green : Color(0xFFC62828),
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildMemberAvatars(
    BuildContext context,
    GroupModel group,
    List<AppUser> members, {
    required bool isCreator,
  }) {
    // If members empty and not creator → nothing
    if (members.isEmpty && !isCreator) return SizedBox.shrink();

    double avatarSize = 45.0;
    double borderSize = 2.0;
    double overlap = 15.0;
    int maxVisibleAvatars = 2;

    // ====== 0. REORDER MEMBERS TO SHOW CREATOR FIRST ======
    List<AppUser> ordered = [];
    ordered.addAll(members);

    // Now ordered = [Creator, member1, member2, ...]
    List<Widget> stackChildren = [];

    // ===== 1. Determine how many "standard avatars" to show =====
    // We ALWAYS show creator first, then up to 2 more members.
    int totalMembers = ordered.length;
    int avatarsToShow = totalMembers > maxVisibleAvatars
        ? maxVisibleAvatars
        : totalMembers;

    // ===== 2. Add visible avatars (creator + up to 2 members) =====
    for (int i = 0; i < avatarsToShow; i++) {
      final member = ordered[i];
      final initials = Helpers.getInitials(member.fullName);
      final color = SmartColorGenerator.getColor(i);

      stackChildren.add(
        Positioned.directional(
          textDirection: Directionality.of(context),
          start: i * (avatarSize - overlap),
          top: 0,
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: borderSize),
            ),
            child: CircleAvatar(
              backgroundColor: color,
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    int nextIndex = avatarsToShow;

    // ===== 3. Add remaining count avatar (IF extra members exist) =====
    if (totalMembers > avatarsToShow) {
      int remainingCount = totalMembers - avatarsToShow;

      stackChildren.add(
        Positioned.directional(
          textDirection: Directionality.of(context),
          start: nextIndex * (avatarSize - overlap),
          top: 0,
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
              border: Border.all(color: Colors.white, width: borderSize),
            ),
            child: Center(
              child: Text(
                '+$remainingCount',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );

      nextIndex++;
    }

    // ===== 4. If creator → ADD final "+" button =====
    if (isCreator) {
      stackChildren.add(
        Positioned.directional(
          textDirection: Directionality.of(context),
          start: nextIndex * (avatarSize - overlap),
          top: 0,
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(color: Colors.white, width: borderSize),
            ),
            child: Material(
              color: Colors.transparent,
              shape: CircleBorder(),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                onTap: () {
                  Helpers.showBottomModal(
                    context: context,
                    page: InviteMemberPage(groupId: group.groupId),
                  );
                },
                child: Center(
                  child: Icon(Icons.add, color: Colors.black54, size: 20),
                ),
              ),
            ),
          ),
        ),
      );

      nextIndex++;
    }

    // ===== 5. Width Calculation =====
    double stackWidth =
        (avatarSize * nextIndex) -
        (overlap * (nextIndex > 0 ? nextIndex - 1 : 0));

    return SizedBox(
      height: avatarSize,
      width: stackWidth,
      child: Stack(children: stackChildren),
    );
  }

  Widget _buildGroupAlertStatus(
    BuildContext context, {
    required bool hasGeofence,
    required int membersOutsideCount,
    required int membersSOSCount,
  }) {
    // Determine if everyone is safe based on the rules provided:
    // 1. If no geofence config, ignore outside count.
    // 2. If geofence config exists, outside count must be 0.
    // 3. SOS count must always be 0.

    /*
    hasGeofence = true;
    membersOutsideCount = 0;
    membersSOSCount = 0;
    */

    bool isGeofenceSafe = !hasGeofence || membersOutsideCount == 0;
    bool isAllSafe = isGeofenceSafe && membersSOSCount == 0;
    String alertText = "";

    if (isAllSafe) {
      // --- GREEN STATE ---
      alertText = AppLocalizations.of(context)!.allMembersSafe;
    } else {
      // --- RED STATE ---
      List<String> alertParts = [];
      // Note: You should use localization for plurals here in a real app
      if (hasGeofence && membersOutsideCount > 0) {
        alertParts.add(
          "$membersOutsideCount ${AppLocalizations.of(context)!.outsideGeofence}",
        );
      }
      if (membersSOSCount > 0) {
        alertParts.add(
          "$membersSOSCount ${AppLocalizations.of(context)!.sentSOS}",
        );
        alertText = alertParts.join(" ${AppLocalizations.of(context)!.and} ");
      }

      alertText += "!";
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2.0),
          child: isAllSafe
              ? Icon(
                  Icons.check_circle_outline,
                  color: Colors.green[700],
                  size: 16,
                )
              : Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red[700],
                  size: 16,
                ),
        ),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            alertText,
            style: TextStyle(
              color: isAllSafe ? Colors.green[700] : Colors.red[700],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupActions(
    BuildContext context,
    GroupModel group,
    bool isCreator,
  ) {
    // Build the list of action widgets first
    final actions = isCreator
        ? [
            if (group.isActive)
              if (group.isActive)
                _buildActionIcon(
                  context,
                  Icons.notifications_active,
                  AppLocalizations.of(context)!.alertGroup,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Alert Group tapped')),
                    );
                  },
                ),
            _buildActionIcon(
              context,
              Icons.qr_code_2,
              AppLocalizations.of(context)!.showQR,
              () {
                Helpers.showBottomModal(
                  context: context,
                  page: ShowQRPage(
                    groupId: group.groupId,
                    groupName: group.groupName,
                  ),
                );
              },
            ),
            if (group.isActive)
              _buildActionIcon(
                context,
                Icons.route,
                AppLocalizations.of(context)!.navigateToDestination,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('To Destination tapped')),
                  );
                },
              ),
            if (group.isActive)
              _buildActionIcon(
                context,
                Icons.location_off,
                AppLocalizations.of(context)!.disableTracking,
                () async {
                  await _groupRepository.toggleGroupStatus(
                    group.groupId,
                    false,
                  );
                },
              )
            else
              _buildActionIcon(
                context,
                Icons.location_on,
                AppLocalizations.of(context)!.enableTracking,
                () async {
                  await _groupRepository.toggleGroupStatus(group.groupId, true);
                },
              ),
            _buildActionIcon(
              context,
              Icons.highlight_off,
              AppLocalizations.of(context)!.delete,
              () {
                /*
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Delete Group tapped')));
                */

                Helpers.showBottomModal(
                  context: rootContext,
                  page: FullScreenModal(
                    icon: Icons.priority_high,
                    outerColor: const Color(0xFFFFF4CE),
                    innerColor: const Color(0xFFFFC107),
                    message:
                        "${AppLocalizations.of(rootContext)!.confirmDelete} ${AppLocalizations.of(rootContext)!.the.toLowerCase()}${AppLocalizations.of(rootContext)!.group.toLowerCase()}${AppLocalizations.of(rootContext)!.questionMark}",
                    showCloseButton: true,
                    bottomActions: [
                      Container(
                        margin: EdgeInsets.all(8.0),
                        alignment: Alignment.center,
                        child: PrimaryButton(
                          onPressed: () async {
                            Navigator.pop(rootContext); // Close warning modal
                            try {
                              await _groupRepository.deleteGroup(group.groupId);
                              Helpers.showBottomModal(
                                context: rootContext,
                                page: FullScreenModal(
                                  icon: Icons.check,
                                  message: AppLocalizations.of(
                                    rootContext,
                                  )!.groupDeleted,
                                ),
                              );
                            } catch (e) {
                              Helpers.showBottomModal(
                                context: rootContext,
                                page: FullScreenModal(
                                  icon: Icons.close,
                                  outerColor: const Color(0xFFFFE6E6),
                                  innerColor: const Color(0xFFE53935),
                                  message: AppLocalizations.of(
                                    rootContext,
                                  )!.groupDeletedFailed,
                                ),
                              );
                            }
                          },
                          child: Text(
                            AppLocalizations.of(rootContext)!.yes,
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
                          onPressed: () => Navigator.pop(rootContext),
                          child: Text(
                            AppLocalizations.of(rootContext)!.no,
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
            ),
            _buildActionIcon(
              context,
              Icons.settings,
              AppLocalizations.of(context)!.edit,
              () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Edit Group tapped')));
              },
            ),
          ]
        : [
            _buildActionIcon(
              context,
              Icons.notifications_active,
              AppLocalizations.of(context)!.alertGroup,
              () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Alert Group tapped')));
              },
            ),
            _buildActionIcon(
              context,
              Icons.route,
              AppLocalizations.of(context)!.navigateToLeader,
              () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('To Leader tapped')));
              },
            ),
            _buildActionIcon(
              context,
              Icons.route,
              AppLocalizations.of(context)!.navigateToDestination,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('To Destination tapped')),
                );
              },
            ),
            _buildActionIcon(
              context,
              Icons.logout,
              AppLocalizations.of(context)!.exit,
              () {
                // ==== SHOW CONFIRM MODAL ====
                Helpers.showBottomModal(
                  context: rootContext,
                  page: FullScreenModal(
                    icon: Icons.priority_high,
                    outerColor: const Color(0xFFFFF4CE),
                    innerColor: const Color(0xFFFFC107),
                    message: AppLocalizations.of(rootContext)!.confirmExit,
                    showCloseButton: true,
                    bottomActions: [
                      // --- YES BUTTON ---
                      Container(
                        margin: EdgeInsets.all(8.0),
                        alignment: Alignment.center,
                        child: PrimaryButton(
                          onPressed: () async {
                            Navigator.pop(rootContext); // close confirm modal

                            try {
                              await _groupRepository.removeMember(
                                group: group,
                                phoneNumber: widget.user.phoneNumber,
                              );

                              // SUCCESS MODAL
                              Helpers.showBottomModal(
                                context: rootContext,
                                page: FullScreenModal(
                                  icon: Icons.check,
                                  message: AppLocalizations.of(
                                    rootContext,
                                  )!.exitSuccess,
                                ),
                              );
                            } catch (e) {
                              // FAILURE MODAL
                              Helpers.showBottomModal(
                                context: rootContext,
                                page: FullScreenModal(
                                  icon: Icons.close,
                                  outerColor: const Color(0xFFFFE6E6),
                                  innerColor: const Color(0xFFE53935),
                                  message: AppLocalizations.of(
                                    rootContext,
                                  )!.exitFailed,
                                ),
                              );
                            }
                          },
                          child: Text(
                            AppLocalizations.of(rootContext)!.yes,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 20.0,
                            ),
                          ),
                        ),
                      ),

                      // --- NO BUTTON ---
                      Container(
                        margin: EdgeInsets.all(8.0),
                        alignment: Alignment.center,
                        child: SecondaryButton(
                          onPressed: () => Navigator.pop(rootContext),
                          child: Text(
                            AppLocalizations.of(rootContext)!.no,
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
            ),
          ];

    return SizedBox(
      height: 45,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        padding: EdgeInsets.symmetric(horizontal: 10),
        separatorBuilder: (_, __) => SizedBox(width: 12),
        itemBuilder: (context, index) => actions[index],
      ),
    );
  }

  Widget _buildActionIcon(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        8.0,
      ), // Add some border radius for the ripple
      child: Padding(
        padding: EdgeInsets.all(5.0), // Add some padding for better touch area
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Color(0xFF3C32A3),
              size: 20,
            ), // Your primary color
            SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: Color(0xFF3C32A3),
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
