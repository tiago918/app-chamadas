import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Sistema avançado de Machine Learning para detecção de spam
class MLSpamDetector {
  static final MLSpamDetector _instance = MLSpamDetector._internal();
  factory MLSpamDetector() => _instance;
  MLSpamDetector._internal();

  // Pesos do modelo neural simples
  late Map<String, double> _phoneWeights;
  late Map<String, double> _contentWeights;
  late Map<String, double> _timeWeights;
  late Map<String, double> _frequencyWeights;
  
  // Bias do modelo
  double _bias = 0.0;
  
  // Taxa de aprendizado
  double _learningRate = 0.01;
  
  // Histórico de feedback para treinamento
  List<TrainingData> _trainingHistory = [];
  
  // Padrões de spam conhecidos
  final List<SpamPattern> _spamPatterns = [
    SpamPattern(
      pattern: r'\b(ganhe|grátis|promoção|oferta|desconto)\b',
      weight: 0.8,
      category: SpamCategory.promotional,
    ),
    SpamPattern(
      pattern: r'\b(urgente|último dia|expire|limitado)\b',
      weight: 0.7,
      category: SpamCategory.urgency,
    ),
    SpamPattern(
      pattern: r'\b(clique|acesse|link|www\.|http)\b',
      weight: 0.6,
      category: SpamCategory.phishing,
    ),
    SpamPattern(
      pattern: r'\b(banco|cartão|conta|senha|cpf)\b',
      weight: 0.9,
      category: SpamCategory.financial,
    ),
    SpamPattern(
      pattern: r'\b(parabéns|sorteio|prêmio|ganhador)\b',
      weight: 0.75,
      category: SpamCategory.lottery,
    ),
  ];
  
  // Prefixos de números suspeitos
  final Map<String, double> _suspiciousNumberPrefixes = {
    '0800': 0.3, // Telemarketing
    '4000': 0.4, // Serviços automatizados
    '4003': 0.4,
    '4004': 0.4,
    '3000': 0.5, // Números virtuais
    '2000': 0.6, // Números temporários
    '1000': 0.7, // Números de teste
  };
  
  /// Inicializa o detector de ML
  Future<void> initialize() async {
    try {
      _initializeWeights();
      await _loadTrainingData();
      _trainModel();
    } catch (e) {
      debugPrint('Erro ao inicializar ML detector: $e');
    }
  }
  
  /// Inicializa os pesos do modelo com valores aleatórios pequenos
  void _initializeWeights() {
    final random = Random();
    
    _phoneWeights = {
      'length': random.nextDouble() * 0.1 - 0.05,
      'prefix_suspicious': random.nextDouble() * 0.1 - 0.05,
      'international': random.nextDouble() * 0.1 - 0.05,
      'shortcode': random.nextDouble() * 0.1 - 0.05,
    };
    
    _contentWeights = {
      'length': random.nextDouble() * 0.1 - 0.05,
      'uppercase_ratio': random.nextDouble() * 0.1 - 0.05,
      'number_ratio': random.nextDouble() * 0.1 - 0.05,
      'special_char_ratio': random.nextDouble() * 0.1 - 0.05,
      'spam_keywords': random.nextDouble() * 0.1 - 0.05,
    };
    
    _timeWeights = {
      'hour': random.nextDouble() * 0.1 - 0.05,
      'day_of_week': random.nextDouble() * 0.1 - 0.05,
      'is_weekend': random.nextDouble() * 0.1 - 0.05,
    };
    
    _frequencyWeights = {
      'calls_per_hour': random.nextDouble() * 0.1 - 0.05,
      'calls_per_day': random.nextDouble() * 0.1 - 0.05,
      'unique_numbers': random.nextDouble() * 0.1 - 0.05,
    };
    
    _bias = random.nextDouble() * 0.1 - 0.05;
  }
  
  /// Carrega dados de treinamento salvos
  Future<void> _loadTrainingData() async {
    // Em uma implementação real, carregaria de um arquivo ou banco de dados
    // Por enquanto, inicializa com dados padrão
    _trainingHistory = [];
  }
  
