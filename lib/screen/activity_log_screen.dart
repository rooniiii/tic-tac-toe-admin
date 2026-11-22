import 'package:flutter/material.dart';

import '../services/admin_log_service.dart';
import '../theme/app_theme.dart';
import '../widgets/load_more_button.dart';

/// Read-only history of everything admins have done.
class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final AdminLogService _logService = AdminLogService();
  final TextEditingController _searchController = TextEditingController();

  static const int _pageSize = 30;
  int _limit = _pageSize;
  late Stream<List<AdminLogEntry>> _logStream;

  String _search = '';
  AdminAction? _filter;

  @override
  void initState() {
    super.initState();
    _logStream = _logService.recent(limit: _limit);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadMore() {
    setState(() {
      _limit += _pageSize;
      _logStream = _logService.recent(limit: _limit);
    });
  }

  bool _matches(AdminLogEntry entry) {
    if (_filter != null && entry.action != _filter) return false;

    final q = _search.toLowerCase();
    if (q.isEmpty) return true;

    return entry.adminEmail.toLowerCase().contains(q) ||
        entry.targetName.toLowerCase().contains(q) ||
        entry.targetUid.toLowerCase().contains(q) ||
        entry.details.toLowerCase().contains(q);
  }

  void _showDetails(AdminLogEntry entry) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppTheme.neonCyan, fontSize: 12),
              ),
              SelectableText(
                value.isEmpty ? '-' : value,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          entry.action?.label ?? entry.actionName,
          style: TextStyle(color: entry.action?.color ?? Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row('When',
                  entry.createdAt == null ? '' : formatLogTime(entry.createdAt!)),
              row('Admin', entry.adminEmail),
              row('Admin UID', entry.adminUid),
              row('Target', entry.targetName),
              row('Target UID', entry.targetUid),
              row('Details', entry.details),
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

  Widget _entryCard(AdminLogEntry entry) {
    final action = entry.action;
    final target =
        entry.targetName.isNotEmpty ? entry.targetName : entry.details;

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _showDetails(entry),
        leading: CircleAvatar(
          backgroundColor:
              (action?.color ?? Colors.white70).withValues(alpha: 0.15),
          child: Icon(
            action?.icon ?? Icons.history,
            color: action?.color ?? Colors.white70,
            size: 20,
          ),
        ),
        title: Text(
          action?.label ?? entry.actionName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          [
            if (target.isNotEmpty) target,
            'by ${entry.adminEmail.isNotEmpty ? entry.adminEmail : entry.adminUid}',
          ].join('\n'),
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        trailing: Text(
          entry.createdAt == null ? '' : formatLogTime(entry.createdAt!),
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        isThreeLine: target.isNotEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.neonCyan,
        title: const Text(
          'Activity Log',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<AdminLogEntry>>(
        stream: _logStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load the activity log. Check Firestore rules.',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.neonCyan),
            );
          }

          final entries = snapshot.data ?? [];
          final filtered = entries.where(_matches).toList();
          final canLoadMore = entries.length >= _limit;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Every change made by an admin is recorded here. '
                'Entries cannot be edited or deleted.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search admin, player or details',
                  prefixIcon:
                      const Icon(Icons.search, color: AppTheme.neonCyan),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _search = '');
                    },
                  ),
                ),
                onChanged: (value) => setState(() => _search = value.trim()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AdminAction?>(
                value: _filter,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Action',
                  prefixIcon:
                      Icon(Icons.filter_list, color: AppTheme.neonCyan),
                ),
                items: [
                  const DropdownMenuItem<AdminAction?>(
                    value: null,
                    child: Text('All actions'),
                  ),
                  ...AdminAction.values.map(
                    (a) => DropdownMenuItem<AdminAction?>(
                      value: a,
                      child: Text(a.label),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      'No matching activity.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              else
                ...filtered.map(_entryCard),
              if (canLoadMore)
                LoadMoreButton(
                  shown: entries.length,
                  onPressed: _loadMore,
                  hint: _search.isEmpty && _filter == null
                      ? null
                      : 'Search and filter only cover loaded entries.',
                ),
            ],
          );
        },
      ),
    );
  }
}
