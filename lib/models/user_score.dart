class UserScore {
  final int? id;
  final int userId; // 外键，关联用户表
  final int score; // 积分（权重值）
  final String description; // 积分描述
  final DateTime earnedAt; // 获得时间

  UserScore({
    this.id,
    required this.userId,
    required this.score,
    required this.description,
    required this.earnedAt,
  });

  // 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'score': score,
      'description': description,
      'earned_at': earnedAt.millisecondsSinceEpoch,
    };
  }

  // 从数据库Map创建
  factory UserScore.fromMap(Map<String, dynamic> map) {
    return UserScore(
      id: map['id']?.toInt(),
      userId: map['user_id']?.toInt() ?? 0,
      score: map['score']?.toInt() ?? 0,
      description: map['description'] ?? '',
      earnedAt: DateTime.fromMillisecondsSinceEpoch(map['earned_at']),
    );
  }

  // 复制并更新
  UserScore copyWith({
    int? id,
    int? userId,
    int? score,
    String? description,
    DateTime? earnedAt,
  }) {
    return UserScore(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      score: score ?? this.score,
      description: description ?? this.description,
      earnedAt: earnedAt ?? this.earnedAt,
    );
  }

  @override
  String toString() {
    return 'UserScore{id: $id, userId: $userId, score: $score, description: $description, earnedAt: $earnedAt}';
  }
}


