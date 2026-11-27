import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/load_more_button.dart';
import '../widgets/simple_charts.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final StatsService _statsService = StatsService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _sortBy = 'Games Played';

  static const int _pageSize = 25;
  int _limit = _pageSize;

  late Future<OverviewStats> _overviewFuture;
  late Future<List<DailyGames>> _dailyFuture;
  late Future<List<Map<String, dynamic>>> _topFuture;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _playersStream;

  @override
  void initState() {
    super.initState();
    _loadCharts();
    _playersStream = _playerQuery();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCharts() {
    _overviewFuture = _statsService.getOverview();
    _dailyFuture = _statsService.getGamesPerDay(days: 14);
    _topFuture = _statsService.getMostActivePlayers(limit: 5);
  }

  // "Win Rate" cannot be sorted by Firestore, so it loads by games played
  // and sorts the loaded players on the device.
  Stream<QuerySnapshot<Map<String, dynamic>>> _playerQuery() {
    final field = _sortBy == 'Wins' ? 'wins' : 'gamesPlayed';
    return _statsService.getPlayerStats(field: field, limit: _limit);
  }

  void _refresh() {
    setState(() {
      _loadCharts();
      _playersStream = _playerQuery();
    });
  }

  void _loadMore() {
    setState(() {
      _limit += _pageSize;
      _playersStream = _playerQuery();
    });
  }

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _winRate(int wins, int games) {
    if (games <= 0) return 0;
    return (wins / games) * 100;
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  Widget _summaryCard(String title, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 25,
                fontWeight: FontWeight.bold,
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

  Widget _summarySection() {
    return FutureBuilder<OverviewStats>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        final s = snapshot.data;

        return Column(
          children: [
            Row(
              children: [
                _summaryCard('Total Players', s?.totalPlayers ?? 0,
                    AppTheme.neonCyan, Icons.people),
                const SizedBox(width: 10),
                _summaryCard('Total Games', s?.totalGames ?? 0,
                    AppTheme.purple, Icons.sports_esports),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _summaryCard('Total Wins', s?.totalWins ?? 0,
                    Colors.greenAccent, Icons.emoji_events),
                const SizedBox(width: 10),
                _summaryCard('Total Losses', s?.totalLosses ?? 0,
                    Colors.redAccent, Icons.trending_down),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _summaryCard('Total Draws', s?.totalDraws ?? 0,
                    AppTheme.neonYellow, Icons.handshake),
                const SizedBox(width: 10),
                _summaryCard('Blocked Players', s?.blockedPlayers ?? 0,
                    AppTheme.neonPink, Icons.block),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _chartsSection() {
    return Column(
      children: [
        ChartCard(
          title: 'Games per Day',
          subtitle: 'Last 14 days',
          child: FutureBuilder<List<DailyGames>>(
            future: _dailyFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Unable to load games per day.',
                  style: TextStyle(color: Colors.redAccent),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 150,
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.neonCyan),
                  ),
                );
              }

              final days = snapshot.data!;
              return VerticalBarChart(
                labels: days.map((d) => '${d.day.day}/${d.day.month}').toList(),
                values: days.map((d) => d.games).toList(),
              );
            },
          ),
        ),
        ChartCard(
          title: 'Results Split',
          subtitle: 'All recorded games, from the player\'s side',
          child: FutureBuilder<OverviewStats>(
            future: _overviewFuture,
            builder: (context, snapshot) {
              final s = snapshot.data;
              if (s == null) {
                return const SizedBox(height: 40);
              }
              return StackedRatioBar(
                segments: [
                  ChartSegment('Wins', s.totalWins, Colors.greenAccent),
                  ChartSegment('Losses', s.totalLosses, Colors.redAccent),
                  ChartSegment('Draws', s.totalDraws, AppTheme.neonYellow),
                ],
              );
            },
          ),
        ),
        ChartCard(
          title: 'Most Active Players',
          subtitle: 'Top 5 by games played',
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _topFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 40);
              }
              final players = snapshot.data!;
              return HorizontalBarList(
                labels: players.map((p) => p['email'] as String).toList(),
                values: players.map((p) => p['gamesPlayed'] as int).toList(),
                unit: ' games',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _playerStat(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 5),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _playerCard({
    required String email,
    required String uid,
    required int games,
    required int wins,
    required int losses,
    required int draws,
  }) {
    final rate = _winRate(wins, games);

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: AppTheme.purple.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.purple,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    email,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'UID: $uid',
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            const Divider(color: Colors.white24, height: 25),
            Row(
              children: [
                _playerStat(
                    'Games', games, AppTheme.neonCyan, Icons.sports_esports),
                _playerStat(
                    'Wins', wins, Colors.greenAccent, Icons.emoji_events),
                _playerStat(
                    'Losses', losses, Colors.redAccent, Icons.trending_down),
                _playerStat(
                    'Draws', draws, AppTheme.neonYellow, Icons.handshake),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Win Rate',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppTheme.neonCyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: rate / 100,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.neonCyan),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playersSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _playersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Unable to load player statistics.',
            style: TextStyle(color: Colors.redAccent),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.neonCyan),
            ),
          );
        }

        final players = snapshot.data?.docs ?? [];
        final canLoadMore = players.length >= _limit;
        final query = _searchQuery.toLowerCase();

        final filtered = players.where((player) {
          final data = player.data();
          final email = data['email']?.toString() ?? '';
          final uid = data['uid']?.toString() ?? player.id;
          return email.toLowerCase().contains(query) ||
              uid.toLowerCase().contains(query);
        }).toList();

        if (_sortBy == 'Win Rate') {
          filtered.sort((a, b) {
            final x = a.data();
            final y = b.data();
            return _winRate(_number(y['wins']), _number(y['gamesPlayed']))
                .compareTo(
              _winRate(_number(x['wins']), _number(x['gamesPlayed'])),
            );
          });
        }

        return Column(
          children: [
            if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.analytics_outlined,
                        color: AppTheme.neonPink, size: 42),
                    SizedBox(height: 10),
                    Text(
                      'No player statistics found.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            else
              ...filtered.map((player) {
                final data = player.data();
                return _playerCard(
                  email: data['email']?.toString() ?? 'Unknown',
                  uid: data['uid']?.toString() ?? player.id,
                  games: _number(data['gamesPlayed']),
                  wins: _number(data['wins']),
                  losses: _number(data['losses']),
                  draws: _number(data['draws']),
                );
              }),
            if (canLoadMore)
              LoadMoreButton(
                shown: players.length,
                onPressed: _loadMore,
                hint: _sortBy == 'Win Rate' || query.isNotEmpty
                    ? 'Search and win-rate sorting only cover loaded players.'
                    : null,
              ),
          ],
        );
      },
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
          'Player Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Analytics Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Monitor player performance and game statistics.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          _summarySection(),
          const SizedBox(height: 22),
          _chartsSection(),
          const SizedBox(height: 8),
          const Text(
            'Player Performance',
            style: TextStyle(
              color: AppTheme.neonCyan,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search loaded players by email or UID',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: AppTheme.neonCyan),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white70),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _sortBy,
            dropdownColor: AppTheme.surface,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Sort Players By',
              prefixIcon: Icon(Icons.sort, color: AppTheme.neonCyan),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Games Played',
                child: Text('Games Played'),
              ),
              DropdownMenuItem(value: 'Wins', child: Text('Wins')),
              DropdownMenuItem(value: 'Win Rate', child: Text('Win Rate')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _sortBy = value;
                _limit = _pageSize;
                _playersStream = _playerQuery();
              });
            },
          ),
          const SizedBox(height: 18),
          _playersSection(),
        ],
      ),
    );
  }
}
