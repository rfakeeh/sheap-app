import 'location_model.dart';

/// Represents a static destination configuration for a group.
/// Dynamic (leader-based) destinations are NOT stored in Firestore.
/// Only static locations are saved.
///
/// If a group uses leaderLocation type, its `destinationConfig` will be NULL.
class DestinationConfig {
  /// The final static destination.
  final AppLocation finalDestination;

  /// Optional ordered stops along the route.
  /// Empty list = simple mode (go directly to finalDestination).
  final List<AppLocation> orderedStops;

  const DestinationConfig({
    required this.finalDestination,
    this.orderedStops = const [],
  });

  /// Convert model to Firestore map.
  Map<String, dynamic> toMap() {
    return {
      'finalDestination': finalDestination.toMap(),
      'orderedStops': orderedStops.map((e) => e.toMap()).toList(),
    };
  }

  /// Construct model from Firestore map.
  factory DestinationConfig.fromMap(Map<String, dynamic> map) {
    return DestinationConfig(
      finalDestination: AppLocation.fromMap(
        Map<String, dynamic>.from(map['finalDestination']),
      ),
      orderedStops:
          (map['orderedStops'] as List<dynamic>?)
              ?.map(
                (e) => AppLocation.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          [],
    );
  }
}
