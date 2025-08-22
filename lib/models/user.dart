class User {
  final int? id;
  final String username;
  final String email;
  final String? avatarPath; // 头像路径
  final String? nickname; // 昵称
  final String? bio; // 个人简介
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    this.id,
    required this.username,
    required this.email,
    this.avatarPath,
    this.nickname,
    this.bio,
    required this.createdAt,
    required this.updatedAt,
  });

  // 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_path': avatarPath,
      'nickname': nickname,
      'bio': bio,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  // 从数据库Map创建
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id']?.toInt(),
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      avatarPath: map['avatar_path'],
      nickname: map['nickname'],
      bio: map['bio'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  // 复制并更新
  User copyWith({
    int? id,
    String? username,
    String? email,
    String? avatarPath,
    String? nickname,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarPath: avatarPath ?? this.avatarPath,
      nickname: nickname ?? this.nickname,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'User{id: $id, username: $username, email: $email, avatarPath: $avatarPath, nickname: $nickname, bio: $bio, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
