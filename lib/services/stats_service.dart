import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class StatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _playerStats =>
      _firestore.collection('player_stats');

  CollectionReference<Map<String, dynamic>> get _gameHistory =>
      _firestore.collection('game_history');

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Stream<Map<String, int>> getOverallStats() {
    late StreamController<Map<String, int>> controller;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? statsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? gamesSub;

    QuerySnapshot<Map<String, dynamic>>? latestStats;
    QuerySnapshot<Map<String, dynamic>>? latestGames;

    void emitStats() {
      if (latestStats == null ||
          latestGames == null ||
          controller.isClosed) {
        return;
      }

      int totalWins = 0;
      int totalLosses = 0;
      int totalDraws = 0;

      for (final doc in latestStats!.docs) {
        final data = doc.data();

        totalWins += _toInt(data['wins']);
        totalLosses += _toInt(data['losses']);
        totalDraws += _toInt(data['draws']);
      }

      controller.add({
        'totalPlayers': latestStats!.docs.length,
        'totalGames': latestGames!.docs.length,
        'totalWins': totalWins,
        'totalLosses': totalLosses,
        'totalDraws': totalDraws,
      });
    }

    controller = StreamController<Map<String, int>>(
      onListen: () {
        statsSub = _playerStats.snapshots().listen(
              (snapshot) {
            latestStats = snapshot;
            emitStats();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );

        gamesSub = _gameHistory.snapshots().listen(
              (snapshot) {
            latestGames = snapshot;
            emitStats();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );
      },
      onCancel: () async {
        await statsSub?.cancel();
        await gamesSub?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPlayerStats() {
    return _playerStats.snapshots();
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