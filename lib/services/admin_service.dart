import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/admin_model.dart';
import 'admin_log_service.dart';

/// Thrown by [AdminService.createAdmin] when the email already has a
/// login. [playerUid] / [playerName] are set when that login belongs to a
/// registered game player, so the UI can offer to promote that account.
class EmailAlreadyRegisteredException implements Exception {
  final String email;
  final String? playerUid;
  final String? playerName;

  const EmailAlreadyRegisteredException({
    required this.email,
    this.playerUid,
    this.playerName,
  });

  bool get isKnownPlayer => playerUid != null;

  @override
  String toString() => isKnownPlayer
      ? 'This email already belongs to player ${playerName ?? email}.'
      : 'This email already has a login, but it is not a registered '
          'player. Ask the person for their UID and use '
          '"Add existing account by UID".';
}

class AdminService {
  // Name of the secondary Firebase app used to create new logins.
  // Creating a user with the main FirebaseAuth instance would sign the
  // current Admin out and sign in as the new user instead.
  static const String _creatorAppName = 'admin-account-creator';

  /// Longest email address allowed by the email standard (RFC 5321).
  /// The same limit is used in the game and in the Firestore rules.
  static const int maxEmailLength = 254;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminLogService _log = AdminLogService();

  CollectionReference<Map<String, dynamic>> get _admins =>
      _firestore.collection('admins');

  // Verify Admin login
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    try {
      final adminDoc = await _admins.doc(uid).get();

      if (!adminDoc.exists || adminDoc.data()?['role'] != 'admin') {
        await _auth.signOut();
        throw Exception('Access denied. You are not an Admin.');
      }

      // Fill in name/email on older admin records that only had a role.
      // Best effort: a failure here must not block the login.
      final data = adminDoc.data() ?? {};
      if ((data['email'] ?? '').toString().isEmpty) {
        try {
          await _admins.doc(uid).set({
            'email': credential.user!.email ?? email.trim().toLowerCase(),
            if ((data['name'] ?? '').toString().isEmpty)
              'name': credential.user!.displayName ?? '',
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Could not update admin record details: $e');
        }
      }

      return credential;
    } catch (e) {
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
      rethrow;
    }
  }

  // Get all Admins
  Stream<List<AdminModel>> getAdmins() {
    return _admins.snapshots().map((snapshot) {
      final admins = snapshot.docs
          .map((doc) => AdminModel.fromMap(doc.id, doc.data()))
          .toList();

      admins.sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
      );

      return admins;
    });
  }

