import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProfilesScreen extends StatelessWidget {
  ProfilesScreen({super.key});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color background = Color(0xFF0B1020);
  static const Color cardColor = Color(0xFF171F35);
  static const Color cyan = Colors.cyanAccent;
  static const Color purple = Color(0xFF7B2FF7);

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().split('.').first;
    }

    if (value is DateTime) {
      return value.toLocal().toString().split('.').first;
    }

    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Player Profiles'),
        backgroundColor: cardColor,
        foregroundColor: cyan,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('user_profiles').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load player profiles.',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: cyan),
            );
          }

          final profiles = snapshot.data?.docs ?? [];

          if (profiles.isEmpty) {
            return const Center(
              child: Text(
                'No player profiles found.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final document = profiles[index];
              final profile = document.data();

              final uid = profile['uid']?.toString().isNotEmpty == true
                  ? profile['uid'].toString()
                  : document.id;

              return _ProfileCard(
                key: ValueKey(document.id),
                uid: uid,
                profile: profile,
                profileRef: document.reference,
                firestore: _firestore,
                formatDate: _formatDate,
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> profile;
  final DocumentReference<Map<String, dynamic>> profileRef;
  final FirebaseFirestore firestore;
  final String Function(dynamic) formatDate;

  const _ProfileCard({
    super.key,
    required this.uid,
    required this.profile,
    required this.profileRef,
    required this.firestore,
    required this.formatDate,
  });

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  static const Color cyan = Colors.cyanAccent;
  static const Color cardColor = Color(0xFF171F35);
  static const Color purple = Color(0xFF7B2FF7);

  late final TextEditingController _bioController;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _confirmDelete = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(
      text: widget.profile['bio']?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _ProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_isEditing &&
        oldWidget.profile['bio'] != widget.profile['bio']) {
      _bioController.text = widget.profile['bio']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _detail(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: cyan,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBio() async {
    final newBio = _bioController.text.trim();

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.profileRef.update({
        'bio': newBio,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _isEditing = false;
        _confirmDelete = false;
      });

      _message('Bio updated successfully.');
    } catch (error) {
      _message('Unable to update bio: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteBio() async {
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await widget.profileRef.update({
        'bio': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _bioController.clear();

      setState(() {
        _isEditing = false;
        _confirmDelete = false;
      });

      _message('Bio deleted successfully.');
    } catch (error) {
      _message('Unable to delete bio: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Widget _bioSection(String bio) {
    if (_isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Bio',
            style: TextStyle(color: cyan, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 200,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter player bio',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: cyan),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: purple),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveBio,
                  child: _isSaving
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('Save Bio'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                    setState(() {
                      _bioController.text = bio;
                      _isEditing = false;
                    });
                  },
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detail(
          'Bio',
          bio.isEmpty ? 'No bio added' : bio,
        ),
        if (_confirmDelete)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delete only this bio?',
                  style: TextStyle(color: Colors.redAccent),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _isDeleting
                          ? null
                          : () {
                        setState(() {
                          _confirmDelete = false;
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: _isDeleting ? null : _deleteBio,
                      child: const Text(
                        'Confirm Delete',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                    _confirmDelete = false;
                  });
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Bio'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cyan,
                  side: const BorderSide(color: cyan),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: bio.isEmpty
                    ? null
                    : () {
                  setState(() {
                    _confirmDelete = true;
                  });
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete Bio'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bio = widget.profile['bio']?.toString() ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.firestore
          .collection('users')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data();

        final phone = userData?['phone']?.toString() ?? '';
        final updatedAt =
            userData?['updatedAt'] ?? widget.profile['updatedAt'];

        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.account_circle,
                      color: cyan,
                      size: 30,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Player Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _detail('UID', widget.uid),
                _detail(
                  'Phone',
                  userSnapshot.hasError
                      ? 'Unable to load phone'
                      : userSnapshot.connectionState ==
                      ConnectionState.waiting &&
                      !userSnapshot.hasData
                      ? 'Loading...'
                      : phone.isEmpty
                      ? 'Not provided'
                      : phone,
                ),
                _bioSection(bio),
                const SizedBox(height: 8),
                _detail(
                  'Last Updated',
                  widget.formatDate(updatedAt),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}