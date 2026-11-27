import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import 'admin_log_service.dart';

class UserCounts {
  final int total;
  final int blocked;

  const UserCounts({required this.total, required this.blocked});

  int get active => total - blocked;
}

class UserService {
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminLogService _log = AdminLogService();

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _playerStats =>
      _firestore.collection('player_stats');

  CollectionReference<Map<String, dynamic>> get _leaderboard =>
      _firestore.collection('leaderboard');

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  UserModel _buildUser(
    String uid,
    Map<String, dynamic> userData,
    Map<String, dynamic>? statsData,
  ) {
    final combinedData = <String, dynamic>{
      ...userData,
      'gamesPlayed': _toInt(statsData?['gamesPlayed']),
      'wins': _toInt(statsData?['wins']),
      'losses': _toInt(statsData?['losses']),
      'draws': _toInt(statsData?['draws']),
    };

    return UserModel.fromMap(uid, combinedData);
  }

  /// Newest players first, at most [limit] of them. The screen raises the
  /// limit with "Load more", so only the players shown are read.
  Stream<List<UserModel>> getUsers({required int limit}) {
    return _users
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      final stats = await _statsFor(snapshot.docs.map((d) => d.id).toList());

      return snapshot.docs
          .map((doc) => _buildUser(doc.id, doc.data(), stats[doc.id]))
          .toList();
    });
  }

  // Reads player_stats only for the given players (30 per query).
  Future<Map<String, Map<String, dynamic>>> _statsFor(List<String> uids) async {
    final result = <String, Map<String, dynamic>>{};

    for (var i = 0; i < uids.length; i += 30) {
      final end = i + 30 > uids.length ? uids.length : i + 30;
      final chunk = uids.sublist(i, end);

      final snapshot = await _playerStats
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        result[doc.id] = doc.data();
      }
    }

    return result;
  }

  /// Total and blocked player counts. Count queries are cheap: one read per
  /// 1000 documents.
  Future<UserCounts> getCounts() async {
    final results = await Future.wait([
      _users.count().get(),
      _users.where('isBlocked', isEqualTo: true).count().get(),
    ]);

    return UserCounts(
      total: results[0].count ?? 0,
      blocked: results[1].count ?? 0,
    );
  }

  Future<UserModel?> getUserById(String uid) async {
    final results = await Future.wait([
      _users.doc(uid).get(),
      _playerStats.doc(uid).get(),
    ]);

    final userDoc = results[0];
    final statsDoc = results[1];

    if (!userDoc.exists || userDoc.data() == null) {
      return null;
    }

    return _buildUser(uid, userDoc.data()!, statsDoc.data());
  }

  /// Admins can only change the display name here. Email and phone are
  /// tied to the player's login and their offline profile in the game, so
  /// changing them from the Admin Panel would break the player's sign-in.
  Future<void> updateUserName({
    required String uid,
    required String name,
    String oldName = '',
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw Exception('Name is required.');
    }

    await _users.doc(uid).update({
      'name': cleanName,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Keep the public leaderboard name in step (if the player has an entry).
    final entry = await _leaderboard.doc(uid).get();
    if (entry.exists) {
      await _leaderboard.doc(uid).update({'name': cleanName});
    }

    await _log.log(
      AdminAction.playerRenamed,
      targetUid: uid,
      targetName: cleanName,
      details: oldName.isEmpty ? '' : 'Was "$oldName"',
    );
  }

  /// Blocks or unblocks a player. The game signs a blocked player out right
  /// away, and the Firestore rules reject all writes from them.
  Future<void> setUserBlocked({
    required String uid,
    required bool blocked,
    String name = '',
  }) async {
    final batch = _firestore.batch();

    batch.update(_users.doc(uid), {
      'isBlocked': blocked,
      'status': blocked ? 'blocked' : 'active',
      'blockedAt': blocked ? FieldValue.serverTimestamp() : FieldValue.delete(),
      'blockedBy':
          blocked ? FirebaseAuth.instance.currentUser?.uid : FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Blocked players are hidden from the public leaderboard. Their entry
    // is re-created by the game after they are unblocked and log in again.
    if (blocked) {
      batch.delete(_leaderboard.doc(uid));
    }

    await batch.commit();

    await _log.log(
      blocked ? AdminAction.playerBlocked : AdminAction.playerUnblocked,
      targetUid: uid,
      targetName: name,
    );
  }

  /// Deletes all of a player's data in Firestore: profile, stats, bio,
  /// leaderboard entry and (optionally) game history. A
  /// `deleted_users/{uid}` marker is written so the Firestore rules stop
  /// that login from re-creating a profile.
  ///
  /// The Firebase Authentication login itself cannot be deleted without a
  /// paid plan; the game refuses it because the profile is gone. It can be
  /// removed by hand in Firebase console > Authentication.
  Future<int> deletePlayer({
    required String uid,
    required String email,
    String name = '',
    bool deleteGameHistory = true,
  }) async {
    final batch = _firestore.batch();

    batch.set(_firestore.collection('deleted_users').doc(uid), {
      'email': email,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': FirebaseAuth.instance.currentUser?.uid,
    });
    batch.delete(_users.doc(uid));
    batch.delete(_playerStats.doc(uid));
    batch.delete(_leaderboard.doc(uid));
    batch.delete(_firestore.collection('user_profiles').doc(uid));

    await batch.commit();

    final deletedGames = deleteGameHistory ? await _deleteGameHistory(uid) : 0;

    await _log.log(
      AdminAction.playerDeleted,
      targetUid: uid,
      targetName: name.isNotEmpty ? name : email,
      details: deleteGameHistory
          ? '$email - $deletedGames game records deleted'
          : '$email - game history kept',
    );

    return deletedGames;
  }

  Future<int> _deleteGameHistory(String uid) async {
    const pageSize = 400; // a batch holds at most 500 writes
    var deleted = 0;

    while (true) {
      final page = await _firestore
          .collection('game_history')
          .where('player1Uid', isEqualTo: uid)
          .limit(pageSize)
          .get();

      if (page.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      deleted += page.docs.length;

      if (page.docs.length < pageSize) break;
    }

    return deleted;
  }

  Future<void> sendPasswordReset(String email, {String name = ''}) async {
    if (email.trim().isEmpty) {
      throw Exception('This player has no email address on record.');
    }

    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());

    await _log.log(
      AdminAction.passwordResetSent,
      targetName: name,
      details: 'Player account ${email.trim()}',
    );
  }
}
