import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Analisador comportamental para detecção de padrões suspeitos
class BehavioralAnalyzer {
  static final BehavioralAnalyzer _instance = BehavioralAnalyzer._internal();
  factory BehavioralAnalyzer() => _instance;
  BehavioralAnalyzer._internal();

  // Cache de análises comportamentais
  final Map<String, BehaviorProfile> _behaviorProfiles = {};
  
  // Histórico de atividades para análise
  final List<ActivityRecord> _activityHistory = [];
  
  // Configurações de análise
  static const int _maxHistorySize = 10000;
  static const int _minDataPointsForAnalysis = 10;
  static const Duration _analysisWindow = Duration(days: 30);
  
  /// Inicializa o analisador comportamental
  Future<void> initialize() async {
    try {
      await _loadBehaviorProfiles();
      _cleanOldData();
    } catch (e) {
      debugPrint('Erro ao inicializar analisador comportamental: $e');
    }
  }
  
  /// Carrega perfis comportamentais salvos
  Future<void> _loadBehaviorProfiles() async {
    // Em uma implementação real, carregaria do banco de dados
    // Por enquanto, inicializa vazio
  }
  
  /// Remove dados antigos para otimizar performance
  void _cleanOldData() {
    final cutoffDate = DateTime.now().subtract(_analysisWindow);
    _activityHistory.removeWhere((record) => record.timestamp.isBefore(cutoffDate));
    
    // Limita o tamanho do histórico
    if (_activityHistory.length > _maxHistorySize) {
      _activityHistory.removeRange(0, _activityHistory.length - _maxHistorySize);
    }
  }
  
  /// Registra uma nova atividade para análise
  Future<void> recordActivity(ActivityRecord record) async {
    try {
      _activityHistory.add(record);
      await _updateBehaviorProfile(record);
      _cleanOldData();
    } catch (e) {
      debugPrint('Erro ao registrar atividade: $e');
    }
  }
  
  /// Atualiza o perfil comportamental de um número
  Future<void> _updateBehaviorProfile(ActivityRecord record) async {
    final phoneNumber = record.phoneNumber;
    
    if (!_behaviorProfiles.containsKey(phoneNumber)) {
      _behaviorProfiles[phoneNumber] = BehaviorProfile(
        phoneNumber: phoneNumber,
        firstSeen: record.timestamp,
        lastSeen: record.timestamp,
        totalInteractions: 0,
        callPatterns: CallPattern(),
        smsPatterns: SmsPattern(),
        timePatterns: TimePattern(),
        suspicionScore: 0.0,
      );
    }
    
    final profile = _behaviorProfiles[phoneNumber]!;
    
    // Atualiza informações básicas
    profile.lastSeen = record.timestamp;
    profile.totalInteractions++;
    
    // Atualiza padrões específicos
    switch (record.type) {
      case ActivityType.call:
        _updateCallPattern(profile.callPatterns, record);
        break;
      case ActivityType.sms:
        _updateSmsPattern(profile.smsPatterns, record);
        break;
    }
    
    // Atualiza padrões temporais
    _updateTimePattern(profile.timePatterns, record);
    
    // Recalcula score de suspeição
    profile.suspicionScore = _calculateSuspicionScore(profile);
  }
  
  /// Atualiza padrões de chamada
  void _updateCallPattern(CallPattern pattern, ActivityRecord record) {
    pattern.totalCalls++;
    
    if (record.duration != null) {
      pattern.totalDuration += record.duration!;
      pattern.averageDuration = pattern.totalDuration / pattern.totalCalls;
      
      // Atualiza distribuição de duração
      if (record.duration! == 0) {
        pattern.missedCalls++;
      } else if (record.duration! < 10) {
        pattern.shortCalls++;
      } else if (record.duration! > 300) {
        pattern.longCalls++;
      }
    }
    
    // Calcula frequência
    final now = DateTime.now();
    final daysDiff = now.difference(record.timestamp).inDays;
    if (daysDiff > 0) {
      pattern.callsPerDay = pattern.totalCalls / daysDiff;
    }
  }
  
