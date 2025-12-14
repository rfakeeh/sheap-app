import 'location_model.dart';

class DestinationConfig {
  final AppLocation finalDestination;
  final List<AppLocation> orderedStops; // Empty list = Simple mode

  DestinationConfig({
    required this.finalDestination,
    this.orderedStops = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'finalDestination': finalDestination.toMap(),
      'orderedStops': orderedStops.map((e) => e.toMap()).toList(),
    };
  }

  factory DestinationConfig.fromMap(Map<String, dynamic> map) {
    return DestinationConfig(
      finalDestination: AppLocation.fromMap(map['finalDestination']),
      orderedStops:
          (map['orderedStops'] as List<dynamic>?)
              ?.map((e) => AppLocation.fromMap(e))
              .toList() ??
          [],
    );
  }
}
