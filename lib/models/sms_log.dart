enum MessageType {
  received,
  sent,
}

class SmsLog {
  final String id;
  final String userId;
  final String sender;
  final String content;
  final DateTime timestamp;
  final MessageType messageType;
  final bool isBlocked;
  final double spamScore;

  SmsLog({
    required this.id,
    required this.userId,
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.messageType,
    this.isBlocked = false,
    this.spamScore = 0.0,
  });

  // Converter para Map (para banco de dados)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'sender': sender,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
      'message_type': messageType.name,
      'is_blocked': isBlocked ? 1 : 0,
      'spam_score': spamScore,
    };
  }

  // Criar SmsLog a partir de Map (do banco de dados)
  factory SmsLog.fromMap(Map<String, dynamic> map) {
    return SmsLog(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      sender: map['sender'] as String,
      content: map['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as int) * 1000),
      messageType: MessageType.values.firstWhere(
        (type) => type.name == map['message_type'],
        orElse: () => MessageType.received,
      ),
      isBlocked: (map['is_blocked'] as int) == 1,
      spamScore: (map['spam_score'] as num).toDouble(),
    );
  }

  // Criar cópia com modificações
  SmsLog copyWith({
    String? id,
    String? userId,
    String? sender,
    String? content,
    DateTime? timestamp,
    MessageType? messageType,
    bool? isBlocked,
    double? spamScore,
  }) {
    return SmsLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      messageType: messageType ?? this.messageType,
      isBlocked: isBlocked ?? this.isBlocked,
      spamScore: spamScore ?? this.spamScore,
    );
  }

  // Verificar se é spam baseado no score
  bool get isSpam => spamScore >= 0.7;

  // Verificar se é mensagem recente (últimas 24h)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inHours < 24;
  }

  // Verificar se contém palavras suspeitas
  bool get hasSuspiciousContent {
    final suspiciousWords = [
      'ganhe',
      'prêmio',
      'grátis',
      'urgente',
      'clique',
      'link',
      'promoção',
      'desconto',
      'oferta',
      'limitada',
      'parabéns',
      'selecionado',
    ];
    
    final lowerContent = content.toLowerCase();
    return suspiciousWords.any((word) => lowerContent.contains(word));
  }

  // Obter preview do conteúdo (primeiras 50 caracteres)
  String get contentPreview {
    if (content.length <= 50) return content;
    return '${content.substring(0, 47)}...';
  }

  // Verificar se é número curto (códigos de 4-6 dígitos)
  bool get isShortCode {
    final phoneRegex = RegExp(r'^[0-9]{4,6}$');
    return phoneRegex.hasMatch(sender);
  }

  // Verificar se é número internacional
  bool get isInternational {
    return sender.startsWith('+') && !sender.startsWith('+55');
  }

  // Formatação do remetente
  String get formattedSender {
    if (sender.startsWith('+55')) {
      // Formato brasileiro: +55 (11) 99999-9999
      final cleanNumber = sender.replaceAll('+55', '');
      if (cleanNumber.length == 11) {
        return '+55 (${cleanNumber.substring(0, 2)}) ${cleanNumber.substring(2, 7)}-${cleanNumber.substring(7)}';
      }
    }
    return sender;
  }

  @override
  String toString() {
    return 'SmsLog{id: $id, sender: $sender, messageType: $messageType, isBlocked: $isBlocked}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SmsLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}