  /// Treina o modelo com os dados disponíveis
  void _trainModel() {
    if (_trainingHistory.isEmpty) return;
    
    for (int epoch = 0; epoch < 100; epoch++) {
      for (var data in _trainingHistory) {
        _trainSingleExample(data);
      }
    }
  }
  
  /// Treina com um único exemplo usando gradiente descendente
  void _trainSingleExample(TrainingData data) {
    final features = _extractFeatures(data);
    final prediction = _predict(features);
    final error = data.isSpam ? 1.0 - prediction : 0.0 - prediction;
    
    // Atualiza pesos usando gradiente descendente
    _updateWeights(features, error);
  }
  
  /// Atualiza os pesos do modelo
  void _updateWeights(Map<String, double> features, double error) {
    // Atualiza pesos do telefone
    for (var key in _phoneWeights.keys) {
      if (features.containsKey('phone_$key')) {
        _phoneWeights[key] = _phoneWeights[key]! + 
            _learningRate * error * features['phone_$key']!;
      }
    }
    
    // Atualiza pesos do conteúdo
    for (var key in _contentWeights.keys) {
      if (features.containsKey('content_$key')) {
        _contentWeights[key] = _contentWeights[key]! + 
            _learningRate * error * features['content_$key']!;
      }
    }
    
    // Atualiza pesos do tempo
    for (var key in _timeWeights.keys) {
      if (features.containsKey('time_$key')) {
        _timeWeights[key] = _timeWeights[key]! + 
            _learningRate * error * features['time_$key']!;
      }
    }
    
    // Atualiza pesos da frequência
    for (var key in _frequencyWeights.keys) {
      if (features.containsKey('frequency_$key')) {
        _frequencyWeights[key] = _frequencyWeights[key]! + 
            _learningRate * error * features['frequency_$key']!;
      }
    }
    
    // Atualiza bias
    _bias += _learningRate * error;
  }
  
  /// Extrai características para o modelo ML
  Map<String, double> _extractFeatures(TrainingData data) {
    Map<String, double> features = {};
    
    // Características do telefone
    features['phone_length'] = data.phoneNumber.length.toDouble() / 15.0;
    features['phone_prefix_suspicious'] = _getSuspiciousScore(data.phoneNumber);
    features['phone_international'] = data.phoneNumber.startsWith('+') ? 1.0 : 0.0;
    features['phone_shortcode'] = data.phoneNumber.length <= 5 ? 1.0 : 0.0;
    
    // Características do conteúdo (se disponível)
    if (data.content != null) {
      final content = data.content!;
      features['content_length'] = (content.length.toDouble() / 160.0).clamp(0.0, 1.0);
      features['content_uppercase_ratio'] = _getUppercaseRatio(content);
      features['content_number_ratio'] = _getNumberRatio(content);
      features['content_special_char_ratio'] = _getSpecialCharRatio(content);
      features['content_spam_keywords'] = _getSpamKeywordScore(content);
    }
    
    // Características do tempo
    final hour = data.timestamp.hour.toDouble();
    features['time_hour'] = hour / 24.0;
    features['time_day_of_week'] = data.timestamp.weekday.toDouble() / 7.0;
    features['time_is_weekend'] = (data.timestamp.weekday >= 6) ? 1.0 : 0.0;
    
    // Características de frequência (simuladas)
    features['frequency_calls_per_hour'] = 0.1; // Seria calculado com dados reais
    features['frequency_calls_per_day'] = 0.1;
    features['frequency_unique_numbers'] = 0.1;
    
    return features;
  }
  
