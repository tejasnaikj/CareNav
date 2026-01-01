import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String phone;
  final String userType;
  final bool isActive;
  final String? specialization;
  final String? department;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.userType,
    required this.isActive,
    this.specialization,
    this.department,
    required this.createdAt,
  });

  factory User.fromMap(Map<String, dynamic> data) {
    return User(
      id: data['id'] ?? '',
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      phone: data['phone'] ?? '',
      userType: data['userType'] ?? 'patient',
      isActive: data['isActive'] ?? true,
      specialization: data['specialization'],
      department: data['department'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'userType': userType,
      'isActive': isActive,
      'specialization': specialization,
      'department': department,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