  /// Atualiza padrões de SMS
  void _updateSmsPattern(SmsPattern pattern, ActivityRecord record) {
    pattern.totalSms++;
    
    if (record.content != null) {
      final content = record.content!;
      pattern.totalCharacters += content.length;
      pattern.averageLength = pattern.totalCharacters / pattern.totalSms;
      
      // Analisa características do conteúdo
      if (_hasUrls(content)) {
        pattern.messagesWithUrls++;
      }
      
      if (_hasNumbers(content)) {
        pattern.messagesWithNumbers++;
      }
      
      if (_isAllCaps(content)) {
        pattern.allCapsMessages++;
      }
      
      // Atualiza palavras-chave mais comuns
      _updateKeywords(pattern, content);
    }
    
    // Calcula frequência
    final now = DateTime.now();
    final daysDiff = now.difference(record.timestamp).inDays;
    if (daysDiff > 0) {
      pattern.smsPerDay = pattern.totalSms / daysDiff;
    }
  }
  
  /// Atualiza padrões temporais
  void _updateTimePattern(TimePattern pattern, ActivityRecord record) {
    final hour = record.timestamp.hour;
    final dayOfWeek = record.timestamp.weekday;
    
    // Atualiza distribuição por hora
    pattern.hourDistribution[hour] = (pattern.hourDistribution[hour] ?? 0) + 1;
    
    // Atualiza distribuição por dia da semana
    pattern.dayDistribution[dayOfWeek] = (pattern.dayDistribution[dayOfWeek] ?? 0) + 1;
    
    // Verifica se é horário comercial
    if (hour >= 9 && hour <= 18 && dayOfWeek <= 5) {
      pattern.businessHoursActivity++;
    } else {
      pattern.offHoursActivity++;
    }
    
    // Calcula intervalos entre atividades
    if (pattern.lastActivityTime != null) {
      final interval = record.timestamp.difference(pattern.lastActivityTime!).inMinutes;
      pattern.intervals.add(interval);
      
      // Mantém apenas os últimos 100 intervalos
      if (pattern.intervals.length > 100) {
        pattern.intervals.removeAt(0);
      }
    }
    
    pattern.lastActivityTime = record.timestamp;
  }
  
  /// Atualiza palavras-chave mais comuns
  void _updateKeywords(SmsPattern pattern, String content) {
    final words = content.toLowerCase().split(RegExp(r'\W+'));
    
    for (final word in words) {
      if (word.length > 3) {
        pattern.commonKeywords[word] = (pattern.commonKeywords[word] ?? 0) + 1;
      }
    }
    
    // Mantém apenas as 50 palavras mais comuns
    if (pattern.commonKeywords.length > 50) {
      final sortedEntries = pattern.commonKeywords.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      pattern.commonKeywords.clear();
      for (int i = 0; i < 50 && i < sortedEntries.length; i++) {
        pattern.commonKeywords[sortedEntries[i].key] = sortedEntries[i].value;
      }
    }
  }
  
  /// Calcula score de suspeição baseado no comportamento
  double _calculateSuspicionScore(BehaviorProfile profile) {
    double score = 0.0;
    
    // Análise de frequência anômala
    score += _analyzeFrequencyAnomalies(profile);
    
    // Análise de padrões temporais suspeitos
    score += _analyzeTimePatterns(profile);
    
    // Análise de conteúdo suspeito
    score += _analyzeContentPatterns(profile);
    
    // Análise de comportamento de chamadas
    score += _analyzeCallBehavior(profile);
    
    return score.clamp(0.0, 1.0);
  }
  
  /// Analisa anomalias de frequência
  double _analyzeFrequencyAnomalies(BehaviorProfile profile) {
    double score = 0.0;
    
    // Frequência muito alta de chamadas
    if (profile.callPatterns.callsPerDay > 10) {
      score += 0.3;
    }
    
    // Frequência muito alta de SMS
    if (profile.smsPatterns.smsPerDay > 20) {
      score += 0.3;
    }
    
    // Atividade muito concentrada em pouco tempo
    final daysSinceFirst = DateTime.now().difference(profile.firstSeen).inDays;
    if (daysSinceFirst < 7 && profile.totalInteractions > 50) {
      score += 0.4;
    }
    
    return score;
  }
  
