import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'ml_spam_detector.dart';
import 'behavioral_analyzer.dart';
import 'spam_detection_service.dart';
import '../database/repository.dart';

/// Detector de spam integrado que combina ML, análise comportamental e regras
class IntegratedSpamDetector {
  static final IntegratedSpamDetector _instance = IntegratedSpamDetector._internal();
  factory IntegratedSpamDetector() => _instance;
  IntegratedSpamDetector._internal();

  // Componentes de detecção
  late final MLSpamDetector _mlDetector;
  late final BehavioralAnalyzer _behavioralAnalyzer;
  late final SpamDetectionService _ruleBasedDetector;
  late final Repository _repository;
  
  // Configurações de pesos para combinação de scores
  static const double _mlWeight = 0.4;
  static const double _behavioralWeight = 0.35;
  static const double _ruleBasedWeight = 0.25;
  
  // Thresholds para diferentes níveis
  static const double _spamThreshold = 0.7;
  static const double _suspiciousThreshold = 0.5;
  static const double _cleanThreshold = 0.3;
  
  // Cache de resultados para otimização
  final Map<String, CachedDetectionResult> _cache = {};
  static const Duration _cacheExpiry = Duration(hours: 1);
  
  bool _isInitialized = false;
  
  /// Inicializa o detector integrado
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _mlDetector = MLSpamDetector();
      _behavioralAnalyzer = BehavioralAnalyzer();
      _ruleBasedDetector = SpamDetectionService();
      _repository = Repository();
      
      // Inicializa todos os componentes
      await Future.wait([
        _mlDetector.initialize(),
        _behavioralAnalyzer.initialize(),
        _ruleBasedDetector.initialize(),
      ]);
      
