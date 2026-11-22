import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Every action an admin can take that changes data.
enum AdminAction {
  adminCreated('Created admin', Icons.person_add_alt_1, AppTheme.neonCyan),
  adminAdded('Granted admin access', Icons.verified_user, AppTheme.neonCyan),
  adminRemoved('Removed admin access', Icons.person_remove, Colors.redAccent),
  playerBlocked('Blocked player', Icons.block, AppTheme.neonPink),
  playerUnblocked('Unblocked player', Icons.lock_open, Colors.greenAccent),
  playerDeleted('Deleted player', Icons.delete_forever, Colors.redAccent),
  playerRenamed('Renamed player', Icons.edit, AppTheme.neonYellow),
  bioEdited('Edited bio', Icons.edit_note, AppTheme.neonYellow),
  bioDeleted('Deleted bio', Icons.delete_outline, AppTheme.neonPink),
  passwordResetSent('Sent password reset', Icons.lock_reset, Colors.white70);

  final String label;
  final IconData icon;
  final Color color;

  const AdminAction(this.label, this.icon, this.color);

  static AdminAction? fromName(String? name) {
    for (final action in values) {
      if (action.name == name) return action;
    }
    return null;
  }
}

class AdminLogEntry {
  final String id;
  final AdminAction? action;
  final String actionName;
  final String adminUid;
  final String adminEmail;
  final String targetUid;
  final String targetName;
  final String details;
  final DateTime? createdAt;

  const AdminLogEntry({
    required this.id,
    required this.action,
    required this.actionName,
    required this.adminUid,
    required this.adminEmail,
    required this.targetUid,
    required this.targetName,
    required this.details,
    this.createdAt,
  });

  factory AdminLogEntry.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    final actionName = data['action']?.toString() ?? '';

    return AdminLogEntry(
      id: id,
      action: AdminAction.fromName(actionName),
      actionName: actionName,
      adminUid: data['adminUid']?.toString() ?? '',
      adminEmail: data['adminEmail']?.toString() ?? '',
      targetUid: data['targetUid']?.toString() ?? '',
      targetName: data['targetName']?.toString() ?? '',
      details: data['details']?.toString() ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

/// Writes and reads the `admin_logs` collection: who did what, to whom, and
/// when. Entries cannot be edited or deleted (enforced by the rules).
class AdminLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _logs =>
      _firestore.collection('admin_logs');

  /// Records an action. Never throws: a failed log entry must not undo or
  /// block the action itself.
  Future<void> log(
    AdminAction action, {
    String targetUid = '',
    String targetName = '',
    String details = '',
  }) async {
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) return;

    try {
      await _logs.add({
        'action': action.name,
        'adminUid': admin.uid,
        'adminEmail': admin.email ?? '',
        'targetUid': targetUid,
        'targetName': targetName,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Admin log write failed: $e');
    }
  }

  /// Most recent entries first.
  Stream<List<AdminLogEntry>> recent({required int limit}) {
    return _logs
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AdminLogEntry.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }
}

/// Short local time like "22/11 16:41".
String formatLogTime(DateTime time) {
  final t = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}