  /// Analisa padrões temporais suspeitos
  double _analyzeTimePatterns(BehaviorProfile profile) {
    double score = 0.0;
    
    // Atividade predominante fora do horário comercial
    final totalActivity = profile.timePatterns.businessHoursActivity + 
                         profile.timePatterns.offHoursActivity;
    
    if (totalActivity > 0) {
      final offHoursRatio = profile.timePatterns.offHoursActivity / totalActivity;
      if (offHoursRatio > 0.8) {
        score += 0.3;
      }
    }
    
    // Intervalos muito regulares (comportamento automatizado)
    if (profile.timePatterns.intervals.length > 10) {
      final avgInterval = profile.timePatterns.intervals.reduce((a, b) => a + b) / 
                         profile.timePatterns.intervals.length;
      
      final variance = _calculateVariance(profile.timePatterns.intervals, avgInterval);
      
      // Baixa variância indica comportamento automatizado
      if (variance < 10 && avgInterval < 60) {
        score += 0.4;
      }
    }
    
    return score;
  }
  
  /// Analisa padrões de conteúdo suspeitos
  double _analyzeContentPatterns(BehaviorProfile profile) {
    double score = 0.0;
    
    final smsPattern = profile.smsPatterns;
    
    if (smsPattern.totalSms > 0) {
      // Alta proporção de mensagens com URLs
      final urlRatio = smsPattern.messagesWithUrls / smsPattern.totalSms;
      if (urlRatio > 0.5) {
        score += 0.4;
      }
      
      // Alta proporção de mensagens em maiúsculas
      final capsRatio = smsPattern.allCapsMessages / smsPattern.totalSms;
      if (capsRatio > 0.3) {
        score += 0.2;
      }
      
      // Mensagens muito curtas ou muito longas
      if (smsPattern.averageLength < 10 || smsPattern.averageLength > 200) {
        score += 0.2;
      }
      
      // Palavras-chave suspeitas
      final suspiciousKeywords = ['gratis', 'promocao', 'urgente', 'clique', 'ganhe'];
      for (final keyword in suspiciousKeywords) {
        if (smsPattern.commonKeywords.containsKey(keyword)) {
          score += 0.1;
        }
      }
    }
    
    return score;
  }
  
  /// Analisa comportamento de chamadas suspeito
  double _analyzeCallBehavior(BehaviorProfile profile) {
    double score = 0.0;
    
    final callPattern = profile.callPatterns;
    
    if (callPattern.totalCalls > 0) {
      // Alta proporção de chamadas perdidas
      final missedRatio = callPattern.missedCalls / callPattern.totalCalls;
      if (missedRatio > 0.8) {
        score += 0.3;
      }
      
      // Alta proporção de chamadas muito curtas
      final shortRatio = callPattern.shortCalls / callPattern.totalCalls;
      if (shortRatio > 0.7) {
        score += 0.2;
      }
      
      // Duração média muito baixa
      if (callPattern.averageDuration < 5) {
        score += 0.2;
      }
    }
    
    return score;
  }
  