      _isInitialized = true;
      debugPrint('Detector de spam integrado inicializado com sucesso');
    } catch (e) {
      debugPrint('Erro ao inicializar detector integrado: $e');
      rethrow;
    }
  }
  
  /// Detecta spam em chamadas usando todos os métodos disponíveis
  Future<IntegratedSpamResult> detectCallSpam({
    required String phoneNumber,
    String? contactName,
    DateTime? timestamp,
    int? duration,
  }) async {
    await _ensureInitialized();
    
    try {
      // Verifica cache primeiro
      final cacheKey = 'call_${phoneNumber}_${contactName ?? "unknown"}';
      final cached = _getCachedResult(cacheKey);
      if (cached != null) {
        return cached.result;
      }
      
      // Registra atividade para análise comportamental
      await _behavioralAnalyzer.recordActivity(ActivityRecord(
        phoneNumber: phoneNumber,
        timestamp: timestamp ?? DateTime.now(),
        type: ActivityType.call,
        duration: duration,
      ));
      
      // Executa detecções em paralelo
      final futures = await Future.wait([
        _mlDetector.calculateCallSpamScore(
          phoneNumber,
          timestamp ?? DateTime.now(),
          contactName: contactName,
          duration: duration,
        ),
        _behavioralAnalyzer.analyzeBehavior(phoneNumber),
        _ruleBasedDetector.calculateSpamScore(
          phoneNumber: phoneNumber,
          contactName: contactName,
          callType: CallType.incoming,
        ),
      ]);
      
      final mlScore = futures[0] as double;
      final behaviorAnalysis = futures[1] as BehaviorAnalysis?;
      final ruleScore = futures[2] as double;
      
      // Combina os scores
      final combinedScore = _combineScores(
        mlScore: mlScore,
        behaviorScore: behaviorAnalysis?.suspicionLevel.toScore() ?? 0.0,
        ruleScore: ruleScore,
        confidence: behaviorAnalysis?.confidence ?? 0.0,
      );
      
      // Cria resultado integrado
      final result = IntegratedSpamResult(
        phoneNumber: phoneNumber,
        finalScore: combinedScore,
        spamLevel: _getSpamLevel(combinedScore),
        confidence: _calculateOverallConfidence(mlScore, behaviorAnalysis, ruleScore),
        mlScore: mlScore,
        behaviorScore: behaviorAnalysis?.suspicionLevel.toScore() ?? 0.0,
        ruleScore: ruleScore,
        behaviorAnalysis: behaviorAnalysis,
        detectionReasons: _generateDetectionReasons(
          mlScore: mlScore,
          behaviorAnalysis: behaviorAnalysis,
          ruleScore: ruleScore,
        ),
        recommendations: _generateRecommendations(combinedScore, behaviorAnalysis),
        timestamp: DateTime.now(),
      );
      
      // Armazena no cache
      _cacheResult(cacheKey, result);
      
      // Salva resultado no histórico se for spam
      if (result.spamLevel != SpamLevel.clean) {
        await _saveDetectionResult(result, DetectionType.call);
      }
      
      return result;
    } catch (e) {
      debugPrint('Erro na detecção integrada de spam em chamada: $e');
      return _createErrorResult(phoneNumber);
    }
  }
  
  /// Detecta spam em SMS usando todos os métodos disponíveis
  Future<IntegratedSpamResult> detectSmsSpam({
    required String phoneNumber,
    required String content,
    String? sender,
    DateTime? timestamp,
  }) async {
    await _ensureInitialized();
    
    try {
      // Verifica cache primeiro
      final cacheKey = 'sms_${phoneNumber}_${content.hashCode}';
      final cached = _getCachedResult(cacheKey);
      if (cached != null) {
        return cached.result;
      }
      
      // Registra atividade para análise comportamental
      await _behavioralAnalyzer.recordActivity(ActivityRecord(
        phoneNumber: phoneNumber,
        timestamp: timestamp ?? DateTime.now(),
        type: ActivityType.sms,
        content: content,
      ));
      
      // Executa detecções em paralelo
      final futures = await Future.wait([
        _mlDetector.calculateSmsSpamScore(
          phoneNumber,
          content,
          timestamp ?? DateTime.now(),
        ),
        _behavioralAnalyzer.analyzeBehavior(phoneNumber),
        _ruleBasedDetector.calculateSmsSpamScore(
          sender: phoneNumber,
          content: content,
          messageType: MessageType.received,
        ),
      ]);
      
      final mlScore = futures[0] as double;
      final behaviorAnalysis = futures[1] as BehaviorAnalysis?;
      final ruleScore = futures[2] as double;
      
      // Combina os scores
      final combinedScore = _combineScores(
        mlScore: mlScore,
        behaviorScore: behaviorAnalysis?.suspicionLevel.toScore() ?? 0.0,
        ruleScore: ruleScore,
        confidence: behaviorAnalysis?.confidence ?? 0.0,
      );
      
      // Cria resultado integrado
      final result = IntegratedSpamResult(
        phoneNumber: phoneNumber,
        finalScore: combinedScore,
        spamLevel: _getSpamLevel(combinedScore),
        confidence: _calculateOverallConfidence(mlScore, behaviorAnalysis, ruleScore),
        mlScore: mlScore,
        behaviorScore: behaviorAnalysis?.suspicionLevel.toScore() ?? 0.0,
        ruleScore: ruleScore,
        behaviorAnalysis: behaviorAnalysis,
        detectionReasons: _generateDetectionReasons(
          mlScore: mlScore,
          behaviorAnalysis: behaviorAnalysis,
          ruleScore: ruleScore,
          content: content,
        ),
        recommendations: _generateRecommendations(combinedScore, behaviorAnalysis),
        timestamp: DateTime.now(),
        content: content,
      );
      
      // Armazena no cache
      _cacheResult(cacheKey, result);
      
      // Salva resultado no histórico se for spam
      if (result.spamLevel != SpamLevel.clean) {
        await _saveDetectionResult(result, DetectionType.sms);
      }
      
      return result;
    } catch (e) {
      debugPrint('Erro na detecção integrada de spam em SMS: $e');
      return _createErrorResult(phoneNumber, content: content);
    }
  }
  
  /// Combina scores de diferentes métodos de detecção
  double _combineScores({
    required double mlScore,
    required double behaviorScore,
    required double ruleScore,
    required double confidence,
  }) {
    // Ajusta pesos baseado na confiança da análise comportamental
    double adjustedMlWeight = _mlWeight;
    double adjustedBehaviorWeight = _behavioralWeight * confidence;
    double adjustedRuleWeight = _ruleBasedWeight;
    
    // Redistribui pesos se a confiança comportamental for baixa
    if (confidence < 0.5) {
      final redistribution = _behavioralWeight - adjustedBehaviorWeight;
      adjustedMlWeight += redistribution * 0.6;
      adjustedRuleWeight += redistribution * 0.4;
    }
    
    // Normaliza pesos
    final totalWeight = adjustedMlWeight + adjustedBehaviorWeight + adjustedRuleWeight;
    adjustedMlWeight /= totalWeight;
    adjustedBehaviorWeight /= totalWeight;
    adjustedRuleWeight /= totalWeight;
    
    // Calcula score combinado
    final combinedScore = (mlScore * adjustedMlWeight) +
                         (behaviorScore * adjustedBehaviorWeight) +
                         (ruleScore * adjustedRuleWeight);
    
    return combinedScore.clamp(0.0, 1.0);
  }
  
  /// Calcula confiança geral da detecção
  double _calculateOverallConfidence(
    double mlScore,
    BehaviorAnalysis? behaviorAnalysis,
    double ruleScore,
  ) {
    double confidence = 0.0;
    
    // Confiança baseada na consistência entre métodos
    final scores = [mlScore, behaviorAnalysis?.suspicionLevel.toScore() ?? 0.0, ruleScore];
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;
    final variance = scores.map((s) => pow(s - avgScore, 2)).reduce((a, b) => a + b) / scores.length;
    
    // Baixa variância = alta consistência = alta confiança
    confidence += (1.0 - variance).clamp(0.0, 1.0) * 0.4;
    
    // Confiança da análise comportamental
    if (behaviorAnalysis != null) {
      confidence += behaviorAnalysis.confidence * 0.3;
    }
    
    // Confiança baseada na magnitude do score
    if (avgScore > 0.8 || avgScore < 0.2) {
      confidence += 0.3; // Scores extremos são mais confiáveis
    } else {
      confidence += 0.1;
    }
    
    return confidence.clamp(0.0, 1.0);
  }
  
  /// Determina o nível de spam baseado no score
  SpamLevel _getSpamLevel(double score) {
    if (score >= _spamThreshold) return SpamLevel.spam;
    if (score >= _suspiciousThreshold) return SpamLevel.suspicious;
    if (score >= _cleanThreshold) return SpamLevel.questionable;
    return SpamLevel.clean;
  }
  
  /// Gera razões para a detecção
  List<String> _generateDetectionReasons({
    required double mlScore,
    required BehaviorAnalysis? behaviorAnalysis,
    required double ruleScore,
    String? content,
  }) {
    List<String> reasons = [];
    
    // Razões do ML
    if (mlScore > 0.7) {
      reasons.add('Padrões de spam detectados pelo modelo de ML');
    }
    
    // Razões comportamentais
    if (behaviorAnalysis != null && behaviorAnalysis.reasons.isNotEmpty) {
      reasons.addAll(behaviorAnalysis.reasons);
    }
    
    // Razões baseadas em regras
    if (ruleScore > 0.6) {
      reasons.add('Corresponde a regras de bloqueio configuradas');
    }
    
    // Análise de conteúdo específica
    if (content != null) {
      if (content.toLowerCase().contains('grátis') || 
          content.toLowerCase().contains('promoção')) {
        reasons.add('Contém palavras-chave suspeitas');
      }
      
      if (RegExp(r'http[s]?://').hasMatch(content)) {
        reasons.add('Contém links suspeitos');
      }
    }
    
    return reasons;
  }
  
  /// Gera recomendações baseadas na detecção
  List<String> _generateRecommendations(
    double score,
    BehaviorAnalysis? behaviorAnalysis,
  ) {
    List<String> recommendations = [];
    
    if (score >= _spamThreshold) {
      recommendations.add('Bloquear número imediatamente');
      recommendations.add('Reportar como spam');
      recommendations.add('Adicionar à lista negra');
    } else if (score >= _suspiciousThreshold) {
      recommendations.add('Monitorar atividade');
      recommendations.add('Considerar bloqueio temporário');
      recommendations.add('Verificar manualmente');
    } else if (score >= _cleanThreshold) {
      recommendations.add('Manter observação');
      recommendations.add('Aguardar mais evidências');
    } else {
      recommendations.add('Número parece legítimo');
      recommendations.add('Permitir comunicação');
    }
    
    // Adiciona recomendações comportamentais
    if (behaviorAnalysis?.recommendations.isNotEmpty == true) {
      recommendations.addAll(behaviorAnalysis!.recommendations);
    }
    
    return recommendations.toSet().toList(); // Remove duplicatas
  }
  
  /// Treina o modelo com feedback do usuário
  Future<void> trainWithFeedback({
    required String phoneNumber,
    required bool isSpam,
    String? content,
    DetectionType type = DetectionType.call,
  }) async {
    await _ensureInitialized();
    
    try {
      // Treina o modelo ML
      await _mlDetector.addUserFeedback(
        phoneNumber,
        DateTime.now(),
        isSpam,
        content: content,
      );
      
      // Atualiza configurações baseadas no feedback
      await _updateDetectionSettings(phoneNumber, isSpam, type);
      
      // Limpa cache relacionado
      _clearCacheForNumber(phoneNumber);
      
      debugPrint('Feedback processado para $phoneNumber: ${isSpam ? "spam" : "legítimo"}');
    } catch (e) {
      debugPrint('Erro ao processar feedback: $e');
    }
  }
  
  /// Atualiza configurações de detecção baseado no feedback
  Future<void> _updateDetectionSettings(
    String phoneNumber,
    bool isSpam,
    DetectionType type,
  ) async {
    // Implementa lógica para ajustar thresholds e pesos
    // baseado no feedback do usuário
  }
  
  /// Obtém estatísticas de detecção
  Future<DetectionStats> getDetectionStats() async {
    await _ensureInitialized();
    
    try {
      final mlStats = _mlDetector.getModelStats();
      final behaviorStats = _behavioralAnalyzer.getStats();
      
      // Busca estatísticas do banco de dados
      final stats = await _repository.getStatistics('current_user');
      // Usar estatísticas existentes do repository
      final totalDetections = stats['totalBlocked'] ?? 0;
      final spamBlocked = stats['totalCalls'] ?? 0;
      
      return DetectionStats(
        totalDetections: totalDetections,
        spamDetected: spamBlocked,
        falsePositives: 0, // Implementar baseado no feedback
        falseNegatives: 0, // Implementar baseado no feedback
        accuracy: _calculateAccuracy(),
        mlModelAccuracy: mlStats.accuracy,
        behaviorProfilesCount: behaviorStats.totalProfiles,
        cacheHitRate: _calculateCacheHitRate(),
      );
    } catch (e) {
      debugPrint('Erro ao obter estatísticas: $e');
      return DetectionStats.empty();
    }
  }
  
  /// Calcula precisão geral do sistema
  double _calculateAccuracy() {
    // Implementa cálculo baseado no feedback do usuário
    return 0.85; // Placeholder
  }
  
  /// Calcula taxa de acerto do cache
  double _calculateCacheHitRate() {
    // Implementa cálculo da eficiência do cache
    return 0.75; // Placeholder
  }
  
  /// Verifica resultado no cache
  CachedDetectionResult? _getCachedResult(String key) {
    final cached = _cache[key];
    if (cached != null && 
        DateTime.now().difference(cached.timestamp) < _cacheExpiry) {
      return cached;
    }
    
    // Remove cache expirado
    if (cached != null) {
      _cache.remove(key);
    }
    
    return null;
  }
  
  /// Armazena resultado no cache
  void _cacheResult(String key, IntegratedSpamResult result) {
    _cache[key] = CachedDetectionResult(
      result: result,
      timestamp: DateTime.now(),
    );
    
    // Limita tamanho do cache
    if (_cache.length > 1000) {
      final oldestKey = _cache.entries
          .reduce((a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b)
          .key;
      _cache.remove(oldestKey);
    }
  }
  
  /// Limpa cache para um número específico
  void _clearCacheForNumber(String phoneNumber) {
    _cache.removeWhere((key, value) => 
        value.result.phoneNumber == phoneNumber);
  }
  
  /// Salva resultado de detecção no banco
  Future<void> _saveDetectionResult(
    IntegratedSpamResult result,
    DetectionType type,
  ) async {
    // Implementa salvamento no banco de dados
    // para histórico e análise posterior
  }
  
  /// Cria resultado de erro
  IntegratedSpamResult _createErrorResult(String phoneNumber, {String? content}) {
    return IntegratedSpamResult(
      phoneNumber: phoneNumber,
      finalScore: 0.0,
      spamLevel: SpamLevel.unknown,
      confidence: 0.0,
      mlScore: 0.0,
      behaviorScore: 0.0,
      ruleScore: 0.0,
      behaviorAnalysis: null,
      detectionReasons: ['Erro na detecção'],
      recommendations: ['Verificar manualmente'],
      timestamp: DateTime.now(),
      content: content,
    );
  }
  
  /// Garante que o detector está inicializado
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}

