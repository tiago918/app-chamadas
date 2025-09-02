enum RuleType {
  pattern,
  whitelist,
  blacklist,
  timeBased,
  international,
  unknown,
  shortCode,
  smsBlacklist,
  keywordFilter,
  phoneNumber,
  keyword,
  prefix,
  regex,
}

class BlockRule {
  final String id;
  final String userId;
  final String ruleName;
  final RuleType ruleType;
  final String? pattern;
  final bool isActive;
  final int priority;
  final DateTime createdAt;

  BlockRule({
    required this.id,
    required this.userId,
    required this.ruleName,
    required this.ruleType,
    this.pattern,
    this.isActive = true,
    this.priority = 0,
    required this.createdAt,
  });

  // Converter para Map (para banco de dados)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'rule_name': ruleName,
      'rule_type': ruleType.name,
      'pattern': pattern,
      'is_active': isActive ? 1 : 0,
      'priority': priority,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  // Criar BlockRule a partir de Map (do banco de dados)
  factory BlockRule.fromMap(Map<String, dynamic> map) {
    return BlockRule(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      ruleName: map['rule_name'] as String,
      ruleType: RuleType.values.firstWhere(
        (type) => type.name == map['rule_type'],
        orElse: () => RuleType.pattern,
      ),
      pattern: map['pattern'] as String?,
      isActive: (map['is_active'] as int) == 1,
      priority: map['priority'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int) * 1000),
    );
  }

  // Criar cópia com modificações
  BlockRule copyWith({
    String? id,
    String? userId,
    String? ruleName,
    RuleType? ruleType,
    String? pattern,
    bool? isActive,
    int? priority,
    DateTime? createdAt,
  }) {
    return BlockRule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      ruleName: ruleName ?? this.ruleName,
      ruleType: ruleType ?? this.ruleType,
      pattern: pattern ?? this.pattern,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Verificar se um número corresponde a esta regra
  bool matches(String phoneNumber) {
    if (!isActive) return false;

    switch (ruleType) {
      case RuleType.pattern:
      case RuleType.regex:
        if (pattern == null) return false;
        try {
          final regex = RegExp(pattern!);
          return regex.hasMatch(phoneNumber);
        } catch (e) {
          return false;
        }

      case RuleType.blacklist:
      case RuleType.smsBlacklist:
      case RuleType.phoneNumber:
        return pattern == phoneNumber;

      case RuleType.whitelist:
        return pattern != phoneNumber; // Whitelist bloqueia tudo exceto o padrão

      case RuleType.international:
        return phoneNumber.startsWith('+') && !phoneNumber.startsWith('+55');

      case RuleType.unknown:
        // Lógica para números desconhecidos (não em contatos)
        return true; // Implementar verificação de contatos se necessário

      case RuleType.shortCode:
        return phoneNumber.length <= 6 && RegExp(r'^[0-9]+$').hasMatch(phoneNumber);

      case RuleType.prefix:
        if (pattern == null) return false;
        return phoneNumber.startsWith(pattern!);

      case RuleType.keyword:
      case RuleType.keywordFilter:
        // Para números, não se aplica
        return false;

      case RuleType.timeBased:
        // Implementar lógica baseada em tempo se necessário
        return false;
    }
  }

  // Verificar se uma mensagem corresponde a esta regra
  bool matchesMessage(String sender, String content) {
    if (!isActive) return false;

    switch (ruleType) {
      case RuleType.pattern:
      case RuleType.regex:
        if (pattern == null) return false;
        try {
          final regex = RegExp(pattern!, caseSensitive: false);
          return regex.hasMatch(sender) || regex.hasMatch(content);
        } catch (e) {
          return false;
        }

      case RuleType.blacklist:
      case RuleType.smsBlacklist:
      case RuleType.phoneNumber:
        return pattern == sender;

      case RuleType.whitelist:
        return pattern != sender;

      case RuleType.international:
        return sender.startsWith('+') && !sender.startsWith('+55');

      case RuleType.unknown:
        // Para mensagens, verificar se remetente é desconhecido
        return true; // Implementar verificação de contatos se necessário

      case RuleType.shortCode:
        return sender.length <= 6 && RegExp(r'^[0-9]+$').hasMatch(sender);

      case RuleType.prefix:
        if (pattern == null) return false;
        return sender.startsWith(pattern!);

      case RuleType.keyword:
      case RuleType.keywordFilter:
        if (pattern == null) return false;
        return content.toLowerCase().contains(pattern!.toLowerCase());

      case RuleType.timeBased:
        return false;
    }
  }

  // Obter descrição da regra
  String get description {
    switch (ruleType) {
      case RuleType.pattern:
      case RuleType.regex:
        return 'Bloqueia números que correspondem ao padrão: ${pattern ?? "N/A"}';
      case RuleType.blacklist:
      case RuleType.smsBlacklist:
        return 'Bloqueia especificamente: ${pattern ?? "N/A"}';
      case RuleType.whitelist:
        return 'Permite apenas: ${pattern ?? "N/A"}';
      case RuleType.phoneNumber:
        return 'Bloqueia número de telefone: ${pattern ?? "N/A"}';
      case RuleType.international:
        return 'Bloqueia chamadas internacionais (exceto Brasil)';
      case RuleType.unknown:
        return 'Bloqueia números desconhecidos';
      case RuleType.shortCode:
        return 'Bloqueia códigos curtos (4-6 dígitos)';
      case RuleType.prefix:
        return 'Bloqueia números com prefixo: ${pattern ?? "N/A"}';
      case RuleType.keyword:
      case RuleType.keywordFilter:
        return 'Bloqueia mensagens com palavra-chave: ${pattern ?? "N/A"}';
      case RuleType.timeBased:
        return 'Regra baseada em horário';
    }
  }

  // Obter ícone da regra
  String get icon {
    switch (ruleType) {
      case RuleType.pattern:
      case RuleType.regex:
        return '🔍';
      case RuleType.blacklist:
      case RuleType.smsBlacklist:
      case RuleType.phoneNumber:
        return '🚫';
      case RuleType.whitelist:
        return '✅';
      case RuleType.international:
        return '🌍';
      case RuleType.unknown:
        return '❓';
      case RuleType.shortCode:
        return '📱';
      case RuleType.prefix:
        return '🔢';
      case RuleType.keyword:
      case RuleType.keywordFilter:
        return '🔤';
      case RuleType.timeBased:
        return '⏰';
    }
  }

  // Regras padrão do sistema
  static List<BlockRule> getDefaultRules(String userId) {
    final now = DateTime.now();
    return [
      BlockRule(
        id: 'default_unknown_$userId',
        userId: userId,
        ruleName: 'Números Desconhecidos',
        ruleType: RuleType.pattern,
        pattern: r'^(?!.*contacts).*$',
        priority: 1,
        createdAt: now,
      ),
      BlockRule(
        id: 'default_international_$userId',
        userId: userId,
        ruleName: 'Chamadas Internacionais',
        ruleType: RuleType.pattern,
        pattern: r'^\+(?!55).*$',
        priority: 2,
        createdAt: now,
      ),
      BlockRule(
        id: 'default_short_codes_$userId',
        userId: userId,
        ruleName: 'Códigos Curtos Suspeitos',
        ruleType: RuleType.pattern,
        pattern: r'^[0-9]{4,6}$',
        priority: 3,
        createdAt: now,
      ),
    ];
  }

  @override
  String toString() {
    return 'BlockRule{id: $id, ruleName: $ruleName, ruleType: $ruleType, isActive: $isActive}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BlockRule && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}