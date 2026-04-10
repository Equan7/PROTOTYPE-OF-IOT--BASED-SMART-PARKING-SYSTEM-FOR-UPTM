// lib/models/parking_model.dart - UPDATED WITH NEW FEATURES
import 'package:flutter/foundation.dart';
import '../services/offline_service.dart';

class ParkingSpot {
  final int id;
  String status;
  final String location;
  String lastUpdated;

  ParkingSpot({
    required this.id,
    required this.status,
    required this.location,
    required this.lastUpdated,
  });
}

class ParkingModel with ChangeNotifier {
  List<ParkingSpot> _parkingSpots = [];
  final OfflineService _offlineService = OfflineService();
  Stream<Map<String, dynamic>>? _spotsStream;

  // 🆕 Reservation system dengan user
  Map<int, String> _reservations = {}; // spotId -> studentId
  Map<int, DateTime> _reservationExpiry = {};
  Map<int, int> _reservationDurations = {}; // spotId -> duration in minutes

  List<ParkingSpot> get parkingSpots => _parkingSpots;
  Map<int, String> get reservations => _reservations;

  int get availableSpots => 
      _parkingSpots.where((spot) => spot.status == 'available').length;

  int get occupiedSpots => 
      _parkingSpots.where((spot) => spot.status == 'occupied').length;

  int get reservedSpots => 
      _parkingSpots.where((spot) => spot.status == 'reserved').length;

  // Initialize dengan offline data
  void initialize() {
    _offlineService.initialize();
    _setupRealtimeListener();
    _loadInitialData();
    _startReservationChecker();
  }

  void _setupRealtimeListener() {
    _spotsStream = _offlineService.getParkingSpotsStream();
    _spotsStream?.listen((data) {
      _updateParkingSpotsFromData(data);
    });
  }

  void _loadInitialData() {
    final data = _offlineService.getParkingSpots();
    _updateParkingSpotsFromData(data);
  }

  void _updateParkingSpotsFromData(Map<String, dynamic> data) {
    List<ParkingSpot> updatedSpots = [];
    
    for (int i = 1; i <= 5; i++) {
      final spotData = data['spot_$i'];
      if (spotData != null) {
        updatedSpots.add(ParkingSpot(
          id: i,
          status: spotData['status'] ?? 'available',
          location: 'Bangunan CS',
          lastUpdated: spotData['last_updated'] ?? '',
        ));
      } else {
        updatedSpots.add(ParkingSpot(
          id: i,
          status: 'available',
          location: 'Bangunan CS',
          lastUpdated: DateTime.now().toString(),
        ));
      }
    }
    
    _parkingSpots = updatedSpots;
    notifyListeners();
  }

  // 🆕 RESERVATION SYSTEM WITH DURATION
  Future<void> reserveSpot(int spotId, String studentId, int durationMinutes) async {
    final expiryTime = DateTime.now().add(Duration(minutes: durationMinutes));
    
    _reservations[spotId] = studentId;
    _reservationExpiry[spotId] = expiryTime;
    _reservationDurations[spotId] = durationMinutes;
    
    await updateSpotStatus(spotId, 'reserved');
    
    print("✅ Spot $spotId reserved by $studentId for $durationMinutes minutes");
    notifyListeners();
  }

  // 🆕 Check if spot is reserved by current user
  bool isReservedByUser(int spotId, String studentId) {
    return _reservations[spotId] == studentId;
  }

  // 🆕 Cancel reservation
  Future<void> cancelReservation(int spotId) async {
    _reservations.remove(spotId);
    _reservationExpiry.remove(spotId);
    _reservationDurations.remove(spotId);
    await updateSpotStatus(spotId, 'available');
    notifyListeners();
  }

  // 🆕 Get remaining reservation time
  String getRemainingTime(int spotId) {
    final expiry = _reservationExpiry[spotId];
    if (expiry == null) return '';
    
    final remaining = expiry.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // 🆕 Get reservation duration
  int getReservationDuration(int spotId) {
    return _reservationDurations[spotId] ?? 0;
  }

  // 🆕 Check if reservation is expired and auto-release
  void _checkReservationExpiry() {
    final now = DateTime.now();
    List<int> expiredSpots = [];

    _reservationExpiry.forEach((spotId, expiryTime) {
      if (expiryTime.isBefore(now)) {
        expiredSpots.add(spotId);
      }
    });

    for (final spotId in expiredSpots) {
      _reservations.remove(spotId);
      _reservationExpiry.remove(spotId);
      _reservationDurations.remove(spotId);
      updateSpotStatus(spotId, 'available');
      print("🕒 Reservation for spot $spotId expired and auto-released");
    }

    if (expiredSpots.isNotEmpty) {
      notifyListeners();
    }
  }

  // 🆕 Start periodic reservation checker
  void _startReservationChecker() {
    // Check every 10 seconds for expired reservations
    Stream.periodic(Duration(seconds: 10)).listen((_) {
      _checkReservationExpiry();
    });
  }

  // 🆕 Get user's active reservations
  List<int> getUserReservations(String studentId) {
    return _reservations.entries
        .where((entry) => entry.value == studentId)
        .map((entry) => entry.key)
        .toList();
  }

  // 🆕 Extend reservation
  Future<void> extendReservation(int spotId, int additionalMinutes) async {
    if (_reservationExpiry.containsKey(spotId)) {
      final newExpiry = _reservationExpiry[spotId]!.add(Duration(minutes: additionalMinutes));
      _reservationExpiry[spotId] = newExpiry;
      _reservationDurations[spotId] = (_reservationDurations[spotId] ?? 0) + additionalMinutes;
      
      notifyListeners();
      print("✅ Reservation for spot $spotId extended by $additionalMinutes minutes");
    }
  }

  // Update spot status
  Future<void> updateSpotStatus(int spotId, String status) async {
    await _offlineService.updateParkingStatus(spotId, status);
    // Data akan auto update melalui stream listener
  }

  // Manual controls untuk testing
  Future<void> markAsOccupied(int spotId) async {
    await updateSpotStatus(spotId, 'occupied');
  }

  Future<void> markAsAvailable(int spotId) async {
    // 🆕 Also remove any reservations when marking as available
    _reservations.remove(spotId);
    _reservationExpiry.remove(spotId);
    _reservationDurations.remove(spotId);
    
    await updateSpotStatus(spotId, 'available');
  }

  // Reset semua spots
  Future<void> resetAllSpots() async {
    // 🆕 Clear all reservations when resetting
    _reservations.clear();
    _reservationExpiry.clear();
    _reservationDurations.clear();
    
    for (int i = 1; i <= 5; i++) {
      await markAsAvailable(i);
    }
  }

  // 🆕 Fill all spots (for testing)
  Future<void> fillAllSpots() async {
    for (int i = 1; i <= 5; i++) {
      await markAsOccupied(i);
    }
  }

  // 🆕 Get spot by ID
  ParkingSpot? getSpotById(int spotId) {
    try {
      return _parkingSpots.firstWhere((spot) => spot.id == spotId);
    } catch (e) {
      return null;
    }
  }

  // 🆕 Check if any spot is available
  bool get hasAvailableSpots => availableSpots > 0;

  // 🆕 Get first available spot
  int? get firstAvailableSpot {
    try {
      return _parkingSpots.firstWhere((spot) => spot.status == 'available').id;
    } catch (e) {
      return null;
    }
  }
}