/// Resultado integrado de detecção de spam
class IntegratedSpamResult {
  final String phoneNumber;
  final double finalScore;
  final SpamLevel spamLevel;
  final double confidence;
  final double mlScore;
  final double behaviorScore;
  final double ruleScore;
  final BehaviorAnalysis? behaviorAnalysis;
  final List<String> detectionReasons;
  final List<String> recommendations;
  final DateTime timestamp;
  final String? content;
  
  const IntegratedSpamResult({
    required this.phoneNumber,
    required this.finalScore,
    required this.spamLevel,
    required this.confidence,
    required this.mlScore,
    required this.behaviorScore,
    required this.ruleScore,
    required this.behaviorAnalysis,
    required this.detectionReasons,
    required this.recommendations,
    required this.timestamp,
    this.content,
  });
  
  /// Verifica se deve ser bloqueado
  bool get shouldBlock => spamLevel == SpamLevel.spam;
  
  /// Verifica se é suspeito
  bool get isSuspicious => spamLevel == SpamLevel.suspicious || spamLevel == SpamLevel.spam;
  
  /// Obtém descrição do nível de spam
  String get spamLevelDescription {
    switch (spamLevel) {
      case SpamLevel.spam:
        return 'Spam confirmado';
      case SpamLevel.suspicious:
        return 'Suspeito';
      case SpamLevel.questionable:
        return 'Questionável';
      case SpamLevel.clean:
        return 'Limpo';
      case SpamLevel.unknown:
        return 'Desconhecido';
    }
  }
}

