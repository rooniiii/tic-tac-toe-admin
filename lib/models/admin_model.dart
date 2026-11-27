import 'package:cloud_firestore/cloud_firestore.dart';

class AdminModel {
  final String uid;
  final String role;
  final String name;
  final String email;
  final DateTime? createdAt;
  final String? createdBy;

  const AdminModel({
    required this.uid,
    required this.role,
    this.name = '',
    this.email = '',
    this.createdAt,
    this.createdBy,
  });

  factory AdminModel.fromMap(String uid, Map<String, dynamic> data) {
    final created = data['createdAt'];

    return AdminModel(
      uid: uid,
      role: data['role']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
      createdBy: data['createdBy']?.toString(),
    );
  }

  /// Best label to show in lists: name, then email, then UID.
  String get displayName {
    if (name.isNotEmpty) return name;
    if (email.isNotEmpty) return email;
    return uid;
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'name': name,
      'email': email,
    };
  }
}
