// lib/services/auth_service.dart
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? _currentUser;
  List<User> _users = []; // Simpan users dalam memory

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // Register new user
  Future<bool> register({
    required String name,
    required String email,
    required String studentId,
    required String phone,
    required String vehicleNo,
    required String password,
  }) async {
    await Future.delayed(Duration(seconds: 1)); // Simulate API call

    // Check jika email/studentId sudah wujud
    if (_users.any((user) => user.email == email || user.studentId == studentId)) {
      return false;
    }

    final newUser = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      studentId: studentId,
      phone: phone,
      vehicleNo: vehicleNo,
    );

    _users.add(newUser);
    _currentUser = newUser;
    
    print("✅ User registered: ${newUser.name}");
    return true;
  }

  // Login user
  Future<bool> login(String studentId, String password) async {
    await Future.delayed(Duration(seconds: 1)); // Simulate API call

    final user = _users.firstWhere(
      (user) => user.studentId == studentId,
      orElse: () => User(
        id: '',
        name: '',
        email: '',
        studentId: '',
        phone: '',
        vehicleNo: '',
      ),
    );

    if (user.id.isNotEmpty) {
      _currentUser = user;
      print("✅ User logged in: ${user.name}");
      return true;
    }

    return false;
  }

  // Logout
  void logout() {
    _currentUser = null;
    print("✅ User logged out");
  }

  // Add some demo users
  void addDemoUsers() {
    _users.addAll([
      User(
        id: '1',
        name: 'Ali Ahmad',
        email: 'ali@student.uptm.edu.my',
        studentId: 'AM2408016628',
        phone: '0123456789',
        vehicleNo: 'ABC123',
      ),
      User(
        id: '2', 
        name: 'Siti Sarah',
        email: 'siti@student.uptm.edu.my',
        studentId: 'AM2408016630',
        phone: '0123456790',
        vehicleNo: 'DEF456',
      ),
    ]);
  }
}