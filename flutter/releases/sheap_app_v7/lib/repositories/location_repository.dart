import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';

class LocationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 2. Get Fixed Locations: Returns a live stream of static places.
  Stream<List<AppLocation>> getFixedLocations() {
    return _firestore.collection('locations').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        // Pass doc.id so we capture "abdulaziz" as the ID
        return AppLocation.fromMap(doc.data(), id: doc.id);
      }).toList();
    });
  }
}
