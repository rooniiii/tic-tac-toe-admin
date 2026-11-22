class GameModel {
  final String id;
  final String player1Uid;
  final String player1Email;
  final String opponentType;
  final String opponentName;
  final String difficulty;
  final String result;
  final DateTime? completedAt;

  const GameModel({
    required this.id,
    required this.player1Uid,
    required this.player1Email,
    required this.opponentType,
    required this.opponentName,
    required this.difficulty,
    required this.result,
    this.completedAt,
  });

  factory GameModel.fromMap(String id, Map<String, dynamic> data) {
    return GameModel(
      id: id,
      player1Uid: data['player1Uid'] ?? '',
      player1Email: data['player1Email'] ?? '',
      opponentType: data['opponentType'] ?? '',
      opponentName: data['opponentName'] ?? '',
      difficulty: data['difficulty'] ?? '',
      result: data['resultForPlayer1'] ?? '',
      completedAt: (data['completedAt'] as dynamic)?.toDate(),
    );
  }
}