  /// Faz predição usando o modelo treinado
  double _predict(Map<String, double> features) {
    double sum = _bias;
    
    // Soma ponderada das características
    for (var entry in features.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (key.startsWith('phone_')) {
        final weightKey = key.substring(6);
        if (_phoneWeights.containsKey(weightKey)) {
          sum += _phoneWeights[weightKey]! * value;
        }
      } else if (key.startsWith('content_')) {
        final weightKey = key.substring(8);
        if (_contentWeights.containsKey(weightKey)) {
          sum += _contentWeights[weightKey]! * value;
        }
      } else if (key.startsWith('time_')) {
        final weightKey = key.substring(5);
        if (_timeWeights.containsKey(weightKey)) {
          sum += _timeWeights[weightKey]! * value;
        }
      } else if (key.startsWith('frequency_')) {
        final weightKey = key.substring(10);
        if (_frequencyWeights.containsKey(weightKey)) {
          sum += _frequencyWeights[weightKey]! * value;
        }
      }
    }
    
    // Função sigmoid para normalizar entre 0 e 1
    return 1.0 / (1.0 + exp(-sum));
  }
  
  /// Calcula score de spam para uma chamada
  Future<double> calculateCallSpamScore(
    String phoneNumber,
    DateTime timestamp, {
    String? contactName,
    int? duration,
  }) async {
    try {
      final data = TrainingData(
        phoneNumber: phoneNumber,
        timestamp: timestamp,
        content: null,
        isSpam: false, // Não usado para predição
      );
      
      final features = _extractFeatures(data);
      final mlScore = _predict(features);
      
      // Combina com análise baseada em regras
      final ruleScore = _calculateRuleBasedScore(phoneNumber, null);
      
      // Peso maior para ML se tiver dados de treinamento suficientes
      final mlWeight = _trainingHistory.length > 50 ? 0.7 : 0.3;
      final ruleWeight = 1.0 - mlWeight;
      
      return (mlScore * mlWeight + ruleScore * ruleWeight).clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('Erro ao calcular score ML para chamada: $e');
      return 0.0;
    }
  }
  
  /// Calcula score de spam para SMS
  Future<double> calculateSmsSpamScore(
    String phoneNumber,
    String content,
    DateTime timestamp,
  ) async {
    try {
      final data = TrainingData(
        phoneNumber: phoneNumber,
        timestamp: timestamp,
        content: content,
        isSpam: false, // Não usado para predição
      );
      
      final features = _extractFeatures(data);
      final mlScore = _predict(features);
      
      // Combina com análise baseada em regras
      final ruleScore = _calculateRuleBasedScore(phoneNumber, content);
      
      // Peso maior para ML se tiver dados de treinamento suficientes
      final mlWeight = _trainingHistory.length > 50 ? 0.7 : 0.3;
      final ruleWeight = 1.0 - mlWeight;
      
      return (mlScore * mlWeight + ruleScore * ruleWeight).clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('Erro ao calcular score ML para SMS: $e');
      return 0.0;
    }
  }
  
  /// Adiciona feedback do usuário para treinamento
  Future<void> addUserFeedback(
    String phoneNumber,
    DateTime timestamp,
    bool isSpam, {
    String? content,
  }) async {
    try {
      final data = TrainingData(
        phoneNumber: phoneNumber,
        timestamp: timestamp,
        content: content,
        isSpam: isSpam,
      );
      
      _trainingHistory.add(data);
      
      // Treina com o novo exemplo
      _trainSingleExample(data);
      
      // Limita o histórico para evitar uso excessivo de memória
      if (_trainingHistory.length > 1000) {
        _trainingHistory.removeAt(0);
      }
      
      // Salva os dados de treinamento
      await _saveTrainingData();
    } catch (e) {
      debugPrint('Erro ao adicionar feedback: $e');
    }
  }
  
  /// Salva dados de treinamento
  Future<void> _saveTrainingData() async {
    // Em uma implementação real, salvaria em arquivo ou banco de dados
    // Por enquanto, apenas mantém em memória
  }
  
  /// Calcula score baseado em regras tradicionais
  double _calculateRuleBasedScore(String phoneNumber, String? content) {
    double score = 0.0;
    
    // Análise do número
    score += _getSuspiciousScore(phoneNumber);
    
    // Análise do conteúdo
    if (content != null) {
      score += _getSpamKeywordScore(content);
      score += _getPatternScore(content);
    }
    
    return score.clamp(0.0, 1.0);
  }
  
