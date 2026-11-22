import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import '../widgets/load_more_button.dart';
import '../theme/app_theme.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final UserService _service = UserService();
  final TextEditingController _searchController = TextEditingController();

  String _search = '';

  static const int _pageSize = 25;
  int _limit = _pageSize;
  late Stream<List<UserModel>> _usersStream;
  late Future<UserCounts> _countsFuture;


  @override
  void initState() {
    super.initState();
    _usersStream = _service.getUsers(limit: _limit);
    _countsFuture = _service.getCounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadMore() {
    setState(() {
      _limit += _pageSize;
      _usersStream = _service.getUsers(limit: _limit);
    });
  }

  void _refreshCounts() {
    setState(() => _countsFuture = _service.getCounts());
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _editPlayer(UserModel user) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.name);

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Edit Player',
          style: TextStyle(color: AppTheme.neonCyan, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Display Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                _detail('Email (login)', user.email),
                _detail(
                  'Phone',
                  user.phone.isEmpty ? 'Not provided' : user.phone,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Email and phone are tied to the player\'s login and '
                  'offline profile, so they can only be changed by the '
                  'player.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
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
            child: const Text('SAVE CHANGES'),
          ),
        ],
      ),
    );

    if (save == true) {
      try {
        await _service.updateUserName(
          uid: user.uid,
          name: nameController.text,
          oldName: user.name,
        );
        _message('Player name updated.');
      } catch (e) {
        _message('Update failed: $e');
      }
    }

    nameController.dispose();
  }

  Future<void> _toggleBlock(UserModel user) async {
    final block = !user.isBlocked;
    final name = user.name.isEmpty ? user.email : user.name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          block ? 'Block Player?' : 'Unblock Player?',
          style: const TextStyle(color: AppTheme.neonCyan),
        ),
        content: Text(
          block
              ? '$name will be signed out the next time they open the game '
                  'online, and cannot log in or save game results until '
                  'unblocked.'
              : '$name will be able to log in and play again.',
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
      await _service.setUserBlocked(
        uid: user.uid,
        blocked: block,
        name: name,
      );
      _message(block ? 'Player blocked.' : 'Player unblocked.');
      _refreshCounts();
    } catch (e) {
      _message('Status update failed: $e');
    }
  }

  Future<void> _sendPasswordReset(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Send Password Reset?',
          style: TextStyle(color: AppTheme.neonCyan),
        ),
        content: Text(
          'A password reset link will be emailed to ${user.email}.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('SEND'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.sendPasswordReset(user.email, name: user.name);
      _message('Password reset email sent to ${user.email}.');
    } catch (e) {
      _message('Could not send reset email: $e');
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    var deleteHistory = true;
    final name = user.name.isEmpty ? user.email : user.name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text(
            'Delete Player?',
            style: TextStyle(color: AppTheme.neonPink),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This permanently deletes $name\'s profile, statistics and '
                'bio. It cannot be undone, and they will no longer be able '
                'to log in to the game.',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: deleteHistory,
                activeColor: AppTheme.neonPink,
                onChanged: (v) =>
                    setDialogState(() => deleteHistory = v ?? true),
                title: const Text(
                  'Also delete their game history',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Untick to keep past games in Statistics and Game History.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'To also remove the login itself, delete it in Firebase '
                'console > Authentication (UID shown in the profile).',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
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
                style: TextStyle(color: AppTheme.neonPink),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final games = await _service.deletePlayer(
        uid: user.uid,
        email: user.email,
        name: user.name,
        deleteGameHistory: deleteHistory,
      );
      _refreshCounts();
      _message(
        deleteHistory
            ? 'Player deleted, including $games game records.'
            : 'Player deleted. Game history kept.',
      );
    } catch (e) {
      _message('Delete failed: $e');
    }
  }

  void _showDetails(UserModel user) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Player Profile',
          style: TextStyle(color: AppTheme.neonCyan),
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
          Text(label, style: const TextStyle(color: AppTheme.neonCyan, fontSize: 12)),
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
          color: AppTheme.surface,
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
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: blocked ? AppTheme.neonPink : AppTheme.purple.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: blocked ? AppTheme.neonPink : AppTheme.neonCyan,
                  child: const Icon(Icons.person, color: AppTheme.background),
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
                    color: blocked ? AppTheme.neonPink : AppTheme.neonCyan,
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
                    style: const TextStyle(color: AppTheme.neonCyan, fontSize: 12)),
                Text(
                  'Win rate: ${user.winRate.toStringAsFixed(1)}%',
                  style: const TextStyle(color: AppTheme.neonYellow, fontSize: 12),
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
                  icon: const Icon(Icons.visibility_outlined, color: AppTheme.neonCyan),
                ),
                IconButton(
                  tooltip: 'Edit Player',
                  onPressed: () => _editPlayer(user),
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.neonYellow),
                ),
                IconButton(
                  tooltip: 'Send Password Reset Email',
                  onPressed: () => _sendPasswordReset(user),
                  icon: const Icon(Icons.lock_reset, color: Colors.white70),
                ),
                IconButton(
                  tooltip: blocked ? 'Unblock Player' : 'Block Player',
                  onPressed: () => _toggleBlock(user),
                  icon: Icon(
                    blocked ? Icons.lock_open : Icons.block,
                    color: blocked ? AppTheme.neonCyan : AppTheme.neonPink,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete Player',
                  onPressed: () => _deleteUser(user),
                  icon: const Icon(Icons.delete_outline, color: AppTheme.neonPink),
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.neonCyan,
        title: const Text(
          'USER MANAGEMENT',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load players. Check Firestore permissions.',
                style: TextStyle(color: AppTheme.neonPink),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.neonCyan),
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

          final canLoadMore = allUsers.length >= _limit;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    FutureBuilder<UserCounts>(
                      future: _countsFuture,
                      builder: (context, countSnapshot) {
                        final counts = countSnapshot.data;
                        return Row(
                          children: [
                            _stat('TOTAL', counts?.total ?? 0, AppTheme.neonCyan),
                            const SizedBox(width: 8),
                            _stat('ACTIVE', counts?.active ?? 0, AppTheme.neonYellow),
                            const SizedBox(width: 8),
                            _stat('BLOCKED', counts?.blocked ?? 0, AppTheme.neonPink),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _search = value),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search loaded players: name, email, phone',
                        prefixIcon: const Icon(Icons.search, color: AppTheme.neonCyan),
                        suffixIcon: IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                          icon: const Icon(Icons.clear, color: Colors.white54),
                        ),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: users.isEmpty && !canLoadMore
                    ? Center(
                  child: Text(
                    allUsers.isEmpty
                        ? 'No registered players found.'
                        : 'No matching players found.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: users.length + (canLoadMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == users.length) {
                      return LoadMoreButton(
                        shown: allUsers.length,
                        onPressed: _loadMore,
                        hint: query.isEmpty
                            ? null
                            : 'Search only covers loaded players.',
                      );
                    }
                    return _playerCard(users[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}