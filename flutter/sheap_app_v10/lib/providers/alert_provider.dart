import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/alert_model.dart';
import '../repositories/alert_repository.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Provides a reactive list of alerts for the current user
/// and exposes a "top banner alert" for the UI.
///
/// Responsibilities:
/// - Subscribes to Firestore alerts for the current user.
/// - Keeps alerts sorted (newest first).
/// - Exposes the latest unopened alert as the banner alert.
/// - Wraps repository methods such as markAlertAsOpened and
///   updateStatusForCase when needed.
class AlertProvider with ChangeNotifier {
  final AlertRepository _alertRepo;

  AlertProvider({AlertRepository? alertRepository})
    : _alertRepo = alertRepository ?? AlertRepository();

  StreamSubscription<List<AlertModel>>? _alertsSub;
  String? _currentUserId;

  List<AlertModel> _alerts = [];
  List<AlertModel> get alerts => _alerts;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Number of unread alerts.
  ///
  /// Definition:
  /// - isOpened == false
  int get unreadAlertsCount {
    return _alerts.where((alert) {
      return alert.isOpened == false;
    }).length;
  }

  /// The most recent unopened alert for the current user.
  ///
  /// Logic:
  /// - Alerts are kept sorted by sentAt (descending).
  /// - We return the first alert that is not opened yet.
  /// - If all alerts are opened, this returns null.
  AlertModel? get topBannerAlert {
    for (final alert in _alerts) {
      if (!alert.isOpened) {
        return alert;
      }
    }
    return null;
  }

  /// Starts listening for alerts targeted to [userId].
  ///
  /// This should typically be called once after login
  /// or when the current user changes.
  void startListening(String userId) {
    print('🔔 AlertProvider startListening called for userId = $userId');

    FirebaseFirestore.instance
        .collection('alerts')
        .limit(1)
        .snapshots()
        .listen(
          (_) => print("Firestore: snapshot OK"),
          onError: (e) => print("Firestore: snapshot ERROR => $e"),
        );

    if (_currentUserId == userId && _alertsSub != null) {
      print(
        '🔔 AlertProvider Already listening for this user, skipping re-subscribe',
      );
      return;
    }

    // Cancel any existing subscription for previous user
    _alertsSub?.cancel();
    _currentUserId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _alertsSub = _alertRepo
        .getAlertsForUser(userId)
        .listen(
          (list) {
            print(
              '✅ AlertProvider Alerts stream update: got ${list.length} alerts',
            );

            // Ensure alerts are sorted by sentAt descending (newest first)
            list.sort((a, b) => b.sentAt.compareTo(a.sentAt));

            _alerts = list;
            _isLoading = false;
            _errorMessage = null;

            print('🔢 AlertProvider unreadAlertsCount = $unreadAlertsCount');
            notifyListeners();
          },
          onError: (error) {
            _isLoading = false;
            _errorMessage = error.toString();

            print('❌ AlertProvider Alerts stream error: $error');
            notifyListeners();
          },
        );
  }

  /// Stops listening to alerts stream.
  ///
  /// Call this, for example, when the user logs out.
  void stopListening() {
    _alertsSub?.cancel();
    _alertsSub = null;
    _currentUserId = null;
    _alerts = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Marks a single alert as opened both in Firestore and locally.
  ///
  /// - Updates the "isOpened" field in the backend.
  /// - Updates the in-memory list so the UI reacts immediately.
  Future<void> markAlertAsOpened(String alertId) async {
    try {
      await _alertRepo.markAlertAsOpened(alertId);

      final index = _alerts.indexWhere((a) => a.id == alertId);
      if (index != -1) {
        final updated = AlertModel(
          id: _alerts[index].id,
          type: _alerts[index].type,
          message: _alerts[index].message,
          sentAt: _alerts[index].sentAt,
          senderId: _alerts[index].senderId,
          receiverId: _alerts[index].receiverId,
          isOpened: true,
          caseId: _alerts[index].caseId,
          status: _alerts[index].status,
          requiresAction: _alerts[index].requiresAction,
          groupId: _alerts[index].groupId,
          payload: _alerts[index].payload,
        );

        _alerts[index] = updated;
        notifyListeners();
      }
    } catch (e) {
      // You may choose to expose this via errorMessage if needed
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Updates the status of an entire alert case (all alerts with the same caseId).
  ///
  /// This is useful for flows such as:
  /// - Invitation accepted / rejected
  /// - SOS resolved
  Future<void> updateCaseStatus(String caseId, String newStatus) async {
    try {
      await _alertRepo.updateStatusForCase(caseId, newStatus);

      // Update local alerts belonging to that case
      bool changed = false;
      _alerts = _alerts.map((alert) {
        if (alert.caseId == caseId) {
          changed = true;
          return AlertModel(
            id: alert.id,
            type: alert.type,
            message: alert.message,
            sentAt: alert.sentAt,
            senderId: alert.senderId,
            receiverId: alert.receiverId,
            isOpened: alert.isOpened,
            caseId: alert.caseId,
            status: newStatus,
            requiresAction: alert.requiresAction,
            groupId: alert.groupId,
            payload: alert.payload,
          );
        }
        return alert;
      }).toList();

      if (changed) {
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Marks a single alert as opened both in Firestore and locally.
  ///
  /// - Updates the "isOpened" field in the backend.
  /// - Updates the in-memory list so the UI reacts immediately.
  Future<void> markAlertAsOpenedAndResolved(String alertId) async {
    try {
      await _alertRepo.markAlertAsOpenedAndResolved(alertId);

      final index = _alerts.indexWhere((a) => a.id == alertId);
      if (index != -1) {
        final updated = AlertModel(
          id: _alerts[index].id,
          type: _alerts[index].type,
          message: _alerts[index].message,
          sentAt: _alerts[index].sentAt,
          senderId: _alerts[index].senderId,
          receiverId: _alerts[index].receiverId,
          isOpened: _alerts[index].isOpened,
          caseId: _alerts[index].caseId,
          status: _alerts[index].status,
          requiresAction: _alerts[index].requiresAction,
          groupId: _alerts[index].groupId,
          payload: _alerts[index].payload,
        );

        _alerts[index] = updated;
        notifyListeners();
      }
    } catch (e) {
      // You may choose to expose this via errorMessage if needed
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  bool isOnTheWay(String caseId, String helperId) {
    return _alerts.any(
      (a) =>
          a.caseId == caseId &&
          a.senderId == helperId &&
          a.type == AlertType.sosMemberComing &&
          a.status == AlertStatus.pending,
    );
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    super.dispose();
  }
}
