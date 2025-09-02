class User {
  final String id;
  final String email;
  final String? phoneNumber;
  final bool isPremium;
  final Map<String, dynamic>? settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    this.phoneNumber,
    this.isPremium = false,
    this.settings,
    required this.createdAt,
    required this.updatedAt,
  });

  // Converter para Map (para banco de dados)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'phone_number': phoneNumber,
      'is_premium': isPremium ? 1 : 0,
      'settings': settings != null ? _encodeSettings(settings!) : null,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'updated_at': updatedAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  // Criar User a partir de Map (do banco de dados)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      email: map['email'] as String,
      phoneNumber: map['phone_number'] as String?,
      isPremium: (map['is_premium'] as int) == 1,
      settings: map['settings'] != null ? _decodeSettings(map['settings'] as String) : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int) * 1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch((map['updated_at'] as int) * 1000),
    );
  }

  // Criar cópia com modificações
  User copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    bool? isPremium,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPremium: isPremium ?? this.isPremium,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Codificar configurações para JSON string
  static String _encodeSettings(Map<String, dynamic> settings) {
    return settings.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  // Decodificar configurações de JSON string
  static Map<String, dynamic> _decodeSettings(String settingsStr) {
    final Map<String, dynamic> settings = {};
    final pairs = settingsStr.split(',');
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        settings[parts[0]] = parts[1];
      }
    }
    return settings;
  }

  @override
  String toString() {
    return 'User{id: $id, email: $email, phoneNumber: $phoneNumber, isPremium: $isPremium}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}