  Future<FirebaseAuth> _creatorAuth() async {
    FirebaseApp app;

    final existing =
        Firebase.apps.where((a) => a.name == _creatorAppName).toList();

    if (existing.isNotEmpty) {
      app = existing.first;
    } else {
      app = await Firebase.initializeApp(
        name: _creatorAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    return FirebaseAuth.instanceFor(app: app);
  }

  /// Creates a brand-new login (email + password) and grants it Admin access.
  /// The current Admin stays signed in.
  Future<String> createAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();

    if (cleanName.isEmpty || cleanEmail.isEmpty) {
      throw Exception('Name and email are required.');
    }

    if (cleanEmail.length > maxEmailLength) {
      throw Exception('Email must be at most $maxEmailLength characters.');
    }

    if (password.length < 8) {
      throw Exception('Password must be at least 8 characters.');
    }

    final creatorAuth = await _creatorAuth();
    User? newUser;

    try {
      final credential = await creatorAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      newUser = credential.user;

      if (newUser == null) {
        throw Exception('The login could not be created.');
      }

      await newUser.updateDisplayName(cleanName);

      // Written with the CURRENT Admin's session, which the rules allow.
      await _admins.doc(newUser.uid).set({
        'role': 'admin',
        'name': cleanName,
        'email': cleanEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid,
      });

      await _log.log(
        AdminAction.adminCreated,
        targetUid: newUser.uid,
        targetName: cleanName,
        details: cleanEmail,
      );

      return newUser.uid;
    } on FirebaseAuthException catch (e) {
      await _rollBack(newUser);

      if (e.code == 'email-already-in-use') {
        throw await _alreadyRegistered(cleanEmail);
      }

      throw Exception(_authError(e.code));
    } catch (e) {
      await _rollBack(newUser);
      rethrow;
    } finally {
      try {
        await creatorAuth.signOut();
      } catch (_) {}
    }
  }

  // The login was created but a later step failed: delete the login so the
  // email can be used again on the next attempt.
  Future<void> _rollBack(User? newUser) async {
    if (newUser == null) return;

    try {
      await newUser.delete();
    } catch (e) {
      debugPrint('Could not roll back new admin login: $e');
    }
  }

  Future<EmailAlreadyRegisteredException> _alreadyRegistered(
    String email,
  ) async {
    try {
      final players = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (players.docs.isNotEmpty) {
        final doc = players.docs.first;
        return EmailAlreadyRegisteredException(
          email: email,
          playerUid: doc.id,
          playerName: doc.data()['name']?.toString(),
        );
      }
    } catch (e) {
      debugPrint('Player lookup failed: $e');
    }

    return EmailAlreadyRegisteredException(email: email);
  }

  /// Grants Admin access to an account that already has a login.
  Future<void> addAdmin(
    String uid, {
    String name = '',
    String email = '',
  }) async {
    final cleanUid = uid.trim();

    if (cleanUid.isEmpty) {
      throw Exception('Please enter a valid UID.');
    }

    final doc = _admins.doc(cleanUid);
    final existing = await doc.get();

    if (existing.exists) {
      throw Exception('This account is already an Admin.');
    }

    var cleanName = name.trim();
    var cleanEmail = email.trim().toLowerCase();

    // If the UID belongs to a player, copy their name and email.
    if (cleanName.isEmpty || cleanEmail.isEmpty) {
      try {
        final player =
            await _firestore.collection('users').doc(cleanUid).get();
        final data = player.data();
        if (data != null) {
          if (cleanName.isEmpty) cleanName = data['name']?.toString() ?? '';
          if (cleanEmail.isEmpty) {
            cleanEmail = data['email']?.toString() ?? '';
          }
        }
      } catch (_) {}
    }

    await doc.set({
      'role': 'admin',
      'name': cleanName,
      'email': cleanEmail,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _auth.currentUser?.uid,
    });

    await _log.log(
      AdminAction.adminAdded,
      targetUid: cleanUid,
      targetName: cleanName,
      details: cleanEmail,
    );
  }

  // Remove an Admin (their login is kept; it just loses Admin access)
  Future<void> removeAdmin(String uid) async {
    final admins = await _admins.get();

    if (admins.docs.length <= 1) {
      throw Exception('The last Admin cannot be removed.');
    }

    final removed = admins.docs.where((d) => d.id == uid).toList();
    final removedData = removed.isEmpty ? null : removed.first.data();

    await _admins.doc(uid).delete();

    await _log.log(
      AdminAction.adminRemoved,
      targetUid: uid,
      targetName: removedData?['name']?.toString() ?? '',
      details: removedData?['email']?.toString() ?? '',
    );

    if (_auth.currentUser?.uid == uid) {
      await _auth.signOut();
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final cleanEmail = email.trim();

    if (cleanEmail.isEmpty) {
      throw Exception('This account has no email address on record.');
    }

    try {
      await _auth.sendPasswordResetEmail(email: cleanEmail);
      await _log.log(
        AdminAction.passwordResetSent,
        details: 'Admin account $cleanEmail',
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_authError(e.code));
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet.';
      case 'user-not-found':
        return 'No login exists for this email.';
      default:
        return 'Firebase error: $code';
    }
  }

  // Current Admin UID
  String? get currentAdminUid => _auth.currentUser?.uid;

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}
