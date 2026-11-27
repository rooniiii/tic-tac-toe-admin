import 'package:flutter/material.dart';

import '../services/admin_log_service.dart';
import '../services/admin_service.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const DashboardScreen({
    super.key,
    required this.onLogout,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final StatsService _statsService = StatsService();
  final AdminService _adminService = AdminService();
  final AdminLogService _logService = AdminLogService();

  late Future<OverviewStats> _overviewFuture;
  late final Stream<List<AdminLogEntry>> _recentLogs;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _statsService.getOverview();
    _recentLogs = _logService.recent(limit: 5);
  }

  Future<void> _refresh() async {
    final future = _statsService.getOverview();

    setState(() {
      _overviewFuture = future;
    });

    await future;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text(
            'Confirm Logout',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: AppTheme.neonCyan),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'LOGOUT',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    await _adminService.logout();

    if (!context.mounted) return;
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'NEON XO ADMIN',
          style: TextStyle(
            color: AppTheme.neonCyan,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.neonCyan,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Dashboard Overview',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Totals from Firebase. Pull down or tap refresh to update.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 25),
            FutureBuilder<OverviewStats>(
              future: _overviewFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Unable to load dashboard data:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.neonCyan,
                      ),
                    ),
                  );
                }

                final stats = snapshot.data!;

                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.1,
                  children: [
                    _statCard('Total Players', stats.totalPlayers,
                        Icons.people, AppTheme.neonCyan),
                    _statCard('Blocked Players', stats.blockedPlayers,
                        Icons.block, AppTheme.neonPink),
                    _statCard('Total Games', stats.totalGames,
                        Icons.sports_esports, Colors.purpleAccent),
                    _statCard('Total Wins', stats.totalWins,
                        Icons.emoji_events, Colors.greenAccent),
                    _statCard('Total Losses', stats.totalLosses,
                        Icons.trending_down, Colors.redAccent),
                    _statCard('Total Draws', stats.totalDraws,
                        Icons.handshake, Colors.orangeAccent),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            const Text(
              'Recent Admin Activity',
              style: TextStyle(
                color: AppTheme.neonCyan,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<AdminLogEntry>>(
              stream: _recentLogs,
              builder: (context, snapshot) {
                final entries = snapshot.data ?? const [];

                if (snapshot.hasError) {
                  return const Text(
                    'Unable to load activity.',
                    style: TextStyle(color: Colors.redAccent),
                  );
                }

                if (entries.isEmpty) {
                  return const Text(
                    'No admin actions recorded yet.',
                    style: TextStyle(color: Colors.white54),
                  );
                }

                return Column(
                  children: entries.map(_activityTile).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityTile(AdminLogEntry entry) {
    final action = entry.action;
    final target = entry.targetName.isNotEmpty ? entry.targetName : entry.details;

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(
          action?.icon ?? Icons.history,
          color: action?.color ?? Colors.white70,
        ),
        title: Text(
          '${action?.label ?? entry.actionName}'
          '${target.isNotEmpty ? ': $target' : ''}',
          style: const TextStyle(color: Colors.white, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'by ${entry.adminEmail.isNotEmpty ? entry.adminEmail : entry.adminUid}'
          '${entry.createdAt != null ? ' - ${formatLogTime(entry.createdAt!)}' : ''}',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ),
    );
  }

  Widget _statCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}