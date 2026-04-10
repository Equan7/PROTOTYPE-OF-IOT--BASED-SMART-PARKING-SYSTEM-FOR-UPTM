// lib/models/user_model.dart
class User {
  final String id;
  final String name;
  final String email;
  final String studentId;
  final String phone;
  final String vehicleNo;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.studentId,
    required this.phone,
    required this.vehicleNo,
  });

  // Convert to Map untuk simpan
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'studentId': studentId,
      'phone': phone,
      'vehicleNo': vehicleNo,
    };
  }

  // Create from Map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      studentId: map['studentId'] ?? '',
      phone: map['phone'] ?? '',
      vehicleNo: map['vehicleNo'] ?? '',
    );
  }
}