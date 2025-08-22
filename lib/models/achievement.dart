class Achievement {
  final int? id;
  final int userId; // 外键，关联用户表
  final String name; // 成就名称
  final String description; // 成就描述
  final String icon; // 成就图标
  final DateTime earnedAt; // 获得时间
  final bool isUnlocked; // 是否已解锁

  Achievement({
    this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.icon,
    required this.earnedAt,
    required this.isUnlocked,
  });

  // 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'icon': icon,
      'earned_at': earnedAt.millisecondsSinceEpoch,
      'is_unlocked': isUnlocked ? 1 : 0,
    };
  }

  // 从数据库Map创建
  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id']?.toInt(),
      userId: map['user_id']?.toInt() ?? 0,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'] ?? '',
      earnedAt: DateTime.fromMillisecondsSinceEpoch(map['earned_at']),
      isUnlocked: map['is_unlocked'] == 1,
    );
  }

  // 复制并更新
  Achievement copyWith({
    int? id,
    int? userId,
    String? name,
    String? description,
    String? icon,
    DateTime? earnedAt,
    bool? isUnlocked,
  }) {
    return Achievement(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      earnedAt: earnedAt ?? this.earnedAt,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }

  @override
  String toString() {
    return 'Achievement{id: $id, userId: $userId, name: $name, description: $description, icon: $icon, earnedAt: $earnedAt, isUnlocked: $isUnlocked}';
  }
}


