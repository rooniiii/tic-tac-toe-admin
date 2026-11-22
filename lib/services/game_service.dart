import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game_model.dart';

class GameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all game records
  Stream<List<GameModel>> getGames() {
    return _firestore
        .collection('game_history')
        .snapshots()
        .map((snapshot) {
      final games = snapshot.docs.map((doc) {
        return GameModel.fromMap(doc.id, doc.data());
      }).toList();

      games.sort((a, b) {
        return (b.completedAt ?? DateTime(2000))
            .compareTo(a.completedAt ?? DateTime(2000));
      });

      return games;
    });
  }

  // Get total number of games
  Future<int> getTotalGames() async {
    final snapshot =
    await _firestore.collection('game_history').count().get();

    return snapshot.count ?? 0;
  }
}