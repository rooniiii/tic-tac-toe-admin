import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ad_model.dart';
import 'admin_log_service.dart';
import 'input_sanitizer.dart';

/// Create, read, update and delete the game's advertisements.
/// Every change is written to the activity log.
class AdService {
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminLogService _log = AdminLogService();

  CollectionReference<Map<String, dynamic>> get _ads =>
      _firestore.collection('ads');

  /// Newest first, paged with [limit].
  Stream<List<AdModel>> getAds({required int limit}) {
    return _ads
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => AdModel.fromMap(d.id, d.data())).toList());
  }

  /// Validates and cleans the form values. Throws with a readable message.
  Map<String, dynamic> _validated({
    required String title,
    required String message,
    required String imageUrl,
    required int countdownSeconds,
    required bool active,
  }) {
    final cleanTitle =
        InputSanitizer.clean(title, maxLength: AdModel.maxTitleLength);
    final cleanMessage =
        InputSanitizer.clean(message, maxLength: AdModel.maxMessageLength);
    final cleanUrl =
        InputSanitizer.clean(imageUrl, maxLength: AdModel.maxImageUrlLength);

    if (cleanTitle.isEmpty) throw Exception('Title is required.');
    if (cleanUrl.isNotEmpty && !InputSanitizer.isSafeHttpsUrl(cleanUrl)) {
      throw Exception('Image URL must be a valid https:// link.');
    }
    if (countdownSeconds < AdModel.minCountdown ||
        countdownSeconds > AdModel.maxCountdown) {
      throw Exception(
        'Countdown must be ${AdModel.minCountdown}–${AdModel.maxCountdown} seconds.',
      );
    }

    return {
      'title': cleanTitle,
      'message': cleanMessage,
      'imageUrl': cleanUrl,
      'countdownSeconds': countdownSeconds,
      'active': active,
    };
  }

  Future<void> createAd({
    required String title,
    required String message,
    required String imageUrl,
    required int countdownSeconds,
    required bool active,
  }) async {
    final data = _validated(
      title: title,
      message: message,
      imageUrl: imageUrl,
      countdownSeconds: countdownSeconds,
      active: active,
    );
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final ref = await _ads.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });

    await _log.log(
      AdminAction.adCreated,
      targetUid: ref.id,
      targetName: data['title'] as String,
      details: '${data['countdownSeconds']} s countdown, '
          '${active ? 'active' : 'inactive'}',
    );
  }

  Future<void> updateAd(
    AdModel ad, {
    required String title,
    required String message,
    required String imageUrl,
    required int countdownSeconds,
    required bool active,
  }) async {
    final data = _validated(
      title: title,
      message: message,
      imageUrl: imageUrl,
      countdownSeconds: countdownSeconds,
      active: active,
    );

    await _ads.doc(ad.id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
    });

    await _log.log(
      AdminAction.adUpdated,
      targetUid: ad.id,
      targetName: data['title'] as String,
      details: '${data['countdownSeconds']} s countdown, '
          '${active ? 'active' : 'inactive'}',
    );
  }

  Future<void> setActive(AdModel ad, bool active) async {
    await _ads.doc(ad.id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
    });

    await _log.log(
      active ? AdminAction.adActivated : AdminAction.adDeactivated,
      targetUid: ad.id,
      targetName: ad.title,
    );
  }

  Future<void> deleteAd(AdModel ad) async {
    await _ads.doc(ad.id).delete();
    await _log.log(
      AdminAction.adDeleted,
      targetUid: ad.id,
      targetName: ad.title,
    );
  }
}
