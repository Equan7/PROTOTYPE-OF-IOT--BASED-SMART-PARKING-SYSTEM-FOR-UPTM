// lib/services/offline_service.dart - COMPLETE UPDATE
import 'dart:async';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  // Simulate Firebase-like operations
  Map<String, dynamic> _database = {};
  
  // 🆕 Stream controllers untuk real-time updates
  final StreamController<Map<String, dynamic>> _spotsController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  final StreamController<Map<String, dynamic>> _reservationsController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Initialize offline service
  Future<void> initialize() async {
    _database = {
      'parking_spots': {
        'spot_1': {
          'status': 'available', 
          'last_updated': DateTime.now().toString(),
          'location': 'Bangunan CS - Zone A'
        },
        'spot_2': {
          'status': 'occupied', 
          'last_updated': DateTime.now().toString(),
          'location': 'Bangunan CS - Zone A'
        },
        'spot_3': {
          'status': 'available', 
          'last_updated': DateTime.now().toString(),
          'location': 'Bangunan CS - Zone B'
        },
        'spot_4': {
          'status': 'available', 
          'last_updated': DateTime.now().toString(),
          'location': 'Bangunan CS - Zone B'
        },
        'spot_5': {
          'status': 'occupied', 
          'last_updated': DateTime.now().toString(),
          'location': 'Bangunan CS - Zone C'
        },
      },
      'reservations': {},
      'users': {
        'AM2408016628': {
          'name': 'Ali Ahmad',
          'email': 'ali@student.uptm.edu.my',
          'phone': '0123456789',
          'vehicle_no': 'ABC123'
        },
        'AM2408016630': {
          'name': 'Siti Sarah', 
          'email': 'siti@student.uptm.edu.my',
          'phone': '0123456790',
          'vehicle_no': 'DEF456'
        }
      }
    };
    
    print("✅ Offline Service Initialized!");
    
    // Start periodic updates untuk simulate real-time
    _startPeriodicUpdates();
  }

  // 🆕 Start periodic updates untuk real-time simulation
  void _startPeriodicUpdates() {
    Timer.periodic(Duration(seconds: 3), (timer) {
      _spotsController.add(getParkingSpots());
    });
  }

  // Update parking spot status
  Future<void> updateParkingStatus(int spotId, String status) async {
    await Future.delayed(Duration(milliseconds: 150)); // Simulate network delay
    
    _database['parking_spots']?['spot_$spotId'] = {
      'status': status,
      'last_updated': DateTime.now().toString(),
      'location': _database['parking_spots']?['spot_$spotId']?['location'] ?? 'Bangunan CS'
    };
    
    // 🆕 Notify listeners about the update
    _spotsController.add(getParkingSpots());
    
    print("✅ Spot $spotId updated to: $status (Offline Mode)");
  }

  // 🆕 Reserve parking spot dengan duration
  Future<void> reserveSpot(int spotId, String studentId, int durationMinutes) async {
    await Future.delayed(Duration(milliseconds: 200));
    
    final reservationId = 'res_${spotId}_${DateTime.now().millisecondsSinceEpoch}';
    final expiryTime = DateTime.now().add(Duration(minutes: durationMinutes));
    
    _database['reservations']?[reservationId] = {
      'spot_id': spotId,
      'student_id': studentId,
      'duration_minutes': durationMinutes,
      'created_at': DateTime.now().toString(),
      'expires_at': expiryTime.toString(),
      'status': 'active'
    };
    
    // Update spot status to reserved
    await updateParkingStatus(spotId, 'reserved');
    
    print("✅ Spot $spotId reserved by $studentId for $durationMinutes minutes");
  }

  // 🆕 Cancel reservation
  Future<void> cancelReservation(int spotId, String studentId) async {
    await Future.delayed(Duration(milliseconds: 150));
    
    // Find and remove reservation
    final reservations = _database['reservations'] ?? {};
    final reservationKey = reservations.entries.firstWhere(
      (entry) => entry.value['spot_id'] == spotId && entry.value['student_id'] == studentId,
      orElse: () => MapEntry('', {})
    ).key;
    
    if (reservationKey.isNotEmpty) {
      _database['reservations']?.remove(reservationKey);
      await updateParkingStatus(spotId, 'available');
      print("✅ Reservation cancelled for spot $spotId");
    }
  }

  // 🆕 Get user reservations
  List<Map<String, dynamic>> getUserReservations(String studentId) {
    final reservations = _database['reservations'] ?? {};
    return reservations.entries
        .where((entry) => entry.value['student_id'] == studentId && entry.value['status'] == 'active')
        .map((entry) => {
          'reservation_id': entry.key,
          ...entry.value
        })
        .toList();
  }

  // 🆕 Check reservation expiry dan auto-release
  void checkAndReleaseExpiredReservations() {
    final now = DateTime.now();
    final reservations = _database['reservations'] ?? {};
    List<String> expiredReservations = [];

    reservations.forEach((key, value) {
      if (value['status'] == 'active') {
        final expiry = DateTime.parse(value['expires_at']);
        if (expiry.isBefore(now)) {
          expiredReservations.add(key);
          // Auto-release the spot
          updateParkingStatus(value['spot_id'], 'available');
          value['status'] = 'expired';
        }
      }
    });

    if (expiredReservations.isNotEmpty) {
      print("🕒 Auto-released ${expiredReservations.length} expired reservations");
    }
  }

  // Get all parking spots
  Map<String, dynamic> getParkingSpots() {
    return _database['parking_spots'] ?? {};
  }

  // 🆕 Enhanced real-time updates dengan stream
  Stream<Map<String, dynamic>> getParkingSpotsStream() {
    return _spotsController.stream;
  }

  // 🆕 Get reservations stream
  Stream<Map<String, dynamic>> getReservationsStream() {
    return _reservationsController.stream;
  }

  // 🆕 Get specific spot data
  Map<String, dynamic>? getSpotData(int spotId) {
    return _database['parking_spots']?['spot_$spotId'];
  }

  // 🆕 Get all spots as list
  List<Map<String, dynamic>> getAllSpots() {
    final spots = _database['parking_spots'] ?? {};
    return spots.entries.map((entry) => {
      'id': int.parse(entry.key.replaceFirst('spot_', '')),
      ...entry.value,
    }).toList();
  }

  // 🆕 Get user data
  Map<String, dynamic>? getUserData(String studentId) {
    return _database['users']?[studentId];
  }

  // 🆕 Get all users
  Map<String, dynamic> getUsers() {
    return _database['users'] ?? {};
  }

  // 🆕 Add new user
  Future<void> addUser(Map<String, dynamic> userData) async {
    await Future.delayed(Duration(milliseconds: 200));
    
    final studentId = userData['student_id'];
    if (studentId != null) {
      _database['users']?[studentId] = {
        'name': userData['name'],
        'email': userData['email'],
        'phone': userData['phone'],
        'vehicle_no': userData['vehicle_no']
      };
      print("✅ User $studentId added to offline database");
    }
  }

  // 🆕 Get spot statistics
  Map<String, int> getSpotStatistics() {
    final spots = _database['parking_spots'] ?? {};
    int available = 0;
    int occupied = 0;
    int reserved = 0;

    spots.forEach((key, value) {
      switch (value['status']) {
        case 'available':
          available++;
          break;
        case 'occupied':
          occupied++;
          break;
        case 'reserved':
          reserved++;
          break;
      }
    });

    return {
      'total': spots.length,
      'available': available,
      'occupied': occupied,
      'reserved': reserved
    };
  }

  // 🆕 Find available spots
  List<int> findAvailableSpots() {
    final spots = _database['parking_spots'] ?? {};
    List<int> availableSpots = [];

    spots.forEach((key, value) {
      if (value['status'] == 'available') {
        final spotId = int.parse(key.replaceFirst('spot_', ''));
        availableSpots.add(spotId);
      }
    });

    return availableSpots;
  }

  // 🆕 Get first available spot
  int? getFirstAvailableSpot() {
    final availableSpots = findAvailableSpots();
    return availableSpots.isNotEmpty ? availableSpots.first : null;
  }

  // 🆕 Reset all spots to available
  Future<void> resetAllSpots() async {
    final spots = _database['parking_spots'] ?? {};
    
    for (final key in spots.keys) {
      _database['parking_spots']?[key]?['status'] = 'available';
      _database['parking_spots']?[key]?['last_updated'] = DateTime.now().toString();
    }
    
    // Clear all active reservations
    final reservations = _database['reservations'] ?? {};
    reservations.forEach((key, value) {
      value['status'] = 'cancelled';
    });
    
    _spotsController.add(getParkingSpots());
    print("✅ All spots reset to available");
  }

  // 🆕 Fill all spots (for testing)
  Future<void> fillAllSpots() async {
    final spots = _database['parking_spots'] ?? {};
    
    for (final key in spots.keys) {
      _database['parking_spots']?[key]?['status'] = 'occupied';
      _database['parking_spots']?[key]?['last_updated'] = DateTime.now().toString();
    }
    
    _spotsController.add(getParkingSpots());
    print("✅ All spots filled (occupied)");
  }

  // 🆕 Get reservation by spot ID
  Map<String, dynamic>? getReservationBySpotId(int spotId) {
    final reservations = _database['reservations'] ?? {};
    
    try {
      return reservations.entries
          .firstWhere((entry) => 
              entry.value['spot_id'] == spotId && 
              entry.value['status'] == 'active')
          .value;
    } catch (e) {
      return null;
    }
  }

  // 🆕 Check if spot is reserved by user
  bool isSpotReservedByUser(int spotId, String studentId) {
    final reservation = getReservationBySpotId(spotId);
    return reservation != null && reservation['student_id'] == studentId;
  }

  // 🆕 Get remaining reservation time
  Duration? getRemainingReservationTime(int spotId) {
    final reservation = getReservationBySpotId(spotId);
    if (reservation == null) return null;
    
    final expiry = DateTime.parse(reservation['expires_at']);
    return expiry.difference(DateTime.now());
  }

  // 🆕 Dispose resources
  void dispose() {
    _spotsController.close();
    _reservationsController.close();
  }
}