import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final UserService _service = UserService();
  final TextEditingController _searchController = TextEditingController();

  String _search = '';

  static const Color background = Color(0xFF0B0B2B);
  static const Color surface = Color(0xFF171F35);
  static const Color purple = Color(0xFF7B2FF7);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color pink = Color(0xFFFF2BD6);
  static const Color yellow = Color(0xFFFFD600);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showUserForm({UserModel? user}) async {
    final isEditing = user != null;
    final formKey = GlobalKey<FormState>();

    final uidController = TextEditingController(text: user?.uid ?? '');
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        title: Text(
          isEditing ? 'Edit Player' : 'Add Player Profile',
          style: const TextStyle(
            color: cyan,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isEditing) ...[
                  TextFormField(
                    controller: uidController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Firebase User UID',
                      hintText: 'Enter existing Auth UID',
                    ),
                    validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'UID is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                  ),
                ),
                if (!isEditing) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'This creates a Firestore profile only. It does not create a Firebase Authentication account.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(isEditing ? 'SAVE CHANGES' : 'ADD PROFILE'),
          ),
        ],
      ),
    );

    if (save == true) {
      try {
        if (isEditing) {
          await _service.updateUser(
            uid: user.uid,
            name: nameController.text,
            email: emailController.text,
            phone: phoneController.text,
          );
          _message('Player profile updated successfully.');
        } else {
          await _service.addUser(
            uid: uidController.text,
            name: nameController.text,
            email: emailController.text,
            phone: phoneController.text,
          );
          _message('Player profile added successfully.');
        }
      } catch (e) {
        _message('Operation failed: $e');
      }
    }

    uidController.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
  }

  Future<void> _toggleBlock(UserModel user) async {
    final block = !user.isBlocked;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        title: Text(
          block ? 'Block Player?' : 'Unblock Player?',
          style: const TextStyle(color: cyan),
        ),
        content: Text(
          block
              ? 'Mark ${user.name} as blocked?'
              : 'Mark ${user.name} as active?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(block ? 'BLOCK' : 'UNBLOCK'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.setUserBlocked(uid: user.uid, blocked: block);
      _message(block ? 'Player marked as blocked.' : 'Player marked as active.');
    } catch (e) {
      _message('Status update failed: $e');
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        title: const Text(
          'Delete Player Record?',
          style: TextStyle(color: pink),
        ),
        content: Text(
          'This deletes only the Firestore profile for ${user.name}. '
              'The Firebase Authentication account will remain.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: pink),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteUserRecord(user.uid);
      _message('Firestore profile deleted.');
    } catch (e) {
      _message('Delete failed: $e');
    }
  }

  void _showDetails(UserModel user) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        title: const Text(
          'Player Profile',
          style: TextStyle(color: cyan),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detail('Name', user.name),
              _detail('Email', user.email),
              _detail('Phone', user.phone.isEmpty ? 'Not provided' : user.phone),
              _detail('UID', user.uid),
              _detail('Registered', _date(user.createdAt)),
              _detail('Email Verified', _date(user.emailVerifiedAt)),
              _detail('Last Login', _date(user.lastLoginAt)),
              _detail('Status', user.isBlocked ? 'Blocked' : 'Active'),
              const Divider(color: Colors.white24),
              _detail('Games Played', '${user.gamesPlayed}'),
              _detail('Wins', '${user.wins}'),
              _detail('Losses', '${user.losses}'),
              _detail('Draws', '${user.draws}'),
              _detail('Win Rate', '${user.winRate.toStringAsFixed(1)}%'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  String _date(DateTime? date) {
    if (date == null) return 'Not available';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: cyan, fontSize: 12)),
          SelectableText(
            value,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _stat(String title, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 23,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerCard(UserModel user) {
    final blocked = user.isBlocked;

    return Card(
      color: surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: blocked ? pink : purple.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: blocked ? pink : cyan,
                  child: const Icon(Icons.person, color: background),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? 'Unnamed Player' : user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  blocked ? 'BLOCKED' : 'ACTIVE',
                  style: TextStyle(
                    color: blocked ? pink : cyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Games: ${user.gamesPlayed}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text('Wins: ${user.wins}',
                    style: const TextStyle(color: cyan, fontSize: 12)),
                Text(
                  'Win rate: ${user.winRate.toStringAsFixed(1)}%',
                  style: const TextStyle(color: yellow, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                IconButton(
                  tooltip: 'View Profile',
                  onPressed: () => _showDetails(user),
                  icon: const Icon(Icons.visibility_outlined, color: cyan),
                ),
                IconButton(
                  tooltip: 'Edit Player',
                  onPressed: () => _showUserForm(user: user),
                  icon: const Icon(Icons.edit_outlined, color: yellow),
                ),
                IconButton(
                  tooltip: blocked ? 'Unblock Player' : 'Block Player',
                  onPressed: () => _toggleBlock(user),
                  icon: Icon(
                    blocked ? Icons.lock_open : Icons.block,
                    color: blocked ? cyan : pink,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete Firestore Record',
                  onPressed: () => _deleteUser(user),
                  icon: const Icon(Icons.delete_outline, color: pink),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: cyan,
        title: const Text(
          'USER MANAGEMENT',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Add Player Profile',
            onPressed: () => _showUserForm(),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        onPressed: () => _showUserForm(),
        icon: const Icon(Icons.add),
        label: const Text('ADD PLAYER'),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: _service.getUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load players. Check Firestore permissions.',
                style: TextStyle(color: pink),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: cyan),
            );
          }

          final allUsers = snapshot.data ?? [];
          final query = _search.toLowerCase().trim();

          final users = allUsers.where((user) {
            return user.name.toLowerCase().contains(query) ||
                user.email.toLowerCase().contains(query) ||
                user.uid.toLowerCase().contains(query) ||
                user.phone.toLowerCase().contains(query);
          }).toList();

          final active = allUsers.where((u) => !u.isBlocked).length;
          final blocked = allUsers.where((u) => u.isBlocked).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _stat('TOTAL', allUsers.length, cyan),
                        const SizedBox(width: 8),
                        _stat('ACTIVE', active, yellow),
                        const SizedBox(width: 8),
                        _stat('BLOCKED', blocked, pink),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _search = value),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search name, email, phone or UID',
                        prefixIcon: const Icon(Icons.search, color: cyan),
                        suffixIcon: IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                          icon: const Icon(Icons.clear, color: Colors.white54),
                        ),
                        filled: true,
                        fillColor: surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: users.isEmpty
                    ? Center(
                  child: Text(
                    allUsers.isEmpty
                        ? 'No registered players found.'
                        : 'No matching players found.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: users.length,
                  itemBuilder: (context, index) =>
                      _playerCard(users[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}