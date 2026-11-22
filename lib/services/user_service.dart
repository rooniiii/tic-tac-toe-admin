import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _playerStats =>
      _firestore.collection('player_stats');

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

  Stream<List<UserModel>> getUsers() {
    late StreamController<List<UserModel>> controller;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? usersSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? statsSub;

    QuerySnapshot<Map<String, dynamic>>? latestUsers;
    QuerySnapshot<Map<String, dynamic>>? latestStats;

    var usersLoaded = false;
    var statsLoaded = false;

    void emitUsers() {
      if (!usersLoaded || !statsLoaded || controller.isClosed) return;

      final statsByUid = <String, Map<String, dynamic>>{};

      for (final doc in latestStats!.docs) {
        statsByUid[doc.id] = doc.data();
      }

      final result = latestUsers!.docs.map((doc) {
        return _buildUser(
          doc.id,
          doc.data(),
          statsByUid[doc.id],
        );
      }).toList();

      controller.add(result);
    }

    controller = StreamController<List<UserModel>>(
      onListen: () {
        usersSub = _users.snapshots().listen(
              (snapshot) {
            latestUsers = snapshot;
            usersLoaded = true;
            emitUsers();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );

        statsSub = _playerStats.snapshots().listen(
              (snapshot) {
            latestStats = snapshot;
            statsLoaded = true;
            emitUsers();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );
      },
      onCancel: () async {
        await usersSub?.cancel();
        await statsSub?.cancel();
      },
    );

    return controller.stream;
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

    return _buildUser(
      uid,
      userDoc.data()!,
      statsDoc.data(),
    );
  }

  Future<void> addUser({
    required String uid,
    required String name,
    required String email,
    required String phone,
  }) async {
    final cleanUid = uid.trim();
    final cleanName = name.trim();
    final cleanEmail = email.trim();

    if (cleanUid.isEmpty || cleanName.isEmpty || cleanEmail.isEmpty) {
      throw Exception('UID, name and email are required.');
    }

    final existingUser = await _users.doc(cleanUid).get();

    if (existingUser.exists) {
      throw Exception('A player with this UID already exists.');
    }

    await _users.doc(cleanUid).set({
      'name': cleanName,
      'email': cleanEmail,
      'phone': phone.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'emailVerifiedAt': null,
      'lastLoginAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'isBlocked': false,
      'status': 'active',
      'gamesPlayed': 0,
      'wins': 0,
      'losses': 0,
      'draws': 0,
    });
  }

  Future<void> updateUser({
    required String uid,
    required String name,
    required String email,
    required String phone,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim();

    if (cleanName.isEmpty || cleanEmail.isEmpty) {
      throw Exception('Name and email are required.');
    }

    await _users.doc(uid).update({
      'name': cleanName,
      'email': cleanEmail,
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setUserBlocked({
    required String uid,
    required bool blocked,
  }) async {
    await _users.doc(uid).update({
      'isBlocked': blocked,
      'status': blocked ? 'blocked' : 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUserRecord(String uid) async {
    await _users.doc(uid).delete();
  }
}