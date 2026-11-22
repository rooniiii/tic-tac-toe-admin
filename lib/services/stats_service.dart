import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class OverviewStats {
  final int totalPlayers;
  final int blockedPlayers;
  final int totalGames;
  final int totalWins;
  final int totalLosses;
  final int totalDraws;

  const OverviewStats({
    required this.totalPlayers,
    required this.blockedPlayers,
    required this.totalGames,
    required this.totalWins,
    required this.totalLosses,
    required this.totalDraws,
  });
}

class DailyGames {
  final DateTime day;
  final int games;

  const DailyGames(this.day, this.games);
}

class StatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _playerStats =>
      _firestore.collection('player_stats');

  CollectionReference<Map<String, dynamic>> get _gameHistory =>
      _firestore.collection('game_history');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Totals for the dashboard. Uses aggregation queries (count / sum), which
  /// cost one read per 1000 documents instead of reading every document.
  Future<OverviewStats> getOverview() async {
    // Each sum is its own query: summing several fields in ONE query would
    // need a composite index in Firestore, a single field does not.
    final results = await Future.wait<AggregateQuerySnapshot>([
      _users.count().get(),
      _users.where('isBlocked', isEqualTo: true).count().get(),
      _gameHistory.count().get(),
      _playerStats.aggregate(sum('wins')).get(),
      _playerStats.aggregate(sum('losses')).get(),
      _playerStats.aggregate(sum('draws')).get(),
    ]);

    return OverviewStats(
      totalPlayers: results[0].count ?? 0,
      blockedPlayers: results[1].count ?? 0,
      totalGames: results[2].count ?? 0,
      totalWins: (results[3].getSum('wins') ?? 0).toInt(),
      totalLosses: (results[4].getSum('losses') ?? 0).toInt(),
      totalDraws: (results[5].getSum('draws') ?? 0).toInt(),
    );
  }

  /// Number of games finished on each of the last [days] days (oldest
  /// first). Only reads games from that period.
  Future<List<DailyGames>> getGamesPerDay({int days = 14}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));

    final snapshot = await _gameHistory
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();

    final counts = <DateTime, int>{
      for (var i = 0; i < days; i++) start.add(Duration(days: i)): 0,
    };

    for (final doc in snapshot.docs) {
      final completed = doc.data()['completedAt'];
      if (completed is! Timestamp) continue;

      final local = completed.toDate().toLocal();
      final day = DateTime(local.year, local.month, local.day);

      if (counts.containsKey(day)) {
        counts[day] = counts[day]! + 1;
      }
    }

    return counts.entries.map((e) => DailyGames(e.key, e.value)).toList();
  }

  /// Players with the most games.
  Future<List<Map<String, dynamic>>> getMostActivePlayers({
    int limit = 5,
  }) async {
    final snapshot = await _playerStats
        .orderBy('gamesPlayed', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'email': data['email']?.toString() ?? doc.id,
        'gamesPlayed': _toInt(data['gamesPlayed']),
        'wins': _toInt(data['wins']),
      };
    }).toList();
  }

  /// Player stats sorted by [field] (gamesPlayed or wins), at most [limit].
  Stream<QuerySnapshot<Map<String, dynamic>>> getPlayerStats({
    required String field,
    required int limit,
  }) {
    return _playerStats
        .orderBy(field, descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<Map<String, dynamic>?> getPlayerStatsById(String uid) async {
    final doc = await _playerStats.doc(uid).get();

    if (!doc.exists) return null;

    return doc.data();
  }

  Future<int> getTotalPlayers() async {
    final snapshot = await _playerStats.count().get();
    return snapshot.count ?? 0;
  }
}
