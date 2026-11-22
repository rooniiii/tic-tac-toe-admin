import 'package:flutter/material.dart';

import '../models/game_model.dart';
import '../services/game_service.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  final GameService _gameService = GameService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedResult = 'All';
  String _selectedDifficulty = 'All';
  String _searchQuery = '';

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

  Color _resultColor(String result) {
    switch (result.toUpperCase()) {
      case 'WIN':
        return Colors.greenAccent;
      case 'LOSS':
        return Colors.redAccent;
      case 'DRAW':
        return yellow;
      default:
        return Colors.white70;
    }
  }

  bool _matchesSearch(GameModel game) {
    final query = _searchQuery.toLowerCase();

    if (query.isEmpty) return true;

    return game.player1Email.toLowerCase().contains(query) ||
        game.player1Uid.toLowerCase().contains(query) ||
        game.id.toLowerCase().contains(query) ||
        game.opponentName.toLowerCase().contains(query) ||
        game.opponentType.toLowerCase().contains(query);
  }

  List<GameModel> _filterGames(List<GameModel> games) {
    return games.where((game) {
      final resultMatches = _selectedResult == 'All' ||
          game.result.toUpperCase() == _selectedResult.toUpperCase();

      final difficultyMatches = _selectedDifficulty == 'All' ||
          game.difficulty.toLowerCase() ==
              _selectedDifficulty.toLowerCase();

      return resultMatches &&
          difficultyMatches &&
          _matchesSearch(game);
    }).toList();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _summaryCard(String title, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 10),
            Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontSize: 23,
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

  Widget _buildFilters(List<GameModel> games) {
    final difficulties = games
        .map((game) => game.difficulty.trim())
        .where((difficulty) => difficulty.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final validDifficulty = difficulties.contains(_selectedDifficulty)
        ? _selectedDifficulty
        : 'All';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filter by Result',
          style: TextStyle(
            color: cyan,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['All', 'WIN', 'LOSS', 'DRAW'].map((result) {
            final selected = _selectedResult == result;

            return ChoiceChip(
              label: Text(result),
              selected: selected,
              selectedColor: purple,
              backgroundColor: cardColor,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.white70,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedResult = result;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        const Text(
          'Filter by Difficulty',
          style: TextStyle(
            color: cyan,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: validDifficulty,
          dropdownColor: cardColor,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.speed, color: cyan),
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(color: Colors.white),
          items: [
            const DropdownMenuItem(
              value: 'All',
              child: Text('All Difficulties'),
            ),
            ...difficulties.map(
                  (difficulty) => DropdownMenuItem(
                value: difficulty,
                child: Text(difficulty),
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedDifficulty = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _gameCard(GameModel game) {
    final result = game.result.toUpperCase();
    final color = _resultColor(result);

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: purple.withValues(alpha: 0.4),
        ),
      ),
      child: ExpansionTile(
        iconColor: cyan,
        collapsedIconColor: cyan,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 5,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(
          Icons.sports_esports,
          color: cyan,
          size: 28,
        ),
        title: Text(
          game.player1Email.isEmpty
              ? (game.player1Uid.isEmpty ? 'Unknown Player' : game.player1Uid)
              : game.player1Email,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Game ID: ${game.id}',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color),
          ),
          child: Text(
            result.isEmpty ? 'UNKNOWN' : result,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        children: [
          const Divider(color: Colors.white24),
          _detail('Player Email', game.player1Email),
          _detail('Player UID', game.player1Uid),
          _detail('Opponent', game.opponentName),
          _detail('Opponent Type', game.opponentType),
          _detail('Difficulty', game.difficulty),
          _detail('Result', result),
          _detail('Completed At', _formatDate(game.completedAt)),
          _detail('Game ID', game.id),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(
                color: cyan,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not available' : value,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
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
          'Game Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<GameModel>>(
        stream: _gameService.getGames(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load game records.',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: cyan),
            );
          }

          final games = snapshot.data ?? [];

          final totalWins = games.where(
                (game) => game.result.toUpperCase() == 'WIN',
          ).length;

          final totalLosses = games.where(
                (game) => game.result.toUpperCase() == 'LOSS',
          ).length;

          final totalDraws = games.where(
                (game) => game.result.toUpperCase() == 'DRAW',
          ).length;

          final filteredGames = _filterGames(games);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Game History Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Monitor and review recorded game activity.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  _summaryCard(
                    'Total Games',
                    games.length,
                    cyan,
                    Icons.sports_esports,
                  ),
                  const SizedBox(width: 8),
                  _summaryCard(
                    'Wins',
                    totalWins,
                    Colors.greenAccent,
                    Icons.emoji_events,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _summaryCard(
                    'Losses',
                    totalLosses,
                    Colors.redAccent,
                    Icons.trending_down,
                  ),
                  const SizedBox(width: 8),
                  _summaryCard(
                    'Draws',
                    totalDraws,
                    yellow,
                    Icons.handshake,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search email, UID, opponent or Game ID',
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

              const SizedBox(height: 18),

              _buildFilters(games),

              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Game Records',
                    style: TextStyle(
                      color: cyan,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${filteredGames.length} records',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (filteredGames.isEmpty)
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        color: pink,
                        size: 40,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No matching game records found.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              else
                ...filteredGames.map(_gameCard),
            ],
          );
        },
      ),
    );
  }
}