import 'package:flutter/material.dart';

import '../services/stats_service.dart';

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

  static const Color background = Color(0xFF0B0B2B);
  static const Color purple = Color(0xFF7B2FF7);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color pink = Color(0xFFFF2BD6);
  static const Color yellow = Color(0xFFFFD600);
  static const Color cardColor = Color(0xFF171F35);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Widget _summaryCard(
      String title,
      int value,
      Color color,
      IconData icon,
      ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.45),
          ),
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
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerStat(
      String label,
      int value,
      Color color,
      IconData icon,
      ) {
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
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
            ),
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
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: purple.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: purple,
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
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
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
            ),

            const Divider(color: Colors.white24, height: 25),

            Row(
              children: [
                _playerStat(
                  'Games',
                  games,
                  cyan,
                  Icons.sports_esports,
                ),
                _playerStat(
                  'Wins',
                  wins,
                  Colors.greenAccent,
                  Icons.emoji_events,
                ),
                _playerStat(
                  'Losses',
                  losses,
                  Colors.redAccent,
                  Icons.trending_down,
                ),
                _playerStat(
                  'Draws',
                  draws,
                  yellow,
                  Icons.handshake,
                ),
              ],
            ),

            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Win Rate',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: cyan,
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
                valueColor: const AlwaysStoppedAnimation<Color>(cyan),
              ),
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
        backgroundColor: background,
        foregroundColor: cyan,
        title: const Text(
          'Player Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder(
        stream: _statsService.getPlayerStats(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load player analytics.',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: cyan),
            );
          }

          final players = snapshot.data?.docs ?? [];

          int totalGames = 0;
          int totalWins = 0;
          int totalLosses = 0;
          int totalDraws = 0;

          for (final player in players) {
            final data = player.data();

            totalGames += _number(data['gamesPlayed']);
            totalWins += _number(data['wins']);
            totalLosses += _number(data['losses']);
            totalDraws += _number(data['draws']);
          }

          final filteredPlayers = players.where((player) {
            final data = player.data();

            final email = data['email']?.toString() ?? '';
            final uid = data['uid']?.toString() ?? player.id;
            final query = _searchQuery.toLowerCase();

            return email.toLowerCase().contains(query) ||
                uid.toLowerCase().contains(query);
          }).toList();

          filteredPlayers.sort((a, b) {
            final first = a.data();
            final second = b.data();

            switch (_sortBy) {
              case 'Wins':
                return _number(second['wins'])
                    .compareTo(_number(first['wins']));
              case 'Win Rate':
                final firstGames = _number(first['gamesPlayed']);
                final secondGames = _number(second['gamesPlayed']);

                return _winRate(
                  _number(second['wins']),
                  secondGames,
                ).compareTo(
                  _winRate(
                    _number(first['wins']),
                    firstGames,
                  ),
                );
              case 'Games Played':
              default:
                return _number(second['gamesPlayed'])
                    .compareTo(_number(first['gamesPlayed']));
            }
          });

          return ListView(
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

              Row(
                children: [
                  _summaryCard(
                    'Total Players',
                    players.length,
                    cyan,
                    Icons.people,
                  ),
                  const SizedBox(width: 10),
                  _summaryCard(
                    'Total Games',
                    totalGames,
                    purple,
                    Icons.sports_esports,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  _summaryCard(
                    'Total Wins',
                    totalWins,
                    Colors.greenAccent,
                    Icons.emoji_events,
                  ),
                  const SizedBox(width: 10),
                  _summaryCard(
                    'Total Losses',
                    totalLosses,
                    Colors.redAccent,
                    Icons.trending_down,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  _summaryCard(
                    'Total Draws',
                    totalDraws,
                    yellow,
                    Icons.handshake,
                  ),
                  const SizedBox(width: 10),
                  _summaryCard(
                    'Players Found',
                    filteredPlayers.length,
                    pink,
                    Icons.person_search,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              const Text(
                'Player Performance',
                style: TextStyle(
                  color: cyan,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search player by email or UID',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: cyan),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _sortBy,
                dropdownColor: cardColor,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Sort Players By',
                  prefixIcon: Icon(Icons.sort, color: cyan),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Games Played',
                    child: Text('Games Played'),
                  ),
                  DropdownMenuItem(
                    value: 'Wins',
                    child: Text('Wins'),
                  ),
                  DropdownMenuItem(
                    value: 'Win Rate',
                    child: Text('Win Rate'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _sortBy = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 18),

              if (filteredPlayers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        color: pink,
                        size: 42,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No player statistics found.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              else
                ...filteredPlayers.map((player) {
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
            ],
          );
        },
      ),
    );
  }
}