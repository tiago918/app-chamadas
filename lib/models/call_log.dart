enum CallType {
  incoming,
  outgoing,
  missed,
}

class CallLog {
  final String id;
  final String userId;
  final String phoneNumber;
  final String? contactName;
  final DateTime timestamp;
  final int duration; // em segundos
  final CallType callType;
  final bool isBlocked;
  final double spamScore;

  CallLog({
    required this.id,
    required this.userId,
    required this.phoneNumber,
    this.contactName,
    required this.timestamp,
    this.duration = 0,
    required this.callType,
    this.isBlocked = false,
    this.spamScore = 0.0,
  });

  // Converter para Map (para banco de dados)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'phone_number': phoneNumber,
      'contact_name': contactName,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
      'duration': duration,
      'call_type': callType.name,
      'is_blocked': isBlocked ? 1 : 0,
      'spam_score': spamScore,
    };
  }

  // Criar CallLog a partir de Map (do banco de dados)
  factory CallLog.fromMap(Map<String, dynamic> map) {
    return CallLog(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      phoneNumber: map['phone_number'] as String,
      contactName: map['contact_name'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as int) * 1000),
      duration: map['duration'] as int,
      callType: CallType.values.firstWhere(
        (type) => type.name == map['call_type'],
        orElse: () => CallType.incoming,
      ),
      isBlocked: (map['is_blocked'] as int) == 1,
      spamScore: (map['spam_score'] as num).toDouble(),
    );
  }

  // Criar cópia com modificações
  CallLog copyWith({
    String? id,
    String? userId,
    String? phoneNumber,
    String? contactName,
    DateTime? timestamp,
    int? duration,
    CallType? callType,
    bool? isBlocked,
    double? spamScore,
  }) {
    return CallLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      contactName: contactName ?? this.contactName,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      callType: callType ?? this.callType,
      isBlocked: isBlocked ?? this.isBlocked,
      spamScore: spamScore ?? this.spamScore,
    );
  }

  // Formatação da duração
  String get formattedDuration {
    if (duration == 0) return '0s';
    
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // Verificar se é spam baseado no score
  bool get isSpam => spamScore >= 0.7;

  // Verificar se é chamada perdida
  bool get isMissed => callType == CallType.missed;

  // Verificar se é chamada recente (últimas 24h)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inHours < 24;
  }

  @override
  String toString() {
    return 'CallLog{id: $id, phoneNumber: $phoneNumber, callType: $callType, isBlocked: $isBlocked}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CallLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}