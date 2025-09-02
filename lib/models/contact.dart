class Contact {
  final String id;
  final String userId;
  final String name;
  final String phoneNumber;
  final bool isTrusted;
  final bool isBlocked;
  final DateTime createdAt;
  final DateTime? lastContactAt;
  final String? photoUrl;
  final String? notes;

  Contact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.isTrusted = false,
    this.isBlocked = false,
    required this.createdAt,
    this.lastContactAt,
    this.photoUrl,
    this.notes,
  });

  // Converter para Map (para banco de dados)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone_number': phoneNumber,
      'is_trusted': isTrusted ? 1 : 0,
      'is_blocked': isBlocked ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'last_contact_at': lastContactAt != null ? lastContactAt!.millisecondsSinceEpoch ~/ 1000 : null,
      'photo_url': photoUrl,
      'notes': notes,
    };
  }

  // Criar Contact a partir de Map (do banco de dados)
  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      phoneNumber: map['phone_number'] as String,
      isTrusted: (map['is_trusted'] as int) == 1,
      isBlocked: (map['is_blocked'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int) * 1000),
      lastContactAt: map['last_contact_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['last_contact_at'] as int) * 1000)
          : null,
      photoUrl: map['photo_url'] as String?,
      notes: map['notes'] as String?,
    );
  }

  // Criar cópia com modificações
  Contact copyWith({
    String? id,
    String? userId,
    String? name,
    String? phoneNumber,
    bool? isTrusted,
    bool? isBlocked,
    DateTime? createdAt,
    DateTime? lastContactAt,
    String? photoUrl,
    String? notes,
  }) {
    return Contact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isTrusted: isTrusted ?? this.isTrusted,
      isBlocked: isBlocked ?? this.isBlocked,
      createdAt: createdAt ?? this.createdAt,
      lastContactAt: lastContactAt ?? this.lastContactAt,
      photoUrl: photoUrl ?? this.photoUrl,
      notes: notes ?? this.notes,
    );
  }

  // Obter iniciais do nome para avatar
  String get initials {
    final words = name.trim().split(' ');
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words[0].isNotEmpty ? words[0][0].toUpperCase() : '?';
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  // Verificar se é contato recente (últimos 30 dias)
  bool get isRecentContact {
    if (lastContactAt == null) return false;
    final now = DateTime.now();
    final difference = now.difference(lastContactAt!);
    return difference.inDays <= 30;
  }

  // Verificar se é contato frequente (mais de 10 interações)
  bool get isFrequentContact {
    // Esta lógica seria implementada com base no histórico de chamadas/mensagens
    // Por enquanto, retorna false como placeholder
    return false;
  }

  // Formatar número de telefone
  String get formattedPhoneNumber {
    if (phoneNumber.startsWith('+55')) {
      // Formato brasileiro: +55 (11) 99999-9999
      final cleanNumber = phoneNumber.replaceAll('+55', '');
      if (cleanNumber.length == 11) {
        return '+55 (${cleanNumber.substring(0, 2)}) ${cleanNumber.substring(2, 7)}-${cleanNumber.substring(7)}';
      } else if (cleanNumber.length == 10) {
        return '+55 (${cleanNumber.substring(0, 2)}) ${cleanNumber.substring(2, 6)}-${cleanNumber.substring(6)}';
      }
    }
    return phoneNumber;
  }

  // Verificar se o número é válido
  bool get isValidPhoneNumber {
    // Regex básico para números brasileiros
    final brazilianRegex = RegExp(r'^\+55[1-9][0-9]{8,9}$');
    final internationalRegex = RegExp(r'^\+[1-9][0-9]{7,14}$');
    
    return brazilianRegex.hasMatch(phoneNumber) || 
           internationalRegex.hasMatch(phoneNumber);
  }

  // Obter status do contato
  String get status {
    if (isBlocked) return 'Bloqueado';
    if (isTrusted) return 'Confiável';
    if (isRecentContact) return 'Recente';
    return 'Normal';
  }

  // Obter cor do status
  String get statusColor {
    if (isBlocked) return 'red';
    if (isTrusted) return 'green';
    if (isRecentContact) return 'blue';
    return 'grey';
  }

  // Verificar se corresponde a uma busca
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return name.toLowerCase().contains(lowerQuery) ||
           phoneNumber.contains(query) ||
           (notes?.toLowerCase().contains(lowerQuery) ?? false);
  }

  // Obter informações de contato para exibição
  Map<String, String> get displayInfo {
    return {
      'name': name,
      'phone': formattedPhoneNumber,
      'status': status,
      'initials': initials,
      'notes': notes ?? '',
    };
  }

  @override
  String toString() {
    return 'Contact{id: $id, name: $name, phoneNumber: $phoneNumber, isTrusted: $isTrusted, isBlocked: $isBlocked}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Contact && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}