  /// Obtém score de suspeição do número
  double _getSuspiciousScore(String phoneNumber) {
    for (var entry in _suspiciousNumberPrefixes.entries) {
      if (phoneNumber.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return 0.0;
  }
  
  /// Calcula proporção de maiúsculas
  double _getUppercaseRatio(String text) {
    if (text.isEmpty) return 0.0;
    final uppercaseCount = text.split('').where((c) => c == c.toUpperCase() && c != c.toLowerCase()).length;
    return uppercaseCount / text.length;
  }
  
  /// Calcula proporção de números
  double _getNumberRatio(String text) {
    if (text.isEmpty) return 0.0;
    final numberCount = text.split('').where((c) => '0123456789'.contains(c)).length;
    return numberCount / text.length;
  }
  
  /// Calcula proporção de caracteres especiais
  double _getSpecialCharRatio(String text) {
    if (text.isEmpty) return 0.0;
    final specialCount = text.split('').where((c) => '!@#\$%^&*()_+-=[]{}|;:,.<>?'.contains(c)).length;
    return specialCount / text.length;
  }
  
  /// Calcula score de palavras-chave de spam
  double _getSpamKeywordScore(String content) {
    double score = 0.0;
    final lowerContent = content.toLowerCase();
    
    for (var pattern in _spamPatterns) {
      final regex = RegExp(pattern.pattern, caseSensitive: false);
      if (regex.hasMatch(lowerContent)) {
        score += pattern.weight;
      }
    }
    
    return (score / _spamPatterns.length).clamp(0.0, 1.0);
  }
  
  /// Calcula score de padrões suspeitos
  double _getPatternScore(String content) {
    double score = 0.0;
    
    // URLs suspeitas
    if (RegExp(r'http[s]?://[^\s]+').hasMatch(content)) {
      score += 0.3;
    }
    
    // Muitos números
    if (_getNumberRatio(content) > 0.3) {
      score += 0.2;
    }
    
    // Muitas maiúsculas
    if (_getUppercaseRatio(content) > 0.5) {
      score += 0.2;
    }
    
    // Texto muito curto ou muito longo
    if (content.length < 10 || content.length > 300) {
      score += 0.1;
    }
    
    return score.clamp(0.0, 1.0);
  }
  
  /// Obtém estatísticas do modelo
  MLModelStats getModelStats() {
    return MLModelStats(
      trainingExamples: _trainingHistory.length,
      accuracy: _calculateAccuracy(),
      lastTrainingDate: _trainingHistory.isNotEmpty 
          ? _trainingHistory.last.timestamp 
          : null,
    );
  }
  
  /// Calcula precisão do modelo
  double _calculateAccuracy() {
    if (_trainingHistory.length < 10) return 0.0;
    
    int correct = 0;
    for (var data in _trainingHistory.take(100)) {
      final features = _extractFeatures(data);
      final prediction = _predict(features);
      final predictedSpam = prediction > 0.5;
      if (predictedSpam == data.isSpam) {
        correct++;
      }
    }
    
    return correct / min(100, _trainingHistory.length);
  }
}

/// Dados de treinamento para o modelo ML
class TrainingData {
  final String phoneNumber;
  final DateTime timestamp;
  final String? content;
  final bool isSpam;
  
  const TrainingData({
    required this.phoneNumber,
    required this.timestamp,
    this.content,
    required this.isSpam,
  });
}

/// Padrão de spam
class SpamPattern {
  final String pattern;
  final double weight;
  final SpamCategory category;
  
  const SpamPattern({
    required this.pattern,
    required this.weight,
    required this.category,
  });
}

/// Categorias de spam
enum SpamCategory {
  promotional,
  urgency,
  phishing,
  financial,
  lottery,
  other,
}

/// Estatísticas do modelo ML
class MLModelStats {
  final int trainingExamples;
  final double accuracy;
  final DateTime? lastTrainingDate;
  
  const MLModelStats({
    required this.trainingExamples,
    required this.accuracy,
    this.lastTrainingDate,
  });
}