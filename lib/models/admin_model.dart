class AdminModel {
  final String uid;
  final String role;

  const AdminModel({
    required this.uid,
    required this.role,
  });

  factory AdminModel.fromMap(String uid, Map<String, dynamic> data) {
    return AdminModel(
      uid: uid,
      role: data['role'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
    };
  }
}