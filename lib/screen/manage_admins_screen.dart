import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';

class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({super.key});

  @override
  State<ManageAdminsScreen> createState() =>
      _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  final AdminService _adminService = AdminService();

  final TextEditingController _uidController =
  TextEditingController();

  final TextEditingController _searchController =
  TextEditingController();

  bool _isAdding = false;
  String? _removingUid;
  String _searchQuery = '';

  static const Color background = Color(0xFF0B0B2B);
  static const Color purple = Color(0xFF7B2FF7);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color pink = Color(0xFFFF2BD6);
  static const Color yellow = Color(0xFFFFD600);
  static const Color cardColor = Color(0xFF171F35);

  Future<void> _addAdmin() async {
    final uid = _uidController.text.trim();

    if (uid.isEmpty) {
      _showMessage('Please enter a Firebase Authentication UID.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _isAdding = true);

    try {
      await _adminService.addAdmin(uid);

      if (!mounted) return;

      _uidController.clear();
      _showMessage('Admin authorization record added.');
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<void> _removeAdmin(String uid, bool isCurrentAdmin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Remove Admin Access?',
            style: TextStyle(color: cyan),
          ),
          content: Text(
            isCurrentAdmin
                ? 'You are removing your own Admin access. '
                'You may be signed out after this action. Continue?'
                : 'This account will lose Admin Panel access. '
                'The Firebase Authentication account itself '
                'will not be deleted.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Remove Access'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _removingUid = uid);

    try {
      await _adminService.removeAdmin(uid);

      if (!mounted) return;

      _showMessage('Admin authorization record removed.');
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _removingUid = null);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: cardColor,
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _adminCard(String uid, bool isCurrentAdmin) {
    final isRemoving = _removingUid == uid;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCurrentAdmin
              ? cyan.withValues(alpha: 0.6)
              : purple.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: isCurrentAdmin
                  ? cyan.withValues(alpha: 0.15)
                  : purple.withValues(alpha: 0.2),
              child: Icon(
                Icons.admin_panel_settings,
                color: isCurrentAdmin ? cyan : pink,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCurrentAdmin
                        ? 'Current Admin'
                        : 'Admin Account',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    uid,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentAdmin
                          ? cyan.withValues(alpha: 0.12)
                          : purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCurrentAdmin ? 'YOU' : 'ADMIN',
                      style: TextStyle(
                        color: isCurrentAdmin ? cyan : pink,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isRemoving)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.redAccent,
                ),
              )
            else
              IconButton(
                tooltip: 'Remove Admin Access',
                onPressed: () => _removeAdmin(
                  uid,
                  isCurrentAdmin,
                ),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _uidController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: cyan,
        title: const Text(
          'Admin Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _adminService.getAdmins(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load Admin records.',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: cyan),
            );
          }

          final admins = snapshot.data?.docs ?? [];
          final currentUid = _adminService.currentAdminUid;

          final filteredAdmins = admins.where((admin) {
            return admin.id.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle(
                'Admin Overview',
                'Manage accounts authorized to access this panel.',
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: cyan.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      color: cyan,
                      size: 35,
                    ),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Text(
                        'Total Admin Accounts',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      admins.length.toString(),
                      style: const TextStyle(
                        color: cyan,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              _sectionTitle(
                'Add New Admin',
                'Enter the UID of an existing Firebase Authentication user.',
              ),
              const SizedBox(height: 13),
              TextField(
                controller: _uidController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter Firebase Authentication UID',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(
                    Icons.fingerprint,
                    color: cyan,
                  ),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: purple.withValues(alpha: 0.4),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: cyan,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isAdding ? null : _addAdmin,
                  icon: _isAdding
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.person_add_alt_1),
                  label: Text(
                    _isAdding ? 'Adding...' : 'Add Admin',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: yellow.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: yellow.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: yellow,
                      size: 19,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'This action adds an Admin authorization '
                            'record in Firestore. It does not create a '
                            'Firebase Authentication account.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _sectionTitle(
                'Existing Admins',
                'View and manage authorized Admin accounts.',
              ),
              const SizedBox(height: 13),
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by Admin UID',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: cyan,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: const Icon(
                      Icons.clear,
                      color: Colors.white70,
                    ),
                  ),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim());
                },
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Admin Accounts',
                    style: TextStyle(
                      color: cyan,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${filteredAdmins.length} found',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredAdmins.isEmpty)
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.person_search,
                        color: pink,
                        size: 38,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No Admin accounts found.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              else
                ...filteredAdmins.map((admin) {
                  final uid = admin.id;

                  return _adminCard(
                    uid,
                    uid == currentUid,
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}