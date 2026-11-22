import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game_model.dart';

class GameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('game_history');

  /// Most recent games first, at most [limit] of them. The screen raises the
  /// limit with "Load more", so only the games shown are read.
  Stream<List<GameModel>> getGames({required int limit}) {
    return _games
        .orderBy('completedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GameModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Totals over ALL games, using count queries (cheap: one read per 1000
  /// documents) instead of downloading every game.
  Future<Map<String, int>> getResultCounts() async {
    final results = await Future.wait([
      _games.count().get(),
      _games.where('resultForPlayer1', isEqualTo: 'win').count().get(),
      _games.where('resultForPlayer1', isEqualTo: 'loss').count().get(),
      _games.where('resultForPlayer1', isEqualTo: 'draw').count().get(),
    ]);

    return {
      'total': results[0].count ?? 0,
      'win': results[1].count ?? 0,
      'loss': results[2].count ?? 0,
      'draw': results[3].count ?? 0,
    };
  }

  // Get total number of games
  Future<int> getTotalGames() async {
    final snapshot = await _games.count().get();
    return snapshot.count ?? 0;
  }
}