  /// Calcula variância de uma lista de números
  double _calculateVariance(List<int> values, double mean) {
    if (values.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (final value in values) {
      sum += pow(value - mean, 2);
    }
    
    return sum / values.length;
  }
  
  /// Verifica se o texto contém URLs
  bool _hasUrls(String text) {
    return RegExp(r'http[s]?://[^\s]+|www\.[^\s]+').hasMatch(text);
  }
  
  /// Verifica se o texto contém muitos números
  bool _hasNumbers(String text) {
    final numberCount = text.split('').where((c) => '0123456789'.contains(c)).length;
    return numberCount > text.length * 0.3;
  }
  
  /// Verifica se o texto está todo em maiúsculas
  bool _isAllCaps(String text) {
    if (text.length < 10) return false;
    return text == text.toUpperCase() && text != text.toLowerCase();
  }
  
  /// Obtém análise comportamental de um número
  Future<BehaviorAnalysis?> analyzeBehavior(String phoneNumber) async {
    try {
      final profile = _behaviorProfiles[phoneNumber];
      if (profile == null) return null;
      
      // Verifica se há dados suficientes para análise
      if (profile.totalInteractions < _minDataPointsForAnalysis) {
        return BehaviorAnalysis(
          phoneNumber: phoneNumber,
          suspicionLevel: SuspicionLevel.unknown,
          confidence: 0.0,
          reasons: ['Dados insuficientes para análise'],
          recommendations: ['Aguardar mais interações'],
        );
      }
      
      final suspicionLevel = _getSuspicionLevel(profile.suspicionScore);
      final reasons = _generateReasons(profile);
      final recommendations = _generateRecommendations(profile, suspicionLevel);
      
      return BehaviorAnalysis(
        phoneNumber: phoneNumber,
        suspicionLevel: suspicionLevel,
        confidence: _calculateConfidence(profile),
        reasons: reasons,
        recommendations: recommendations,
      );
    } catch (e) {
      debugPrint('Erro ao analisar comportamento: $e');
      return null;
    }
  }
  
  /// Determina o nível de suspeição
  SuspicionLevel _getSuspicionLevel(double score) {
    if (score >= 0.8) return SuspicionLevel.high;
    if (score >= 0.6) return SuspicionLevel.medium;
    if (score >= 0.3) return SuspicionLevel.low;
    return SuspicionLevel.clean;
  }
  
  /// Gera razões para o nível de suspeição
  List<String> _generateReasons(BehaviorProfile profile) {
    List<String> reasons = [];
    
    if (profile.callPatterns.callsPerDay > 10) {
      reasons.add('Frequência muito alta de chamadas');
    }
    
    if (profile.smsPatterns.smsPerDay > 20) {
      reasons.add('Frequência muito alta de SMS');
    }
    
    final totalActivity = profile.timePatterns.businessHoursActivity + 
                         profile.timePatterns.offHoursActivity;
    if (totalActivity > 0) {
      final offHoursRatio = profile.timePatterns.offHoursActivity / totalActivity;
      if (offHoursRatio > 0.8) {
        reasons.add('Atividade predominante fora do horário comercial');
      }
    }
    
    if (profile.smsPatterns.totalSms > 0) {
      final urlRatio = profile.smsPatterns.messagesWithUrls / profile.smsPatterns.totalSms;
      if (urlRatio > 0.5) {
        reasons.add('Alta proporção de mensagens com links');
      }
    }
    
    return reasons;
  }
  
  /// Gera recomendações baseadas na análise
  List<String> _generateRecommendations(BehaviorProfile profile, SuspicionLevel level) {
    List<String> recommendations = [];
    
    switch (level) {
      case SuspicionLevel.high:
        recommendations.add('Bloquear número imediatamente');
        recommendations.add('Reportar como spam');
        break;
      case SuspicionLevel.medium:
        recommendations.add('Monitorar atividade');
        recommendations.add('Considerar bloqueio temporário');
        break;
      case SuspicionLevel.low:
        recommendations.add('Manter observação');
        break;
      case SuspicionLevel.clean:
        recommendations.add('Número parece legítimo');
        break;
      case SuspicionLevel.unknown:
        recommendations.add('Aguardar mais dados');
        break;
    }
    
    return recommendations;
  }
  
  /// Calcula confiança da análise
  double _calculateConfidence(BehaviorProfile profile) {
    // Confiança baseada na quantidade de dados
    final dataPoints = profile.totalInteractions;
    final daysSinceFirst = DateTime.now().difference(profile.firstSeen).inDays;
    
    double confidence = 0.0;
    
    // Mais dados = maior confiança
    if (dataPoints >= 100) {
      confidence += 0.4;
    } else if (dataPoints >= 50) {
      confidence += 0.3;
    } else if (dataPoints >= 20) {
      confidence += 0.2;
    }
    
    // Período de observação mais longo = maior confiança
    if (daysSinceFirst >= 30) {
      confidence += 0.3;
    } else if (daysSinceFirst >= 14) {
      confidence += 0.2;
    } else if (daysSinceFirst >= 7) {
      confidence += 0.1;
    }
    
    // Diversidade de tipos de atividade
    if (profile.callPatterns.totalCalls > 0 && profile.smsPatterns.totalSms > 0) {
      confidence += 0.2;
    }
    
    // Consistência nos padrões
    if (profile.timePatterns.intervals.length > 10) {
      confidence += 0.1;
    }
    
    return confidence.clamp(0.0, 1.0);
  }
  
  /// Obtém estatísticas do analisador
  BehaviorAnalyzerStats getStats() {
    return BehaviorAnalyzerStats(
      totalProfiles: _behaviorProfiles.length,
      totalActivities: _activityHistory.length,
      highSuspicionProfiles: _behaviorProfiles.values
          .where((p) => p.suspicionScore >= 0.8).length,
      mediumSuspicionProfiles: _behaviorProfiles.values
          .where((p) => p.suspicionScore >= 0.6 && p.suspicionScore < 0.8).length,
      cleanProfiles: _behaviorProfiles.values
          .where((p) => p.suspicionScore < 0.3).length,
    );
  }
}

/// Registro de atividade para análise comportamental
class ActivityRecord {
  final String phoneNumber;
  final DateTime timestamp;
  final ActivityType type;
  final int? duration;
  final String? content;
  
