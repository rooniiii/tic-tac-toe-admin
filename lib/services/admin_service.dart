import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AdminService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    debugPrint('LOGIN UID: $uid');

    try {
      final adminDoc = await _firestore
          .collection('admins')
          .doc(uid)
          .get();

      debugPrint('ADMIN DOCUMENT EXISTS: ${adminDoc.exists}');
      debugPrint('ADMIN DOCUMENT DATA: ${adminDoc.data()}');

      if (!adminDoc.exists ||
          adminDoc.data()?['role'] != 'admin') {
        await _auth.signOut();
        throw Exception('Access denied. You are not an Admin.');
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
  Stream<QuerySnapshot<Map<String, dynamic>>> getAdmins() {
    return _firestore.collection('admins').snapshots();
  }

  // Add a new Admin
  Future<void> addAdmin(String uid) async {
    final cleanUid = uid.trim();

    if (cleanUid.isEmpty) {
      throw Exception('Please enter a valid UID.');
    }

    final doc = _firestore.collection('admins').doc(cleanUid);
    final existing = await doc.get();

    if (existing.exists) {
      throw Exception('This user is already an Admin.');
    }

    await doc.set({'role': 'admin'});
  }

  // Remove an Admin
  Future<void> removeAdmin(String uid) async {
    final admins = await _firestore.collection('admins').get();

    if (admins.docs.length <= 1) {
      throw Exception('The last Admin cannot be removed.');
    }

    await _firestore.collection('admins').doc(uid).delete();

    if (_auth.currentUser?.uid == uid) {
      await _auth.signOut();
    }
  }

  // Current Admin UID
  String? get currentAdminUid => _auth.currentUser?.uid;

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}