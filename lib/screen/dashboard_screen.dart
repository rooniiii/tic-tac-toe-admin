import 'package:flutter/material.dart';

import '../services/stats_service.dart';
import '../services/admin_service.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onLogout;

  DashboardScreen({
    super.key,
    required this.onLogout,
  });

  final StatsService _statsService = StatsService();
  final AdminService _adminService = AdminService();

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171F35),
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
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.cyanAccent),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
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
    onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171F35),
        title: const Text(
          'NEON XO ADMIN',
          style: TextStyle(
            color: Colors.cyanAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
            icon: const Icon(
              Icons.logout,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, int>>(
        stream: _statsService.getOverallStats(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load dashboard data:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.cyanAccent,
              ),
            );
          }

          final stats = snapshot.data ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  'Live data from Firebase',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 25),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.25,
                  children: [
                    _statCard(
                      'Total Players',
                      stats['totalPlayers'] ?? 0,
                      Icons.people,
                      Colors.cyanAccent,
                    ),
                    _statCard(
                      'Total Games',
                      stats['totalGames'] ?? 0,
                      Icons.sports_esports,
                      Colors.purpleAccent,
                    ),
                    _statCard(
                      'Total Wins',
                      stats['totalWins'] ?? 0,
                      Icons.emoji_events,
                      Colors.greenAccent,
                    ),
                    _statCard(
                      'Total Losses',
                      stats['totalLosses'] ?? 0,
                      Icons.trending_down,
                      Colors.redAccent,
                    ),
                    _statCard(
                      'Total Draws',
                      stats['totalDraws'] ?? 0,
                      Icons.handshake,
                      Colors.orangeAccent,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(
      String title,
      int value,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171F35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
        ),
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
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}