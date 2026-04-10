// lib/services/firebase_service.dart - FIXED FOR WEB
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../firebase_options.dart'; // 🆕 IMPORT INI

class FirebaseService {
  static late DatabaseReference _databaseRef;

  // Initialize Firebase - FIXED VERSION
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, // 🆕 GUNA OPTIONS
    );
    _databaseRef = FirebaseDatabase.instance.ref();
    print("✅ Firebase Service Initialized Successfully!");
  }

  // Get database reference
  static DatabaseReference get databaseRef => _databaseRef;

  // Write parking spot status
  static Future<void> updateParkingStatus(int spotId, String status) async {
    try {
      await _databaseRef.child('parking_spots/spot_$spotId/status').set(status);
      await _databaseRef.child('parking_spots/spot_$spotId/last_updated')
          .set(DateTime.now().toString());
      print("✅ Spot $spotId updated to: $status");
    } catch (e) {
      print("❌ Error updating spot $spotId: $e");
    }
  }

  // Read all parking spots
  static DatabaseReference getParkingSpotsRef() {
    return _databaseRef.child('parking_spots');
  }
}