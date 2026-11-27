import 'package:cloud_firestore/cloud_firestore.dart';

/// An advertisement shown in the game (Firestore `ads/{id}`).
///
/// The game shows it full-screen with a countdown of [countdownSeconds]
/// (15 by default) before the player can continue: before every 3rd level
/// and as the reward ad for an extra Undo when no AdMob ad is available.
class AdModel {
  static const int maxTitleLength = 60;
  static const int maxMessageLength = 200;
  static const int maxImageUrlLength = 500;
  static const int defaultCountdown = 15;
  static const int minCountdown = 5;
  static const int maxCountdown = 60;

  final String id;
  final String title;
  final String message;
  final String imageUrl;
  final int countdownSeconds;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdModel({
    required this.id,
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.countdownSeconds,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasImage => imageUrl.isNotEmpty;

  factory AdModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? date(dynamic v) => v is Timestamp ? v.toDate() : null;
    final seconds = data['countdownSeconds'];

    return AdModel(
      id: id,
      title: data['title']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      countdownSeconds: seconds is num ? seconds.toInt() : defaultCountdown,
      active: data['active'] == true,
      createdAt: date(data['createdAt']),
      updatedAt: date(data['updatedAt']),
    );
  }
}
