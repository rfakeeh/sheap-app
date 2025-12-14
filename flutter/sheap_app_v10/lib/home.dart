import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sheap_app_v3/repositories/alert_repository.dart';

import '../services/orchestrator.dart';
import '../services/movement_simulator.dart';

import '../providers/language_provider.dart';
import '../providers/location_provider.dart';
import '../providers/group_provider.dart';
import '../providers/geocoding_provider.dart';
import '../providers/user_provider.dart';
import '../providers/member_geofence_provider.dart';
import '../providers/alert_provider.dart';
import '../providers/member_sos_provider.dart';

import '../l10n/app_localizations.dart';
import '../utils/helpers.dart';

import '../models/user_model.dart';
import '../models/group_model.dart';
import '../models/location_model.dart';
import '../models/alert_model.dart';

import '../repositories/group_repository.dart';
import '../repositories/location_repository.dart';
import '../repositories/member_geofence_repository.dart';

import '../buttons.dart';
import '../headers.dart';
import '../alert.dart';
import '../welcome.dart';
import '../modal.dart';
import '../showqr.dart';
import '../scanqr.dart';
import '../invite.dart';
import '../broadcast.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/user_repository.dart';

import '../exceptions/alert_exception.dart';
import 'package:load_switch/load_switch.dart';

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

  late final MovementSimulator _simulator;

  bool switchValue = false;

  bool isSosLoading = false;

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
        geoProvider.requestAddress(
          pos.latitude,
          pos.longitude,
          AppLocalizations.of(context)!.unknownAddress,
        );
      }

      context.read<AlertProvider>().startListening(widget.user.phoneNumber);

      context.read<SosCounterProvider>().setCurrentUser(
        widget.user.phoneNumber,
      );
      context.read<SosCounterProvider>().refresh();

      final firestore = FirebaseFirestore.instance;
      final userRepo = UserRepository();
      final currentUserPhone = widget.user.phoneNumber;

      _simulator = MovementSimulator(
        firestore: firestore,
        userRepository: userRepo,
        groupRepository: _groupRepository,
        orchestrator: _orchestrator,
        currentUserPhone: currentUserPhone,
        activeGroupsOnly: true,
      );

      //_setupSimulation();
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
      geoProvider.requestAddress(
        pos.latitude,
        pos.longitude,
        AppLocalizations.of(context)!.unknownAddress,
      );
    }
  }

  @override
  void dispose() {
    // 1) Dispose search controller
    _locationFilterController.dispose();

    // 2) Stop location tracking and group listeners if they were initialized
    _locationProvider?.stopLocationTracking();
    _groupProvider?.stopListening();

    _simulator.dispose();
    super.dispose();
  }

  Future<void> _setupSimulation() async {
    final centers = <AppLocation>[
      AppLocation(
        id: 'kaaba',
        nameEn: 'Kaaba',
        nameAr: 'الكعبة',
        latitude: 21.422529,
        longitude: 39.826154,
        descriptionEn: null,
        descriptionAr: null,
      ),
      AppLocation(
        id: 'zamzam1',
        nameEn: 'Zamzam Point',
        nameAr: 'زمزم ١',
        latitude: 21.422527,
        longitude: 39.826348,
        descriptionEn: null,
        descriptionAr: null,
      ),
      AppLocation(
        id: 'salam',
        nameEn: 'Salam Gate Area',
        nameAr: 'منطقة السلام',
        latitude: 21.422577,
        longitude: 39.827376,
        descriptionEn: null,
        descriptionAr: null,
      ),
      AppLocation(
        id: 'saee',
        nameEn: 'Saee Area',
        nameAr: 'السعي',
        latitude: 21.422021,
        longitude: 39.827358,
        descriptionEn: null,
        descriptionAr: null,
      ),
    ];

    await _simulator.initialize(centers);
    _simulator.start();
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
      // 1) Check if user is already a member
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

      // 2) Join group + notify creator using orchestrator
      await _orchestrator.joineGroupAndNotify(
        group: group,
        memberPhone: widget.user.phoneNumber,
        memberName: Helpers.getFirstAndLastName(widget.user.fullName),
      );

      // 3) Show success modal to the current user
      Helpers.showBottomModal(
        context: context,
        page: FullScreenModal(
          icon: Icons.check,
          message: AppLocalizations.of(context)!.joinSuccess,
        ),
      );
    }
  }

  Future<bool> _getFuture() async {
    await Future.delayed(const Duration(seconds: 3));
    return !switchValue;
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
    final alertProvider = context.watch<AlertProvider>();

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

    // 3) Get top banner alert
    final topBannerAlert = alertProvider.topBannerAlert;

    final isSosActive = context.watch<SosCounterProvider>().isCurrentUserInSos;

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
                    child: AppHeader(
                      user: widget.user,
                      // Loading = either location stream or geocoding is still busy
                      isLoading:
                          locationProvider.isLoading ||
                          geocodingProvider.isLoading,
                      // Final text that should appear under the name
                      currentAddress: headerAddress,
                    ),
                  ),

                  Column(
                    children: [
                      if (topBannerAlert != null &&
                          topBannerAlert.type == AlertType.broadcast)
                        _buildBroadcastAlertBanner(topBannerAlert, isArabic),
                      if (topBannerAlert != null &&
                          topBannerAlert.type == AlertType.sosRequest)
                        _buildSosRequestAlertBanner(topBannerAlert, isArabic),
                      if (topBannerAlert != null &&
                          topBannerAlert.type == AlertType.sosMemberComing)
                        _buildSosMemberComingAlertBanner(
                          topBannerAlert,
                          isArabic,
                        ),
                      if (topBannerAlert != null &&
                          topBannerAlert.type ==
                              AlertType.sosMemberComingArrived)
                        _buildSosMemberComingArrivedAlertBanner(
                          topBannerAlert,
                          isArabic,
                        ),
                      if (topBannerAlert != null &&
                          topBannerAlert.type == AlertType.sosMemberComingSent)
                        _buildSosMemberComingSentAlertBanner(
                          topBannerAlert,
                          isArabic,
                        ),
                      if (topBannerAlert != null &&
                          topBannerAlert.type ==
                              AlertType.sosMemberComingCancelled)
                        _buildSosMemberComingCancelledAlertBanner(
                          topBannerAlert,
                          isArabic,
                        ),
                      if (topBannerAlert != null &&
                          topBannerAlert.type == AlertType.sosRequestCancelled)
                        _buildSosRequestCancelledAlertBanner(
                          topBannerAlert,
                          isArabic,
                        ),
                      if (topBannerAlert != null &&
                          topBannerAlert.type == AlertType.sosRequestSent)
                        _buildSosRequestSentAlertBanner(
                          topBannerAlert,
                          isArabic,
                        ),

                      if (topBannerAlert != null &&
                          topBannerAlert.type == AlertType.sosMemberSafe)
                        _buildSosMemberSafeAlertBanner(
                          topBannerAlert,
                          isArabic,
                        ),
                      if (topBannerAlert != null &&
                          topBannerAlert.type == AlertType.invitationRequest &&
                          topBannerAlert.requiresAction == true &&
                          topBannerAlert.status == AlertStatus.pending)
                        _buildInvitationRequestAlertBanner(
                          topBannerAlert,
                          isArabic,
                        ),
                      if (topBannerAlert != null &&
                          topBannerAlert.type == AlertType.invitationRejected &&
                          topBannerAlert.requiresAction == false)
                        _buildInvitationRejectedAlertBanner(
                          topBannerAlert,
                          isArabic,
                        ),
                      if (topBannerAlert != null &&
                          topBannerAlert.type == AlertType.invitationAccepted &&
                          topBannerAlert.requiresAction == false)
                        _buildInvitationAcceptedAlertBanner(
                          topBannerAlert,
                          isArabic,
                        ),
                      if (topBannerAlert != null &&
                          topBannerAlert.type == AlertType.memberJoinedGroup &&
                          topBannerAlert.requiresAction == false)
                        _buildMemberJoinedGroupAlertBanner(
                          topBannerAlert,
                          isArabic,
                        ),
                      if (topBannerAlert != null &&
                          topBannerAlert.type == AlertType.memberLeftGroup &&
                          topBannerAlert.requiresAction == false)
                        _buildMemberLeftGroupAlertBanner(
                          topBannerAlert,
                          isArabic,
                        ),
                      /*
                      if (topBannerAlert != null &&
                          topBannerAlert.type ==
                              AlertType
                                  .invitationRejected //&&
                      //topBannerAlert.requiresAction == true &&
                      //topBannerAlert.status == AlertStatus.pending
                      )
                        _buildInvitationRequestAlertBanner(
                          topBannerAlert,
                          isArabic,
                        ),
                        */
                    ],
                  ),

                  /*
                  Column(
                    children: [
                      AppAlert(      time: Helpers.timeAgo(alert.sentAt, isArabic: true),

                        icon: Icons.info,
                        title: "رنا فقيه",
                        message:
                            "قام/ـت بدعوتك إلى مجموعة  حملة 1.\nهل ترغب بالانضمام ؟",
                        borderColor: Color(0xFFE0D9FC),
                        backgroundColor: Color(0xFFF3F0FF),
                        iconColor: Color(0xFF3C32A3),
                        contentColor: Color(0xFF3C32A3),
                        actions: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.check,
                              color: Color(0xFF3C32A3),
                              size: 25,
                            ),
                            onPressed: () {},
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.close,
                              color: Color(0xFF3C32A3),
                              size: 25,
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      /*
                      AppAlert(      time: Helpers.timeAgo(alert.sentAt, isArabic: true),

                        icon: Icons.warning,
                        title: "محمد القرشي",
                        message: "في حالة طوارئ حاليا",
                        actions: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.directions,
                              color: Color(0xFFB71C1C),
                              size: 35,
                            ),
                            onPressed: () {},
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.close,
                              color: Color(0xFFB71C1C),
                              size: 30,
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),

                      AppAlert(      time: Helpers.timeAgo(alert.sentAt, isArabic: true),

                        icon: Icons.check_circle,
                        title: "محمد القرشي",
                        message: "أصبح داخل السياج حاليا",
                        borderColor: Color(0xFFB8D9C8),
                        backgroundColor: Color(0xFFEFFAF4),
                        iconColor: Color(0xFF0F5132),
                        contentColor: Color(0xFF0F5132),
                        actions: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.close,
                              color: Color(0xFF0F5132),
                              size: 30,
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),

                      AppAlert(      time: Helpers.timeAgo(alert.sentAt, isArabic: true),

                        icon: Icons.info,
                        title: "محمد القرشي",
                        message: "قادم إليك حاليا. ابق مكانك",
                        borderColor: Color(0xFFE0D9FC),
                        backgroundColor: Color(0xFFF3F0FF),
                        iconColor: Color(0xFF3C32A3),
                        contentColor: Color(0xFF3C32A3),
                        actions: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.close,
                              color: Color(0xFF3C32A3),
                              size: 30,
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      */
                    ],
                  ),
                  */
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
                                    color: Color(0xFFE4E4E4),
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // SOS Button
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 15,
                          right: 25,
                          left: 15,
                        ),
                        child: EmergencySOSButton(
                          isSosLoading: isSosLoading,
                          isSosActive: isSosActive,
                          onPressed: () {
                            if (!isSosLoading) {
                              if (!isSosActive) {
                                // send SOS
                                _handleSendSosRequest();
                              } else {
                                // cancel Sos
                                _handleCancelSosRequest(topBannerAlert!);
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  Container(
                    margin: EdgeInsets.all(5.0),
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
                    margin: EdgeInsets.all(5.0),
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
        final isLeader = group.leaderId == widget.user.phoneNumber;
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
                  : "$prefix: ${destConfig.finalDestination.nameEn}"
            : AppLocalizations.of(context)!.loading;

        final hasGeofence = group.geofenceConfig != null;
        geofenceProvider.startWatchingGroup(group.groupId);
        //final membersOutsideGeofenceCount = 0;
        final membersOutsideGeofenceCount = geofenceProvider.outsideCountFor(
          group.groupId,
        );

        //final membersSentSOSCount = 0;
        final membersSentSOSCount = context
            .watch<SosCounterProvider>()
            .pendingSelfSosCountForGroup(group.groupId);

        return Card(
          color: const Color(0xFFF9FAFB),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Color(0xFFE4E4E4), width: 1),
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
                                "${AppLocalizations.of(context)!.leader}: $leaderName",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),

                            // --- LEADER CURRENT ADDRESS ---
                            if (leaderUser != null &&
                                leaderUser.lastKnownLocation != null)
                              FutureBuilder<String?>(
                                future:
                                    Provider.of<GeocodingProvider>(
                                      context,
                                      listen: false,
                                    ).getAddress(
                                      leaderUser.lastKnownLocation!.latitude,
                                      leaderUser.lastKnownLocation!.longitude,
                                      AppLocalizations.of(
                                        context,
                                      )!.unknownAddress,
                                    ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Text(
                                      "${AppLocalizations.of(context)!.location}: ${AppLocalizations.of(context)!.loading}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  }

                                  final address =
                                      snapshot.data ??
                                      (AppLocalizations.of(
                                        context,
                                      )!.unknownAddress);

                                  return Text(
                                    isArabic
                                        ? "الموقع: $address"
                                        : "Location: $address",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  );
                                },
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
                                  membersCount: memberUsers.length,
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
                _buildGroupActions(
                  context,
                  group,
                  isCreator,
                  isLeader,
                  hasDestination,
                ),
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
                    context: rootContext,
                    page: InviteMemberPage(
                      username: Helpers.getFirstAndLastName(
                        widget.user.fullName,
                      ),
                      groupId: group.groupId,
                    ),
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
    required int membersCount,
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

      alertText = "${parts.join(" ${AppLocalizations.of(context)!.and} ")}!";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 85,
              child: Text(
                "${AppLocalizations.of(context)!.nSos}:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: membersSentSOSCount == 0
                      ? Colors.green[700]
                      : Colors.red[700],
                ),
              ),
            ),
            Text(
              "$membersSentSOSCount / $membersCount",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: membersSentSOSCount == 0
                    ? Colors.green[700]
                    : Colors.red[700],
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 85,
              child: Text(
                "${AppLocalizations.of(context)!.nOutsideGeofence}:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: membersOutsideGeofenceCount == 0
                      ? Colors.green[700]
                      : Colors.red[700],
                ),
              ),
            ),
            Text(
              "$membersOutsideGeofenceCount / $membersCount",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: membersOutsideGeofenceCount == 0
                    ? Colors.green[700]
                    : Colors.red[700],
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
    bool isLeader,
    bool hasDestination,
  ) {
    // Build the list of action widgets first
    final actions = isCreator
        ? [
            if (group.isActive)
              _buildActionIcon(
                context,
                //Icons.notifications_active,
                Icons.emergency_share,
                AppLocalizations.of(context)!.alertGroup,
                () {
                  Helpers.showBottomModal(
                    context: rootContext,
                    page: BroadcastAlertPage(user: widget.user, group: group),
                  );
                  /*
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Alert Group tapped')));
                  */
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
                //Icons.route,
                Icons.directions,
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
              //Icons.notifications_active,
              Icons.emergency_share,
              AppLocalizations.of(context)!.alertGroup,
              () {
                if (isLeader) {
                  // send an editable message to some or all members
                  // display suitable dialog message
                  // if OK -> _handleLeaderAlertToGroup(group, receivers, message);
                } else {}
                Helpers.showBottomModal(
                  context: rootContext,
                  page: BroadcastAlertPage(user: widget.user, group: group),
                );
              },
            ),
            _buildActionIcon(
              context,
              //Icons.route,
              Icons.directions,
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
                //Icons.route,
                Icons.directions,
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
                              await _orchestrator.leaveGroupAndNotify(
                                group: group,
                                userPhone: widget.user.phoneNumber,
                                userName: Helpers.getFirstAndLastName(
                                  widget.user.fullName,
                                ),
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
                Icon(Icons.place, color: Color(0xFF3C32A3)),
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

  Widget _buildInvitationRequestAlertBanner(AlertModel alert, bool isArabic) {
    final payload = alert.payload;
    final senderName = payload['senderName'] as String? ?? '';
    final groupName = payload['groupName'] as String? ?? '';

    // You can either use alert.message directly (already localized),
    // or build a message from l10n + payload.

    final message =
        "${AppLocalizations.of(context)!.receivedGroupInvitation} '$groupName'. ${AppLocalizations.of(context)!.doYouWantToJoin}";

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.info,
      title: senderName.isNotEmpty ? senderName : "", // or any fallback
      message: message,
      borderColor: const Color(0xFFE0D9FC),
      backgroundColor: const Color(0xFFF3F0FF),
      iconColor: const Color(0xFF3C32A3),
      contentColor: const Color(0xFF3C32A3),
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.check, color: Color(0xFF3C32A3), size: 25),
          onPressed: () => _handleInvitationAccept(alert),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFF3C32A3), size: 25),
          onPressed: () => _handleInvitationReject(alert, groupName),
        ),
      ],
    );
  }

  Future<void> _handleInvitationAccept(AlertModel alert) async {
    try {
      // 1) Accept the invitation in backend:
      //    - Join the group
      //    - Update case status to "accepted" in Firestore
      await _orchestrator.acceptGroupInvitation(
        alert: alert,
        currentUserPhone: widget.user.phoneNumber,
        userName: Helpers.getFirstAndLastName(widget.user.fullName),
      );

      final alertProvider = context.read<AlertProvider>();

      // 2) Immediately update the case status locally so the notification count updates
      await alertProvider.updateCaseStatus(
        alert.caseId,
        AlertStatus.resolved, // Or a string value depending on your model
      );

      // 3) Mark the specific alert as opened (so the banner hides)
      await alertProvider.markAlertAsOpened(alert.id);

      // 4) Show success modal to the user
      Helpers.showBottomModal(
        context: context,
        page: FullScreenModal(
          icon: Icons.check,
          message: AppLocalizations.of(context)!.joinSuccess,
        ),
      );
    } catch (e) {
      // Show error modal if anything fails
      Helpers.showBottomModal(
        context: context,
        page: FullScreenModal(
          icon: Icons.close,
          outerColor: const Color(0xFFFFE6E6),
          innerColor: const Color(0xFFE53935),
          message: AppLocalizations.of(context)!.invitationFailed,
        ),
      );
    }
  }

  Future<void> _handleInvitationReject(
    AlertModel alert,
    String groupName,
  ) async {
    try {
      // 1) Backend: mark the invitation case as "rejected"
      await _orchestrator.rejectGroupInvitation(
        alert: alert,
        currentUserPhone: widget.user.phoneNumber,
        userName: Helpers.getFirstAndLastName(widget.user.fullName),
        groupName: groupName,
      );

      final alertProvider = context.read<AlertProvider>();

      // 2) Update the case locally to remove it from pending-action list
      await alertProvider.updateCaseStatus(alert.caseId, AlertStatus.resolved);

      // 3) Mark the alert as opened so the banner goes away
      await alertProvider.markAlertAsOpened(alert.id);
    } catch (e) {
      // Show fallback error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.invitationFailed)),
      );
    }
  }

  Widget _buildInvitationRejectedAlertBanner(AlertModel alert, bool isArabic) {
    final payload = alert.payload;
    final senderName = payload['memberName'] as String? ?? '';
    final groupName = payload['groupName'] as String? ?? '';

    // You can either use alert.message directly (already localized),
    // or build a message from l10n + payload.

    final message =
        "${AppLocalizations.of(context)!.rejectedGroupInvitation} '$groupName'.";

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.warning_rounded,
      title: senderName.isNotEmpty ? senderName : "", // or any fallback
      message: message,
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFFB71C1C), size: 25),
          onPressed: () => _handleAlertDismiss(alert),
        ),
      ],
    );
  }

  Widget _buildSosMemberSafeAlertBanner(AlertModel alert, bool isArabic) {
    final payload = alert.payload;
    final sosSender = payload['sosSender'];
    final sosSenderName = sosSender['name'];

    // You can either use alert.message directly (already localized),
    // or build a message from l10n + payload.

    final message = AppLocalizations.of(context)!.isSafe;

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.check_circle,
      title: sosSenderName, // or any fallback
      message: message,
      borderColor: Color(0xFFB8D9C8),
      backgroundColor: Color(0xFFEFFAF4),
      iconColor: Color(0xFF0F5132),
      contentColor: Color(0xFF0F5132),
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFF0F5132), size: 25),
          onPressed: () => _handleAlertDismiss(alert),
        ),
      ],
    );
  }

  Widget _buildInvitationAcceptedAlertBanner(AlertModel alert, bool isArabic) {
    final payload = alert.payload;
    final senderName = payload['memberName'] as String? ?? '';
    final groupName = payload['groupName'] as String? ?? '';

    // You can either use alert.message directly (already localized),
    // or build a message from l10n + payload.

    final message =
        "${AppLocalizations.of(context)!.acceptedGroupInvitation} '$groupName'.";

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.check_circle,
      title: senderName.isNotEmpty ? senderName : "", // or any fallback
      message: message,
      borderColor: Color(0xFFB8D9C8),
      backgroundColor: Color(0xFFEFFAF4),
      iconColor: Color(0xFF0F5132),
      contentColor: Color(0xFF0F5132),
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFF0F5132), size: 25),
          onPressed: () => _handleAlertDismiss(alert),
        ),
      ],
    );
  }

  Widget _buildMemberJoinedGroupAlertBanner(AlertModel alert, bool isArabic) {
    final payload = alert.payload;
    final senderName = payload['memberName'] as String? ?? '';
    final groupName = payload['groupName'] as String? ?? '';

    // You can either use alert.message directly (already localized),
    // or build a message from l10n + payload.

    final message =
        "${AppLocalizations.of(context)!.joinedGroup} '$groupName' ${AppLocalizations.of(context)!.viaQR}";

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.info,
      title: senderName,
      message: message,
      borderColor: const Color(0xFFE0D9FC),
      backgroundColor: const Color(0xFFF3F0FF),
      iconColor: const Color(0xFF3C32A3),
      contentColor: const Color(0xFF3C32A3),
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFF3C32A3), size: 25),
          onPressed: () => _handleAlertDismiss(alert),
        ),
      ],
    );
  }

  Widget _buildMemberLeftGroupAlertBanner(AlertModel alert, bool isArabic) {
    final payload = alert.payload;
    final senderName = payload['memberName'] as String? ?? '';
    final groupName = payload['groupName'] as String? ?? '';

    // You can either use alert.message directly (already localized),
    // or build a message from l10n + payload.

    final message = "${AppLocalizations.of(context)!.leftGroup} '$groupName'.";

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.warning_rounded,
      title: senderName,
      message: message,
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFFB71C1C), size: 25),
          onPressed: () => _handleAlertDismiss(alert),
        ),
      ],
    );
  }

  Widget _buildSosRequestAlertBanner(AlertModel alert, bool isArabic) {
    final payload = alert.payload;
    final sosSender = payload['sosSender'];

    // You can either use alert.message directly (already localized),
    // or build a message from l10n + payload.

    final message =
        "${AppLocalizations.of(context)!.sentSosRequest}. ${AppLocalizations.of(context)!.clickToHelpOrDismiss}";

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.warning_rounded,
      title: sosSender!['name'],
      message: message,
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.directions,
            color: Color(0xFFB71C1C),
            size: 35,
          ),
          onPressed: () async {
            _handleSosRequestAccept(alert);
            // open navigation screen
          },
        ),
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFFB71C1C), size: 25),
          onPressed: () => _handleAlertDismiss(alert),
        ),
      ],
    );
  }

  Widget _buildSosMemberComingSentAlertBanner(AlertModel alert, bool isArabic) {
    final payload = alert.payload;
    final sosSender = payload['sosSender'];
    final sosSenderName = sosSender!['name'];

    // You can either use alert.message directly (already localized),
    // or build a message from l10n + payload.

    final message =
        "${AppLocalizations.of(context)!.youOnTheWay} ${AppLocalizations.of(context)!.toMember} $sosSenderName. ${AppLocalizations.of(context)!.clickIfArrivedOrToCancel}";

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.info,
      message: message,
      borderColor: const Color(0xFFE0D9FC),
      backgroundColor: const Color(0xFFF3F0FF),
      iconColor: const Color(0xFF3C32A3),
      contentColor: const Color(0xFF3C32A3),
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.check, color: Color(0xFF3C32A3), size: 25),
          onPressed: () async {
            _handleSosMemberComingArrived(alert); // arrived to sos sender
            // open navigation screen
          },
        ),
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFF3C32A3), size: 25),
          onPressed: () =>
              _handleSosMemberComingCancelled(alert), // cancel help
        ),
      ],
    );
  }

  Widget _buildSosMemberComingCancelledAlertBanner(
    AlertModel alert,
    bool isArabic,
  ) {
    final payload = alert.payload;
    final helperName = payload['helperName'];
    final sosSender = payload['sosSender'];
    final sosSenderName = sosSender!['name'];
    final isSosSender = sosSender!['phone'] == widget.user.phoneNumber;

    // You can either use alert.message directly (already localized),
    // or build a message from l10n + payload.
    String message = AppLocalizations.of(context)!.onTheWayCancelled;
    message += isSosSender
        ? "${AppLocalizations.of(context)!.yourLocation}."
        : "${AppLocalizations.of(context)!.theMemberLocation} $sosSenderName.";

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.info,
      title: helperName,
      message: message,
      borderColor: const Color(0xFFE0D9FC),
      backgroundColor: const Color(0xFFF3F0FF),
      iconColor: const Color(0xFF3C32A3),
      contentColor: const Color(0xFF3C32A3),
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFF3C32A3), size: 25),
          onPressed: () {
            _handleAlertDismiss(alert);
          },
        ),
      ],
    );
  }

  Widget _buildBroadcastAlertBanner(AlertModel alert, bool isArabic) {
    final payload = alert.payload;
    final senderName = payload['senderName'];
    final groupName = payload['groupName'];

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.info,
      title: "${senderName}",
      message:
          "${AppLocalizations.of(context)!.to} ${groupName} : ${alert.message!}",
      borderColor: const Color(0xFFE0D9FC),
      backgroundColor: const Color(0xFFF3F0FF),
      iconColor: const Color(0xFF3C32A3),
      contentColor: const Color(0xFF3C32A3),
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFF3C32A3), size: 25),
          onPressed: () {
            _handleAlertDismiss(alert);
          },
        ),
      ],
    );
  }

  Widget _buildSosMemberComingAlertBanner(AlertModel alert, bool isArabic) {
    final payload = alert.payload;
    final helperName = payload['helperName'];
    final sosSender = payload['sosSender'];
    final sosSenderName = sosSender!['name'];
    final isSosSender = sosSender!['phone'] == widget.user.phoneNumber;

    // You can either use alert.message directly (already localized),
    // or build a message from l10n + payload.
    String message = "${AppLocalizations.of(context)!.onTheWay} ";
    message += isSosSender
        ? "${AppLocalizations.of(context)!.toYou}."
        : "${AppLocalizations.of(context)!.toMember} $sosSenderName.";

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.info,
      title: helperName,
      message: message,
      borderColor: const Color(0xFFE0D9FC),
      backgroundColor: const Color(0xFFF3F0FF),
      iconColor: const Color(0xFF3C32A3),
      contentColor: const Color(0xFF3C32A3),
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFF3C32A3), size: 25),
          onPressed: () {
            _handleAlertDismiss(alert);
          },
        ),
      ],
    );
  }

  Widget _buildSosMemberComingArrivedAlertBanner(
    AlertModel alert,
    bool isArabic,
  ) {
    final payload = alert.payload;
    final helperName = payload['helperName'];
    final sosSender = payload['sosSender'];
    final sosSenderName = sosSender!['name'];
    final isSosSender = sosSender!['phone'] == widget.user.phoneNumber;

    // You can either use alert.message directly (already localized),
    // or build a message from l10n + payload.
    String message = AppLocalizations.of(context)!.onTheWayArrived;
    message += isSosSender
        ? "${AppLocalizations.of(context)!.yourLocation}. ${AppLocalizations.of(context)!.clickIfYouAreSafeOrDismiss}"
        : "${AppLocalizations.of(context)!.theMemberLocation} $sosSenderName. ";

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.info,
      title: helperName,
      message: message,
      borderColor: const Color(0xFFE0D9FC),
      backgroundColor: const Color(0xFFF3F0FF),
      iconColor: const Color(0xFF3C32A3),
      contentColor: const Color(0xFF3C32A3),
      actions: [
        if (isSosSender)
          IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.check, color: Color(0xFF3C32A3), size: 25),
            onPressed: () {
              _handleSosMemberSafe(alert);
            },
          ),
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFF3C32A3), size: 25),
          onPressed: () {
            _handleAlertDismiss(alert);
          },
        ),
      ],
    );
  }

  Widget _buildSosRequestSentAlertBanner(AlertModel alert, bool isArabic) {
    final payload = alert.payload;
    final groupName = payload['groupName'] as String? ?? '';

    // You can either use alert.message directly (already localized),
    // or build a message from l10n + payload.

    final message =
        "${AppLocalizations.of(context)!.sosRequestSent}. ${AppLocalizations.of(context)!.cancelSosRequest}";

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.warning_rounded,
      message: message,
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFFB71C1C), size: 25),
          onPressed: () {
            _handleCancelSosRequest(alert);
          },
        ),
      ],
    );
  }

  Future<void> _handleSosRequestAccept(AlertModel alert) async {
    // Confirm modal
    Helpers.showBottomModal(
      context: rootContext,
      page: FullScreenModal(
        icon: Icons.priority_high,
        outerColor: const Color(0xFFFFF4CE),
        innerColor: const Color(0xFFFFC107),
        message: AppLocalizations.of(context)!.confirmNavigateMemberLocation,
        showCloseButton: true,
        bottomActions: [
          // --- YES BUTTON ---
          Container(
            margin: EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: PrimaryButton(
              onPressed: () async {
                // close modal
                Navigator.pop(rootContext);

                final payload = alert.payload;
                print("=== ACCEPT SOS REQUEST ===");
                //final sosSender = payload['sosSender'];
                final sosSender = _getSosSender(payload['sosSender']['phone']);
                print("sosSender => $sosSender");
                final receivers = List<String>.from(payload['receivers']);
                print("receivers => $receivers");
                final updated = await _computeSosMemberComingReceivers(
                  sosSenderPhone: sosSender!['phone'],
                  sosHelperPhone: widget.user.phoneNumber,
                  receivers: receivers,
                );
                print("updated => $updated");
                try {
                  await _orchestrator.acceptSosRequestAndNotify(
                    caseId: alert.caseId,
                    helperAlertId: alert.id,
                    helperPhone: widget.user.phoneNumber,
                    helperName: Helpers.getFirstAndLastName(
                      widget.user.fullName,
                    ),
                    sosSender: sosSender,
                    receivers: updated.toList(),
                  );
                } catch (e) {
                  // Fallback error handling
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to accept SOS request: $e')),
                  );
                }
              },
              child: Text(
                AppLocalizations.of(rootContext)!.yes,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20.0),
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
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSosMemberComingArrived(AlertModel alert) async {
    // Confirm modal
    Helpers.showBottomModal(
      context: rootContext,
      page: FullScreenModal(
        icon: Icons.priority_high,
        outerColor: const Color(0xFFFFF4CE),
        innerColor: const Color(0xFFFFC107),
        message: AppLocalizations.of(context)!.confirmArrivedSosSenderLocation,
        showCloseButton: true,
        bottomActions: [
          // --- YES BUTTON ---
          Container(
            margin: EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: PrimaryButton(
              onPressed: () async {
                // close modal
                Navigator.pop(rootContext);

                final payload = alert.payload;
                print("=== ARRIVED SOS SENDER LOCATION ===");
                final sosSender = _getSosSender(payload['sosSender']['phone']);
                print("sosSender => $sosSender");
                final receivers = List<String>.from(payload['receivers']);
                print("receivers => $receivers");
                final updated = await _computeSosMemberComingArrivedReceivers(
                  sosSenderPhone: sosSender!['phone'],
                  sosHelperPhone: widget.user.phoneNumber,
                  receivers: receivers,
                );
                print("updated => $updated");
                try {
                  await _orchestrator.arriveSosMemberOnTheWayAndNotify(
                    caseId: alert.caseId,
                    helperAlertId: alert.id,
                    helperPhone: widget.user.phoneNumber,
                    helperName: Helpers.getFirstAndLastName(
                      widget.user.fullName,
                    ),
                    sosSender: sosSender,
                    receivers: updated.toList(),
                  );

                  // Success modal
                  Helpers.showBottomModal(
                    context: context,
                    page: FullScreenModal(
                      icon: Icons.check,
                      message: AppLocalizations.of(
                        context,
                      )!.arrivedSosMemberSuccess,
                    ),
                  );
                } catch (e) {
                  // Fallback error handling
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to accept SOS request: $e')),
                  );
                }
              },
              child: Text(
                AppLocalizations.of(rootContext)!.yes,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20.0),
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
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSosMemberComingCancelled(AlertModel alert) async {
    // Confirm modal
    Helpers.showBottomModal(
      context: rootContext,
      page: FullScreenModal(
        icon: Icons.priority_high,
        outerColor: const Color(0xFFFFF4CE),
        innerColor: const Color(0xFFFFC107),
        message: AppLocalizations.of(context)!.confirmCancelSosSenderHelp,
        showCloseButton: true,
        bottomActions: [
          // --- YES BUTTON ---
          Container(
            margin: EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: PrimaryButton(
              onPressed: () async {
                // close modal
                Navigator.pop(rootContext);

                final payload = alert.payload;
                print("=== CANCEL SOS SENDER HELP ===");
                final sosSender = _getSosSender(payload['sosSender']['phone']);
                print("sosSender => $sosSender");
                final receivers = List<String>.from(payload['receivers']);
                print("receivers => $receivers");
                final updated = await _computeSosMemberComingCancelledReceivers(
                  sosSenderPhone: sosSender!['phone'],
                  sosHelperPhone: widget.user.phoneNumber,
                  receivers: receivers,
                );
                print("updated => $updated");
                try {
                  await _orchestrator.cancelSosMemberOnTheWayAndNotify(
                    caseId: alert.caseId,
                    helperAlertId: alert.id,
                    helperPhone: widget.user.phoneNumber,
                    helperName: Helpers.getFirstAndLastName(
                      widget.user.fullName,
                    ),
                    sosSender: sosSender,
                    receivers: updated.toList(),
                  );

                  /// SUCCESS MODAL
                  Helpers.showBottomModal(
                    context: rootContext,
                    page: FullScreenModal(
                      icon: Icons.check,
                      message: AppLocalizations.of(
                        rootContext,
                      )!.cancelSosMemberOnTheWaySuccess,
                    ),
                  );
                } catch (e) {
                  // Fallback error handling
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to accept SOS request: $e')),
                  );
                }
              },
              child: Text(
                AppLocalizations.of(rootContext)!.yes,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20.0),
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
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSendSosRequest() async {
    // determine dialog prompt
    String message =
        "${AppLocalizations.of(context)!.confirmSosRequest}${AppLocalizations.of(context)!.questionMark}";

    // display suitable dialog message
    // ==== SHOW CONFIRM MODAL ====
    Helpers.showBottomModal(
      context: rootContext,
      page: FullScreenModal(
        icon: Icons.priority_high,
        outerColor: const Color(0xFFFFF4CE),
        innerColor: const Color(0xFFFFC107),
        message: message,
        showCloseButton: true,
        bottomActions: [
          // --- YES BUTTON ---
          Container(
            margin: EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: PrimaryButton(
              onPressed: () async {
                // close modal
                Navigator.pop(rootContext);

                try {
                  setState(() {
                    isSosLoading = true;
                  });
                  print("=== SEND SOS REQUEST ===");
                  // reolve any previous SOS closing alert sent by the user
                  await AlertRepository().resolveAlertsForTypesAndSender(
                    senderId: widget.user.phoneNumber,
                    types: [
                      AlertType.sosRequestCancelled,
                      AlertType.sosMemberSafe,
                    ],
                  );
                  // check any visible member available
                  final visibleMembers = context
                      .read<GroupProvider>()
                      .getAllVisibleMembersFor(widget.user.phoneNumber);
                  print("visibleMembers => $visibleMembers");
                  if (visibleMembers.isEmpty) {
                    // if none , then can't send SOS!
                    // FAILURE MODAL
                    Helpers.showBottomModal(
                      context: rootContext,
                      page: FullScreenModal(
                        icon: Icons.close,
                        outerColor: const Color(0xFFFFE6E6),
                        innerColor: const Color(0xFFE53935),
                        message: AppLocalizations.of(
                          rootContext,
                        )!.sosRequestNoVisibleMembers,
                      ),
                    );
                  } else {
                    // get SOS sender info
                    final sosSender = _getSosSender(widget.user.phoneNumber);
                    print("sosSender => $sosSender");
                    // determine receivers
                    final receivers = await _filterOutSosRequestSenders(
                      visibleMembers: visibleMembers.toList(),
                    );
                    print("receivers => $receivers");
                    // send SOS alert to receivers
                    // and send self notification
                    await _orchestrator.sendSosRequestAndNotify(
                      sosSender: sosSender!,
                      receivers: receivers.toList(),
                    );
                  }
                  setState(() {
                    isSosLoading = false;
                  });
                } on AlertException catch (e) {
                  setState(() {
                    isSosLoading = false;
                  });
                  switch (e.code) {
                    case AlertErrorCodes.duplicatePendingAlert:
                      Helpers.showBottomModal(
                        context: context,
                        page: FullScreenModal(
                          icon: Icons.close,
                          outerColor: const Color(0xFFFFE6E6),
                          innerColor: const Color(0xFFE53935),
                          message: AppLocalizations.of(
                            context,
                          )!.sosRequestAlreadySent,
                        ),
                      );
                      break;
                    default:
                      print(e.toString());
                      // FAILURE MODAL
                      Helpers.showBottomModal(
                        context: rootContext,
                        page: FullScreenModal(
                          icon: Icons.close,
                          outerColor: const Color(0xFFFFE6E6),
                          innerColor: const Color(0xFFE53935),
                          message: AppLocalizations.of(
                            rootContext,
                          )!.sosRequestFailed,
                        ),
                      );
                  }
                } catch (e) {
                  setState(() {
                    isSosLoading = false;
                  });
                  print(e.toString());
                  // FAILURE MODAL
                  Helpers.showBottomModal(
                    context: rootContext,
                    page: FullScreenModal(
                      icon: Icons.close,
                      outerColor: const Color(0xFFFFE6E6),
                      innerColor: const Color(0xFFE53935),
                      message: AppLocalizations.of(
                        rootContext,
                      )!.sosRequestFailed,
                    ),
                  );
                }
              },
              child: Text(
                AppLocalizations.of(rootContext)!.yes,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20.0),
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
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancelSosRequest(AlertModel alert) async {
    // Confirm modal
    Helpers.showBottomModal(
      context: rootContext,
      page: FullScreenModal(
        icon: Icons.priority_high,
        outerColor: const Color(0xFFFFF4CE),
        innerColor: const Color(0xFFFFC107),
        message: AppLocalizations.of(context)!.confirmCancelSosRequest,
        showCloseButton: true,
        bottomActions: [
          // --- YES BUTTON ---
          Container(
            margin: EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: PrimaryButton(
              onPressed: () async {
                // close modal
                Navigator.pop(rootContext);

                try {
                  setState(() {
                    isSosLoading = true;
                  });
                  final payload = alert.payload;
                  print("=== CANCEL SOS REQUEST ===");
                  // get visible members of SOS sender
                  final visibleMembers = context
                      .read<GroupProvider>()
                      .getAllVisibleMembersFor(widget.user.phoneNumber);
                  print("visibleMembers => $visibleMembers");
                  // get SOS sender info
                  final sosSender = _getSosSender(widget.user.phoneNumber);
                  print("sosSender => $sosSender");
                  final receivers = List<String>.from(
                    alert.payload['receivers'],
                  );
                  // get helper info
                  final helperPhone = payload['helperPhone'] ?? "";
                  print("helperPhone => $helperPhone");
                  print("receivers => $receivers");
                  final updated = await _computeSosRequestCancelledReceivers(
                    sosSenderPhone: sosSender!['phone'],
                    helperPhone: helperPhone,
                    visibleMembers: visibleMembers.toList(),
                    receivers: receivers,
                  );
                  print("updated => $updated");

                  // Resolve all sos requests previously sent to receivers
                  // Notify receivers with the cancellation
                  await _orchestrator.cancelSosRequestAndNotify(
                    caseId: alert.caseId,
                    sosSender: sosSender,
                    receivers: updated.toList(),
                  );

                  // Success modal
                  /*
                  Helpers.showBottomModal(
                    context: context,
                    page: FullScreenModal(
                      icon: Icons.check,
                      message: AppLocalizations.of(
                        context,
                      )!.cancelSosRequestSuccess,
                    ),
                  );
                  */
                  setState(() {
                    isSosLoading = false;
                  });
                } catch (e) {
                  setState(() {
                    isSosLoading = false;
                  });
                  // Fallback error handling
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to cancel SOS request: $e')),
                  );
                }
              },
              child: Text(
                AppLocalizations.of(rootContext)!.yes,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20.0),
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
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSosMemberSafe(AlertModel alert) async {
    // Confirm modal
    Helpers.showBottomModal(
      context: rootContext,
      page: FullScreenModal(
        icon: Icons.priority_high,
        outerColor: const Color(0xFFFFF4CE),
        innerColor: const Color(0xFFFFC107),
        message: AppLocalizations.of(context)!.confirmYouAreSafe,
        showCloseButton: true,
        bottomActions: [
          // --- YES BUTTON ---
          Container(
            margin: EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: PrimaryButton(
              onPressed: () async {
                // close modal
                Navigator.pop(rootContext);

                try {
                  final payload = alert.payload;
                  print("=== SOS MEMBER IS SAFE ===");
                  // get SOS sender info
                  final sosSender = _getSosSender(widget.user.phoneNumber);
                  print("sosSender => $sosSender");
                  final receivers = List<String>.from(
                    alert.payload['receivers'],
                  );
                  print("receivers => $receivers");
                  final updated = await _computeSosMemberSafeReceivers(
                    sosSenderPhone: widget.user.phoneNumber,
                    receivers: receivers,
                  );
                  print("updated => $updated");

                  // Resolve all sos requests previously sent to receivers
                  // Notify receivers with the safety

                  await _orchestrator.closeSosRequestAndNotify(
                    caseId: alert.caseId,
                    sosSender: sosSender!,
                    receivers: updated.toList(),
                  );

                  // Success modal
                  Helpers.showBottomModal(
                    context: context,
                    page: FullScreenModal(
                      icon: Icons.check,
                      message: AppLocalizations.of(
                        context,
                      )!.sosMemberSafeSuccess,
                    ),
                  );
                } catch (e) {
                  // Fallback error handling
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to cancel SOS request: $e')),
                  );
                }
              },
              child: Text(
                AppLocalizations.of(rootContext)!.yes,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20.0),
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
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSosRequestCancelledAlertBanner(AlertModel alert, bool isArabic) {
    final payload = alert.payload;
    // get SOS sender info
    //final sosSender = payload['sosSender'];
    final sosSender = payload['sosSender'];
    print("sosSender => $sosSender");

    // You can either use alert.message directly (already localized),
    // or build a message from l10n + payload.

    final message = "${AppLocalizations.of(context)!.sosRequestCancelled}.";

    return AppAlert(
      time: Helpers.timeAgo(alert.sentAt, isArabic: true),
      icon: Icons.warning_rounded,
      title: sosSender!['name'],
      message: message,
      borderColor: const Color(0xFFE0D9FC),
      backgroundColor: const Color(0xFFF3F0FF),
      iconColor: const Color(0xFF3C32A3),
      contentColor: const Color(0xFF3C32A3),
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, color: Color(0xFF3C32A3), size: 25),
          onPressed: () {
            _handleAlertDismiss(alert);
          },
        ),
      ],
    );
  }

  Future<void> _handleAlertDismiss(AlertModel alert) async {
    try {
      // Mark this specific alert as opened so the banner disappears
      await context.read<AlertProvider>().markAlertAsOpenedAndResolved(
        alert.id,
      );
    } catch (e) {
      // Fallback error handling
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to dismiss alert: $e')));
    }
  }

  /// Builds the SOS sender info map for any user by phone number.
  /// Pulls the user object (including lastKnownLocation) from UserProvider.
  /// Returns null if the user or their location is not yet available.
  Map<String, dynamic>? _getSosSender(String userPhone) {
    final user = context.read<UserProvider>().getUser(userPhone);

    // User not loaded yet from Firestore
    if (user == null) return null;

    // Location missing (still null in Firestore)
    final loc = user.lastKnownLocation;
    if (loc == null) return null;

    return {
      "name": Helpers.getFirstAndLastName(user.fullName),
      "phone": user.phoneNumber,
      "latitude": loc.latitude,
      "longitude": loc.longitude,
    };
  }

  Future<Set<String>> _filterOutSosRequestSenders({
    required List<String> visibleMembers,
  }) async {
    final receivers = <String>{};

    // Filter out members who are currently in danger
    // i.e. still has PENDING SOS REQUEST SENT
    for (final memberId in visibleMembers) {
      final isSosSender = await AlertRepository().hasAlertTypeWithStatus(
        receiverId: memberId,
        type: AlertType.sosRequestSent,
        status: AlertStatus.pending,
      );
      if (!isSosSender) {
        receivers.add(memberId);
      }
    }

    return receivers;
  }

  Future<Set<String>> _computeSosRequestCancelledReceivers({
    required String sosSenderPhone,
    required String helperPhone,
    required List<String> visibleMembers,
    required List<String> receivers,
  }) async {
    final updated = <String>{};
    if (helperPhone.isNotEmpty) receivers.add(helperPhone);

    // Filter
    for (final receiverId in receivers) {
      // 1) Must still be visible to the SOS sender
      if (!visibleMembers.contains(receiverId)) continue;

      // 2) Filter out members who are currently in danger
      // i.e. still has PENDING SOS REQUEST SENT
      final isSosSender = await AlertRepository().hasAlertTypeWithStatus(
        receiverId: receiverId,
        type: AlertType.sosRequestSent,
        status: AlertStatus.pending,
      );
      if (isSosSender) continue;

      // 3) Must still have a PENDING SOS_REQUEST or SOS_MEMBER_COMING
      final hasPendingSosRequest = await AlertRepository()
          .hasAlertTypeWithStatusAndSender(
            receiverId: receiverId,
            type: AlertType.sosRequest,
            status: AlertStatus.pending,
            senderId: sosSenderPhone,
          );
      final hasPendingSosMemberComingSent = await AlertRepository()
          .hasAlertTypeWithStatusAndPayloadProperty(
            receiverId: receiverId,
            type: AlertType.sosMemberComingSent,
            status: AlertStatus.pending,
            propertyName: "sosSender.phone",
            propertyValue: sosSenderPhone,
          );
      if (hasPendingSosRequest || hasPendingSosMemberComingSent) {
        updated.add(receiverId);
      }
    }

    return updated;
  }

  Future<Set<String>> _computeSosMemberComingReceivers({
    required String sosSenderPhone,
    required String sosHelperPhone,
    required List<String> receivers,
  }) async {
    final updated = <String>{};
    updated.add(sosSenderPhone);

    // 1) Filter
    for (final receiverId in receivers) {
      // 1) Filter out members who are currently in danger
      // i.e. still has PENDING SOS REQUEST SENT
      final isInDanger = await AlertRepository().hasAlertTypeWithStatus(
        receiverId: receiverId,
        type: AlertType.sosRequestSent,
        status: AlertStatus.pending,
      );
      if (isInDanger) continue;

      // 3) Must still have a PENDING SOS_REQUEST or SOS_MEMBER_COMING
      final hasPendingSosRequest = await AlertRepository()
          .hasAlertTypeWithStatusAndSender(
            receiverId: receiverId,
            type: AlertType.sosRequest,
            status: AlertStatus.pending,
            senderId: sosSenderPhone,
          );
      final hasPendingSosMemberComingSent = await AlertRepository()
          .hasAlertTypeWithStatusAndPayloadProperty(
            receiverId: receiverId,
            type: AlertType.sosMemberComingSent,
            status: AlertStatus.pending,
            propertyName: "sosSender.phone",
            propertyValue: sosSenderPhone,
          );

      if (hasPendingSosRequest || hasPendingSosMemberComingSent) {
        updated.add(receiverId);
      }
    }
    updated.remove(sosHelperPhone);

    return updated;
  }

  Future<Set<String>> _computeSosMemberComingArrivedReceivers({
    required String sosSenderPhone,
    required String sosHelperPhone,
    required List<String> receivers,
  }) async {
    final updated = <String>{};
    updated.add(sosSenderPhone);

    // 1) Filter
    for (final receiverId in receivers) {
      // 1) Filter out members who are currently in danger
      // i.e. still has PENDING SOS REQUEST SENT
      final isInDanger = await AlertRepository().hasAlertTypeWithStatus(
        receiverId: receiverId,
        type: AlertType.sosRequestSent,
        status: AlertStatus.pending,
      );
      if (isInDanger) continue;

      // 3) Must still have a PENDING SOS_REQUEST or SOS_MEMBER_COMING
      final hasPendingSosRequest = await AlertRepository()
          .hasAlertTypeWithStatusAndSender(
            receiverId: receiverId,
            type: AlertType.sosRequest,
            status: AlertStatus.pending,
            senderId: sosSenderPhone,
          );
      final hasPendingSosMemberComingSent = await AlertRepository()
          .hasAlertTypeWithStatusAndPayloadProperty(
            receiverId: receiverId,
            type: AlertType.sosMemberComingSent,
            status: AlertStatus.pending,
            propertyName: "sosSender.phone",
            propertyValue: sosSenderPhone,
          );

      if (hasPendingSosRequest || hasPendingSosMemberComingSent) {
        updated.add(receiverId);
      }
    }

    return updated;
  }

  Future<Set<String>> _computeSosMemberComingCancelledReceivers({
    required String sosSenderPhone,
    required String sosHelperPhone,
    required List<String> receivers,
  }) async {
    final updated = <String>{};
    updated.add(sosSenderPhone);

    // 1) Filter
    for (final receiverId in receivers) {
      // 1) Filter out members who are currently in danger
      // i.e. still has PENDING SOS REQUEST SENT
      final isInDanger = await AlertRepository().hasAlertTypeWithStatus(
        receiverId: receiverId,
        type: AlertType.sosRequestSent,
        status: AlertStatus.pending,
      );
      if (isInDanger) continue;

      // 3) Must still have a PENDING SOS_REQUEST or SOS_MEMBER_COMING
      final hasPendingSosRequest = await AlertRepository()
          .hasAlertTypeWithStatusAndSender(
            receiverId: receiverId,
            type: AlertType.sosRequest,
            status: AlertStatus.pending,
            senderId: sosSenderPhone,
          );
      final hasPendingSosMemberComingSent = await AlertRepository()
          .hasAlertTypeWithStatusAndPayloadProperty(
            receiverId: receiverId,
            type: AlertType.sosMemberComingSent,
            status: AlertStatus.pending,
            propertyName: "sosSender.phone",
            propertyValue: sosSenderPhone,
          );

      if (hasPendingSosRequest || hasPendingSosMemberComingSent) {
        updated.add(receiverId);
      }
    }

    return updated;
  }

  Future<Set<String>> _computeSosMemberSafeReceivers({
    required String sosSenderPhone,
    required List<String> receivers,
  }) async {
    final updated = <String>{};

    // 1) Filter
    for (final receiverId in receivers) {
      // 1) Filter out members who are currently in danger
      // i.e. still has PENDING SOS REQUEST SENT
      final isInDanger = await AlertRepository().hasAlertTypeWithStatus(
        receiverId: receiverId,
        type: AlertType.sosRequestSent,
        status: AlertStatus.pending,
      );
      if (isInDanger) continue;

      // 3) Must still have a PENDING SOS_REQUEST or SOS_MEMBER_COMING
      final hasPendingSosRequest = await AlertRepository()
          .hasAlertTypeWithStatusAndSender(
            receiverId: receiverId,
            type: AlertType.sosRequest,
            status: AlertStatus.pending,
            senderId: sosSenderPhone,
          );
      final hasPendingSosMemberComingSent = await AlertRepository()
          .hasAlertTypeWithStatusAndPayloadProperty(
            receiverId: receiverId,
            type: AlertType.sosMemberComingSent,
            status: AlertStatus.pending,
            propertyName: "sosSender.phone",
            propertyValue: sosSenderPhone,
          );

      if (hasPendingSosRequest || hasPendingSosMemberComingSent) {
        updated.add(receiverId);
      }
    }

    return updated;
  }
}
