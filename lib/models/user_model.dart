import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;

  final DateTime? createdAt;
  final DateTime? emailVerifiedAt;
  final DateTime? lastLoginAt;
  final DateTime? updatedAt;

  final bool isBlocked;

  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.createdAt,
    this.emailVerifiedAt,
    this.lastLoginAt,
    this.updatedAt,
    this.isBlocked = false,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
  });

  factory UserModel.fromMap(
      String uid,
      Map<String, dynamic> data,
      ) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String) {
        return DateTime.tryParse(value);
      }

      return null;
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    return UserModel(
      uid: uid,
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',

      createdAt: parseDate(data['createdAt']),
      emailVerifiedAt: parseDate(data['emailVerifiedAt']),
      lastLoginAt: parseDate(data['lastLoginAt']),
      updatedAt: parseDate(data['updatedAt']),

      isBlocked: data['isBlocked'] == true ||
          data['status'] == 'blocked',

      gamesPlayed: parseInt(data['gamesPlayed']),
      wins: parseInt(data['wins']),
      losses: parseInt(data['losses']),
      draws: parseInt(data['draws']),
    );
  }

  double get winRate {
    if (gamesPlayed == 0) return 0;
    return (wins / gamesPlayed) * 100;
  }
}