import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/member_geofence_model.dart';
import '../repositories/member_geofence_repository.dart';

/// Multi-group geofence provider.
///
/// Responsibilities:
///  - Maintain a live geofence stream per group (0..N groups)
///  - Expose per-group helpers: outside count, member status, loading, error
///
/// Internally it keeps:
///  - Map<groupId, List<MemberGeofence>>   -> latest states
///  - Map<groupId, StreamSubscription>     -> Firestore listeners
///  - Map<groupId, bool>                   -> loading flags
///  - Map<groupId, String?>                -> error messages
///
/// You can:
///  - Start watching a group:   startWatchingGroup(groupId)
///  - Stop watching a group:    stopWatchingGroup(groupId)
///  - Stop all:                 stopAll()
///  - Read data:
///       geofencesFor(groupId)
///       outsideCountFor(groupId)
///       isMemberOutside(groupId, memberId)
///       getMemberGeofence(groupId, memberId)
///       isLoading(groupId), errorFor(groupId)
class MemberGeofenceProvider with ChangeNotifier {
  final MemberGeofenceRepository _repo;

  MemberGeofenceProvider({MemberGeofenceRepository? repository})
    : _repo = repository ?? MemberGeofenceRepository();

  // ---------------------------------------------------------------------------
  // Internal state (per group)
  // ---------------------------------------------------------------------------

  final Map<String, List<MemberGeofence>> _geofencesByGroup = {};
  final Map<String, StreamSubscription<List<MemberGeofence>>> _subs = {};
  final Map<String, bool> _isLoadingByGroup = {};
  final Map<String, String?> _errorByGroup = {};

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  /// Returns all geofence docs for [groupId] (empty list if not loaded).
  List<MemberGeofence> geofencesFor(String groupId) =>
      List.unmodifiable(_geofencesByGroup[groupId] ?? const []);

  /// Returns true while the first snapshot for [groupId] is still loading.
  bool isLoading(String groupId) => _isLoadingByGroup[groupId] ?? false;

  /// Returns the last error message for [groupId], if any.
  String? errorFor(String groupId) => _errorByGroup[groupId];

  /// Returns how many members of [groupId] are currently outside the geofence.
  int outsideCountFor(String groupId) {
    final list = _geofencesByGroup[groupId] ?? const [];
    return list.where((g) => g.isOutsideGeofence).length;
  }

  /// Convenience: is this [memberId] outside the fence in [groupId]?
  bool isMemberOutside(String groupId, String memberId) {
    final list = _geofencesByGroup[groupId] ?? const [];
    try {
      final g = list.firstWhere((m) => m.memberId == memberId);
      return g.isOutsideGeofence;
    } catch (_) {
      // If we have no data for this member yet, treat as safe (inside).
      return false;
    }
  }

  /// Returns the full geofence state for a member in a group, if any.
  MemberGeofence? getMemberGeofence(String groupId, String memberId) {
    final list = _geofencesByGroup[groupId] ?? const [];
    try {
      return list.firstWhere((g) => g.memberId == memberId);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Start watching geofence states for a given [groupId].
  ///
  /// Idempotent: calling this multiple times for the same group
  /// will not create duplicate subscriptions.
  void startWatchingGroup(String groupId) {
    // 1) Already subscribed → no-op
    if (_subs.containsKey(groupId)) return;

    // 2) Initialize state
    _isLoadingByGroup[groupId] = true;
    _errorByGroup[groupId] = null;
    _geofencesByGroup[groupId] = _geofencesByGroup[groupId] ?? [];

    // 3) Attach Firestore listener
    final sub = _repo
        .watchGeofencesForGroup(groupId)
        .listen(
          (list) {
            _geofencesByGroup[groupId] = list;
            _isLoadingByGroup[groupId] = false;
            _errorByGroup[groupId] = null;
            notifyListeners();
          },
          onError: (error) {
            _isLoadingByGroup[groupId] = false;
            _errorByGroup[groupId] = error.toString();
            notifyListeners();
          },
        );

    _subs[groupId] = sub;
  }

  /// Stop watching a single [groupId] and clear its local state.
  void stopWatchingGroup(String groupId) {
    _subs[groupId]?.cancel();
    _subs.remove(groupId);

    _geofencesByGroup.remove(groupId);
    _isLoadingByGroup.remove(groupId);
    _errorByGroup.remove(groupId);

    notifyListeners();
  }

  /// Stop all group listeners and clear everything.
  void stopAll() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    _geofencesByGroup.clear();
    _isLoadingByGroup.clear();
    _errorByGroup.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopAll();
    super.dispose();
  }
}