/// Níveis de spam
enum SpamLevel {
  spam,
  suspicious,
  questionable,
  clean,
  unknown,
}

/// Tipos de detecção
enum DetectionType {
  call,
  sms,
}

/// Resultado em cache
class CachedDetectionResult {
  final IntegratedSpamResult result;
  final DateTime timestamp;
  
  const CachedDetectionResult({
    required this.result,
    required this.timestamp,
  });
}

/// Estatísticas de detecção
class DetectionStats {
  final int totalDetections;
  final int spamDetected;
  final int falsePositives;
  final int falseNegatives;
  final double accuracy;
  final double mlModelAccuracy;
  final int behaviorProfilesCount;
  final double cacheHitRate;
  
  const DetectionStats({
    required this.totalDetections,
    required this.spamDetected,
    required this.falsePositives,
    required this.falseNegatives,
    required this.accuracy,
    required this.mlModelAccuracy,
    required this.behaviorProfilesCount,
    required this.cacheHitRate,
  });
  
  factory DetectionStats.empty() {
    return const DetectionStats(
      totalDetections: 0,
      spamDetected: 0,
      falsePositives: 0,
      falseNegatives: 0,
      accuracy: 0.0,
      mlModelAccuracy: 0.0,
      behaviorProfilesCount: 0,
      cacheHitRate: 0.0,
    );
  }
}

/// Extensão para converter SuspicionLevel em score
extension SuspicionLevelExtension on SuspicionLevel {
  double toScore() {
    switch (this) {
      case SuspicionLevel.high:
        return 0.9;
      case SuspicionLevel.medium:
        return 0.6;
      case SuspicionLevel.low:
        return 0.3;
      case SuspicionLevel.clean:
        return 0.1;
      case SuspicionLevel.unknown:
        return 0.0;
    }
  }
}