  const ActivityRecord({
    required this.phoneNumber,
    required this.timestamp,
    required this.type,
    this.duration,
    this.content,
  });
}

/// Tipos de atividade
enum ActivityType {
  call,
  sms,
}

/// Perfil comportamental de um número
class BehaviorProfile {
  final String phoneNumber;
  final DateTime firstSeen;
  DateTime lastSeen;
  int totalInteractions;
  final CallPattern callPatterns;
  final SmsPattern smsPatterns;
  final TimePattern timePatterns;
  double suspicionScore;
  
  BehaviorProfile({
    required this.phoneNumber,
    required this.firstSeen,
    required this.lastSeen,
    required this.totalInteractions,
    required this.callPatterns,
    required this.smsPatterns,
    required this.timePatterns,
    required this.suspicionScore,
  });
}

/// Padrões de chamada
class CallPattern {
  int totalCalls = 0;
  int totalDuration = 0;
  double averageDuration = 0.0;
  int missedCalls = 0;
  int shortCalls = 0;
  int longCalls = 0;
  double callsPerDay = 0.0;
}

/// Padrões de SMS
class SmsPattern {
  int totalSms = 0;
  int totalCharacters = 0;
  double averageLength = 0.0;
  int messagesWithUrls = 0;
  int messagesWithNumbers = 0;
  int allCapsMessages = 0;
  double smsPerDay = 0.0;
  Map<String, int> commonKeywords = {};
}

/// Padrões temporais
class TimePattern {
  Map<int, int> hourDistribution = {};
  Map<int, int> dayDistribution = {};
  int businessHoursActivity = 0;
  int offHoursActivity = 0;
  List<int> intervals = [];
  DateTime? lastActivityTime;
}

/// Resultado da análise comportamental
class BehaviorAnalysis {
  final String phoneNumber;
  final SuspicionLevel suspicionLevel;
  final double confidence;
  final List<String> reasons;
  final List<String> recommendations;
  
  const BehaviorAnalysis({
    required this.phoneNumber,
    required this.suspicionLevel,
    required this.confidence,
    required this.reasons,
    required this.recommendations,
  });
}

/// Níveis de suspeição
enum SuspicionLevel {
  clean,
  low,
  medium,
  high,
  unknown,
}

/// Estatísticas do analisador comportamental
class BehaviorAnalyzerStats {
  final int totalProfiles;
  final int totalActivities;
  final int highSuspicionProfiles;
  final int mediumSuspicionProfiles;
  final int cleanProfiles;
  
  const BehaviorAnalyzerStats({
    required this.totalProfiles,
    required this.totalActivities,
    required this.highSuspicionProfiles,
    required this.mediumSuspicionProfiles,
    required this.cleanProfiles,
  });
}