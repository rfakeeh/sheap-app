import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/orchestrator.dart';
import '../providers/language_provider.dart';
import '../providers/location_provider.dart';
import '../providers/group_provider.dart';
import '../providers/geocoding_provider.dart';
import '../providers/user_provider.dart';
import '../providers/member_geofence_provider.dart';

import '../l10n/app_localizations.dart';
import '../utils/helpers.dart';

import '../models/user_model.dart';
import '../models/group_model.dart';
import '../models/location_model.dart';
import '../models/member_model.dart';
import '../models/destination_model.dart';

import '../repositories/group_repository.dart';
import '../repositories/location_repository.dart';
import '../repositories/member_geofence_repository.dart';

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
  final MemberGeofenceRepository _memberGeofenceRepository =
      MemberGeofenceRepository();
  final Orchestrator _orchestrator = Orchestrator();

  // Track locale to trigger updates when language changes
  Locale? _lastLocale;
  late BuildContext rootContext;

  // Text controller for searching Hajj locations
  late final TextEditingController _locationFilterController;
  String _searchQuery = "";

  // Cached providers to safely use them later in dispose(), without accessing context
  LocationProvider? _locationProvider;
  GroupProvider? _groupProvider;

  @override
  void initState() {
    super.initState();

    // 1) Create the search controller once for this State
    _locationFilterController = TextEditingController();

    // 2) Run async provider-related initialization after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // 2.1 Load locale from LanguageProvider (reads from SharedPreferences)
      final languageProvider = context.read<LanguageProvider>();
      await languageProvider.loadLocale();
      if (!mounted) return;

      final locale = languageProvider.locale;

      // 2.2 Cache providers if not already cached
      // (didChangeDependencies may not have been called yet)
      _locationProvider ??= context.read<LocationProvider>();
      _groupProvider ??= context.read<GroupProvider>();

      // 2.3 Bind current user to LocationProvider and start live tracking
      _locationProvider!.setCurrentUser(widget.user.phoneNumber);
      await _locationProvider!.startLocationTracking();
      if (!mounted) return;

      // 2.4 Start listening to groups of this user
      _groupProvider!.startListening(widget.user.phoneNumber);

      // 2.5 Initialize GeocodingProvider for the first known position
      final geoProvider = context.read<GeocodingProvider>();
      geoProvider.updateLocale(locale);

      final pos = _locationProvider!.currentPosition;
      if (pos != null) {
        geoProvider.requestAddress(pos.latitude, pos.longitude);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 1) Cache providers (safe to call multiple times)
    _locationProvider ??= context.read<LocationProvider>();
    _groupProvider ??= context.read<GroupProvider>();

    // 2) If locale changes, update GeocodingProvider and refresh the displayed address
    final currentLocale = Provider.of<LanguageProvider>(context).locale;
    final geoProvider = context.read<GeocodingProvider>();
    geoProvider.updateLocale(currentLocale);

    final pos = _locationProvider!.currentPosition;
    if (pos != null) {
      geoProvider.requestAddress(pos.latitude, pos.longitude);
    }
  }

  @override
  void dispose() {
    // 1) Dispose search controller
    _locationFilterController.dispose();

    // 2) Stop location tracking and group listeners if they were initialized
    _locationProvider?.stopLocationTracking();
    _groupProvider?.stopListening();

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

    // 1) Watch providers
    final locationProvider = context.watch<LocationProvider>();
    final geocodingProvider = context.watch<GeocodingProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final userProvider = context.watch<UserProvider>();
    final geofenceProvider = context.watch<MemberGeofenceProvider>();

    final allCreatedGroups = groupProvider.createdGroups;
    final allJoinedGroups = groupProvider.joinedGroups;
    final isGroupsLoading = groupProvider.isLoading;
    final groupsError = groupProvider.errorMessage;

    final bool isArabic = languageProvider.locale.languageCode == 'ar';

    // 2) Decide which address text to show in the header
    String headerAddress;

    if (!locationProvider.serviceEnabled) {
      // Location service (GPS) is turned off
      headerAddress = AppLocalizations.of(context)!.locationServiceDisabled;
    } else if (locationProvider.permissionDenied) {
      // User denied location permissions
      headerAddress = AppLocalizations.of(context)!.permissionsDenied;
    } else if (geocodingProvider.isLoading) {
      // We have a position but we are still resolving the address
      headerAddress = AppLocalizations.of(context)!.loading; // add key in l10n
    } else if (geocodingProvider.currentAddress != null &&
        geocodingProvider.currentAddress!.isNotEmpty) {
      // Successfully resolved a human-readable address
      headerAddress = geocodingProvider.currentAddress!;
    } else {
      // Fallback text when we don't yet have an address
      headerAddress = AppLocalizations.of(
        context,
      )!.unknownAddress; // fallback key
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.all(25.0),
              child: Column(
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,

                    // --- HEADER SECTION ---
                    child: HomeHeader(
                      user: widget.user,
                      // Loading = either location stream or geocoding is still busy
                      isLoading:
                          locationProvider.isLoading ||
                          geocodingProvider.isLoading,
                      // Final text that should appear under the name
                      currentAddress: headerAddress,
                    ),
                  ),

                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,

                      // --- MIDDLE SECTION ---
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(height: 10),

                            // --- HOLY LOCATIONS SECTION ---
                            // --- HEADING ---
                            Align(
                              alignment: isArabic
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
                                setState(() {
                                  _searchQuery = value.toLowerCase().trim();
                                });
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

                                final allLocations = snapshot.data!;

                                // If search box is empty, show all locations
                                if (_searchQuery.isEmpty) {
                                  return _buildLocationList(
                                    allLocations,
                                    isArabic,
                                  );
                                }

                                // Filter based on search query
                                final filteredLocations = allLocations.where((
                                  location,
                                ) {
                                  final nameEn = (location.nameEn ?? '')
                                      .toLowerCase();
                                  final nameAr = (location.nameAr ?? '');
                                  return nameEn.contains(_searchQuery) ||
                                      nameAr.contains(_searchQuery);
                                }).toList();

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

                                return _buildLocationList(
                                  filteredLocations,
                                  isArabic,
                                );
                              },
                            ),

                            SizedBox(height: 30),

                            // --- MY GROUPS SECTION ---
                            // --- HEADING ---
                            Align(
                              alignment: isArabic
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
                            Column(
                              children: [
                                isGroupsLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : Column(
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

                                          if (allCreatedGroups.isEmpty)
                                            _buildEmptyState(
                                              AppLocalizations.of(
                                                context,
                                              )!.noCreatedGroups,
                                            )
                                          else
                                            _buildGroupList(
                                              allCreatedGroups,
                                              isArabic,
                                              userProvider,
                                              geofenceProvider,
                                            ),

                                          const SizedBox(height: 30),

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
                                          if (allJoinedGroups.isEmpty)
                                            _buildEmptyState(
                                              AppLocalizations.of(
                                                context,
                                              )!.noJoinedGroups,
                                            )
                                          else
                                            _buildGroupList(
                                              allJoinedGroups,
                                              isArabic,
                                              userProvider,
                                              geofenceProvider,
                                            ),
                                        ],
                                      ),
                              ],
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

  Widget _buildGroupList(
    List<GroupModel> groups,
    bool isArabic,
    UserProvider userProvider,
    MemberGeofenceProvider geofenceProvider,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final isCreator = group.creatorId == widget.user.phoneNumber;
        final isActive = group.isActive;

        final creatorUser = userProvider.getGroupCreator(group);
        final leaderUser = userProvider.getGroupLeader(group);
        final memberUsers = userProvider.getGroupMembers(group);

        final leaderName = leaderUser != null
            ? Helpers.getFirstAndLastName(leaderUser.fullName)
            : AppLocalizations.of(context)!.loading;

        final destConfig = group.destinationConfig;
        final hasDestination = destConfig != null;
        final prefix = AppLocalizations.of(context)!.destination;
        final destinationName = hasDestination
            ? isArabic
                  ? "$prefix: ${destConfig.finalDestination.nameAr}"
                  : "$prefix: ${destConfig!.finalDestination.nameEn}"
            : AppLocalizations.of(context)!.loading;

        final hasGeofence = group.geofenceConfig != null;
        geofenceProvider.startWatchingGroup(group.groupId);
        final membersOutsideGeofenceCount = geofenceProvider.outsideCountFor(
          group.groupId,
        );

        final membersSentSOSCount = 0;

        return Card(
          color: const Color(0xFFF9FAFB),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: isActive
                            ? const Color(0xFFECFDF3)
                            : Colors.grey.shade200,
                        child: Icon(
                          Icons.group,
                          color: isActive ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- GROUP NAME ---
                            Text(
                              group.groupName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // --- LEADER NAME ---
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Text(
                                "${AppLocalizations.of(context)!.leader}: ${leaderName}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),

                            // --- DESTINATION NAME ---
                            if (hasDestination)
                              Text(
                                destinationName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),

                            // --- ALERTS (GEOFENCE / SOS) ---
                            if (isActive)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 8.0,
                                  top: 4.0,
                                ),
                                child: _buildGroupAlertStatus(
                                  context,
                                  hasGeofence: hasGeofence,
                                  membersOutsideGeofenceCount:
                                      membersOutsideGeofenceCount,
                                  membersSentSOSCount: membersSentSOSCount,
                                ),
                              ),
                            //const SizedBox(height: 8),

                            // --- MEMBER AVATARS ---
                            _buildMemberAvatars(
                              context,
                              group,
                              memberUsers,
                              isCreator,
                            ),
                          ],
                        ),
                      ),

                      // --- STATUS CHIP + ARROW ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildStatusChip(isActive),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                // TODO: Navigate to Group Details
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Navigate to Group Details tapped',
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: const Icon(
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
                const SizedBox(height: 10),

                // --- ACTIONS ROW ---
                _buildGroupActions(context, group, isCreator, hasDestination),
              ],
            ),
          ),
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
    List<AppUser> members,
    bool isCreator,
  ) {
    // If members empty and not creator → nothing
    if (members.isEmpty && !isCreator) return SizedBox.shrink();

    double avatarSize = 45.0;
    double borderSize = 2.0;
    double overlap = 10.0;
    int maxVisibleAvatars = 3;

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
    required int membersOutsideGeofenceCount,
    required int membersSentSOSCount,
  }) {
    // 1) Is geofence safe?
    final bool isGeofenceSafe =
        !hasGeofence || membersOutsideGeofenceCount == 0;

    // 2) All safe if geofence is safe AND no SOS
    final bool isAllSafe = isGeofenceSafe && membersSentSOSCount == 0;

    String alertText;

    if (isAllSafe) {
      // GREEN MESSAGE
      alertText = AppLocalizations.of(context)!.allMembersSafe;
    } else {
      // RED MESSAGE
      final List<String> parts = [];

      if (!isGeofenceSafe) {
        parts.add(
          "$membersOutsideGeofenceCount "
          "${AppLocalizations.of(context)!.outsideGeofence}",
        );
      }

      if (membersSentSOSCount > 0) {
        parts.add(
          "$membersSentSOSCount "
          "${AppLocalizations.of(context)!.sentSOS}",
        );
      }

      alertText = parts.join(" ${AppLocalizations.of(context)!.and} ") + "!";
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Icon(
                isAllSafe
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                color: isAllSafe ? Colors.green[700] : Colors.red[700],
                size: 16,
              ),
            ),
            const SizedBox(width: 4),
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
        ),
      ],
    );
  }

  Widget _buildGroupActions(
    BuildContext context,
    GroupModel group,
    bool isCreator,
    bool hasDestination,
  ) {
    // Build the list of action widgets first
    final actions = isCreator
        ? [
            if (group.isActive)
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
            if (group.isActive && hasDestination)
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
            if (hasDestination)
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

  Widget _buildLocationList(List<AppLocation> locations, bool isArabic) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: locations.length,
        itemBuilder: (context, index) {
          final loc = locations[index];
          final displayName = isArabic
              ? (loc.nameAr ?? '')
              : (loc.nameEn ?? '');

          return Container(
            width: 140,
            margin: EdgeInsets.only(right: 15),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFFF3F0FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE0D9FC)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.place, color: Color(0xFF825EF6)),
                SizedBox(height: 5),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
