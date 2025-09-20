/// AI解答内容数据模型
class AIExplanation {
  final int? id;
  final int quizRecordId; // 关联的答题记录ID
  final String explanation; // AI解答内容
  final DateTime createdAt; // 创建时间
  final DateTime? updatedAt; // 更新时间

  AIExplanation({
    this.id,
    required this.quizRecordId,
    required this.explanation,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quiz_record_id': quizRecordId,
      'explanation': explanation,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory AIExplanation.fromMap(Map<String, dynamic> map) {
    return AIExplanation(
      id: map['id'],
      quizRecordId: map['quiz_record_id'],
      explanation: map['explanation'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
    );
  }

  /// 创建副本（用于更新）
  AIExplanation copyWith({
    int? id,
    int? quizRecordId,
    String? explanation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AIExplanation(
      id: id ?? this.id,
      quizRecordId: quizRecordId ?? this.quizRecordId,
      explanation: explanation ?? this.explanation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'AIExplanation(id: $id, quizRecordId: $quizRecordId, explanation: ${explanation.length > 50 ? explanation.substring(0, 50) + '...' : explanation})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AIExplanation &&
      other.id == id &&
      other.quizRecordId == quizRecordId &&
      other.explanation == explanation &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      quizRecordId.hashCode ^
      explanation.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
  }
}