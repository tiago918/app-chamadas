import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../database/repository.dart';

class SpamDetectionService {
  static final SpamDetectionService _instance = SpamDetectionService._internal();
  factory SpamDetectionService() => _instance;
  SpamDetectionService._internal();

  final Repository _repository = Repository();
  
  // Listas de padrões conhecidos de spam
  final List<String> _spamKeywords = [
    'promoção', 'oferta', 'grátis', 'ganhe', 'prêmio', 'sorteio',
    'desconto', 'liquidação', 'imperdível', 'urgente', 'último dia',
    'clique aqui', 'cadastre-se', 'parabéns', 'você ganhou',
    'empréstimo', 'crédito', 'financiamento', 'cartão aprovado',
    'dívida', 'negativado', 'spc', 'serasa', 'limpe seu nome',
    'bitcoin', 'investimento', 'renda extra', 'trabalhe em casa',
    'multilevel', 'pirâmide', 'esquema', 'dinheiro fácil'
  ];
  
  final List<String> _spamPatterns = [
    r'\b\d{4}\b.*grátis', // 4 dígitos + grátis
    r'clique.*link', // clique + link
    r'\$\d+.*dia', // valor em dólar por dia
    r'R\$\s*\d+.*hora', // valor em real por hora
    r'\d+%.*desconto', // porcentagem de desconto
    r'últimas?\s+\d+\s+vagas?', // últimas X vagas
    r'cadastre.*cpf', // cadastre + cpf
    r'confirme.*dados', // confirme + dados
  ];
  
  final List<String> _trustedPrefixes = [
    '11', '21', '31', '41', '51', '61', '71', '81', '85', '91', // Capitais
    '0800', '4004', '3003', // Números de atendimento
  ];
  
  final List<String> _suspiciousPrefixes = [
    '9', // Números que começam com 9 (podem ser spam)
    '+55', // Números internacionais do Brasil
    '+1', '+44', '+33', // Números internacionais comuns em spam
  ];

  // Cache de scores calculados
  final Map<String, double> _phoneScoreCache = {};
  final Map<String, double> _contentScoreCache = {};
  
  // Modelo de machine learning simplificado
  Map<String, double> _phoneWeights = {};
  Map<String, double> _contentWeights = {};
  double _threshold = 0.7;

  // Inicializar o serviço
  Future<bool> initialize() async {
    try {
      await _loadModel();
      await _loadUserFeedback();
      debugPrint('Serviço de detecção de spam inicializado');
      return true;
    } catch (e) {
      debugPrint('Erro ao inicializar detecção de spam: $e');
      return false;
    }
  }

  // Carregar modelo de ML
  Future<void> _loadModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Carregar pesos do modelo (se existirem)
      final phoneWeightsJson = prefs.getString('phone_weights');
      if (phoneWeightsJson != null) {
        // Aqui seria implementada a deserialização dos pesos
        // Por simplicidade, usamos pesos padrão
      }
      
      // Inicializar com pesos padrão
      _initializeDefaultWeights();
      
      // Carregar threshold personalizado
      _threshold = prefs.getDouble('spam_threshold') ?? 0.7;
      
    } catch (e) {
      debugPrint('Erro ao carregar modelo: $e');
      _initializeDefaultWeights();
    }
  }

  // Inicializar pesos padrão
  void _initializeDefaultWeights() {
    // Pesos para características de números de telefone
    _phoneWeights = {
      'length': 0.1,
      'prefix_suspicious': 0.3,
      'prefix_trusted': -0.4,
      'international': 0.2,
      'shortcode': 0.4,
      'frequency': 0.2,
    };
    
    // Pesos para características de conteúdo
    _contentWeights = {
      'spam_keywords': 0.4,
      'spam_patterns': 0.3,
      'caps_ratio': 0.1,
      'number_ratio': 0.1,
      'url_count': 0.2,
      'length': 0.05,
    };
  }

  // Carregar feedback do usuário
  Future<void> _loadUserFeedback() async {
    try {
      // Buscar histórico de feedback do usuário
      final callHistory = await _repository.getCallHistory('current_user');
      final smsHistory = await _repository.getMessageHistory('current_user');
      
      // Treinar modelo com feedback existente
      for (final call in callHistory) {
        if (call.spamScore > 0.8 || call.spamScore < 0.2) {
          await _updateModelWeights(
            phoneNumber: call.phoneNumber,
            isSpam: call.spamScore > 0.5,
            type: 'call',
          );
        }
      }
      
      for (final sms in smsHistory) {
        if (sms.spamScore > 0.8 || sms.spamScore < 0.2) {
          await _updateModelWeights(
            phoneNumber: sms.sender,
            content: sms.content,
            isSpam: sms.spamScore > 0.5,
            type: 'sms',
          );
        }
      }
      
    } catch (e) {
      debugPrint('Erro ao carregar feedback: $e');
    }
  }

  // Calcular score de spam para chamadas
  Future<double> calculateSpamScore({
    required String phoneNumber,
    String? contactName,
    required CallType callType,
  }) async {
    try {
      // Verificar cache
      final cacheKey = '${phoneNumber}_call';
      if (_phoneScoreCache.containsKey(cacheKey)) {
        return _phoneScoreCache[cacheKey]!;
      }
      
      double score = 0.0;
      
      // Análise do número de telefone
      score += _analyzePhoneNumber(phoneNumber);
      
      // Análise do tipo de chamada
      score += _analyzeCallType(callType);
      
      // Análise do nome do contato
      if (contactName != null) {
        score += _analyzeContactName(contactName);
      } else {
        score += 0.1; // Penalidade por não ter nome
      }
      
      // Análise de frequência
      score += await _analyzeCallFrequency(phoneNumber);
      
      // Análise de horário
      score += _analyzeCallTime();
      
      // Normalizar score (0.0 a 1.0)
      score = score.clamp(0.0, 1.0);
      
      // Armazenar no cache
      _phoneScoreCache[cacheKey] = score;
      
      return score;
    } catch (e) {
      debugPrint('Erro ao calcular score de spam para chamada: $e');
      return 0.0;
    }
  }

  // Calcular score de spam para SMS
  Future<double> calculateSmsSpamScore({
    required String sender,
    required String content,
    required MessageType messageType,
  }) async {
    try {
      // Verificar cache
      final cacheKey = '${sender}_${content.hashCode}';
      if (_contentScoreCache.containsKey(cacheKey)) {
        return _contentScoreCache[cacheKey]!;
      }
      
      double score = 0.0;
      
      // Análise do remetente
      score += _analyzePhoneNumber(sender);
      
      // Análise do conteúdo
      score += _analyzeMessageContent(content);
      
      // Análise do tipo de mensagem
      score += _analyzeMessageType(messageType);
      
      // Análise de frequência do remetente
      score += await _analyzeSmsFrequency(sender);
      
      // Análise de horário
      score += _analyzeMessageTime();
      
      // Normalizar score (0.0 a 1.0)
      score = score.clamp(0.0, 1.0);
      
      // Armazenar no cache
      _contentScoreCache[cacheKey] = score;
      
      return score;
    } catch (e) {
      debugPrint('Erro ao calcular score de spam para SMS: $e');
      return 0.0;
    }
  }

  // Analisar número de telefone
  double _analyzePhoneNumber(String phoneNumber) {
    double score = 0.0;
    
    // Remover caracteres especiais
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    // Análise de comprimento
    if (cleanNumber.length < 8) {
      score += _phoneWeights['shortcode'] ?? 0.4; // Código curto
    } else if (cleanNumber.length > 15) {
      score += 0.2; // Muito longo
    }
    
    // Análise de prefixos suspeitos
    for (final prefix in _suspiciousPrefixes) {
      if (cleanNumber.startsWith(prefix)) {
        score += _phoneWeights['prefix_suspicious'] ?? 0.3;
        break;
      }
    }
    
    // Análise de prefixos confiáveis
    for (final prefix in _trustedPrefixes) {
      if (cleanNumber.startsWith(prefix)) {
        score += _phoneWeights['prefix_trusted'] ?? -0.4;
        break;
      }
    }
    
    // Análise de números internacionais
    if (cleanNumber.startsWith('+')) {
      score += _phoneWeights['international'] ?? 0.2;
    }
    
    return score;
  }

  // Analisar conteúdo da mensagem
  double _analyzeMessageContent(String content) {
    double score = 0.0;
    final lowerContent = content.toLowerCase();
    
    // Análise de palavras-chave de spam
    int keywordCount = 0;
    for (final keyword in _spamKeywords) {
      if (lowerContent.contains(keyword)) {
        keywordCount++;
      }
    }
    score += (keywordCount / _spamKeywords.length) * (_contentWeights['spam_keywords'] ?? 0.4);
    
    // Análise de padrões de spam
    int patternCount = 0;
    for (final pattern in _spamPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(content)) {
        patternCount++;
      }
    }
    score += (patternCount / _spamPatterns.length) * (_contentWeights['spam_patterns'] ?? 0.3);
    
    // Análise de maiúsculas
    final capsCount = content.replaceAll(RegExp(r'[^A-Z]'), '').length;
    final capsRatio = content.isNotEmpty ? capsCount / content.length : 0;
    if (capsRatio > 0.5) {
      score += _contentWeights['caps_ratio'] ?? 0.1;
    }
    
    // Análise de números
    final numberCount = content.replaceAll(RegExp(r'[^0-9]'), '').length;
    final numberRatio = content.isNotEmpty ? numberCount / content.length : 0;
    if (numberRatio > 0.3) {
      score += _contentWeights['number_ratio'] ?? 0.1;
    }
    
    // Análise de URLs
    final urlCount = RegExp(r'https?://|www\.|bit\.ly|tinyurl').allMatches(lowerContent).length;
    score += urlCount * (_contentWeights['url_count'] ?? 0.2);
    
    // Análise de comprimento
    if (content.length > 500) {
      score += _contentWeights['length'] ?? 0.05;
    }
    
    return score;
  }

  // Analisar tipo de chamada
  double _analyzeCallType(CallType callType) {
    switch (callType) {
      case CallType.missed:
        return 0.3; // Chamadas perdidas têm suspeita baixa
      case CallType.incoming:
        return 0.05;
      case CallType.outgoing:
        return -0.1; // Chamadas feitas pelo usuário não são spam
    }
  }

  // Analisar nome do contato
  double _analyzeContactName(String contactName) {
    final lowerName = contactName.toLowerCase();
    
    // Nomes suspeitos
    final suspiciousNames = ['promoção', 'oferta', 'vendas', 'marketing', 'cobrança'];
    for (final name in suspiciousNames) {
      if (lowerName.contains(name)) {
        return 0.3;
      }
    }
    
    // Nome muito genérico
    if (lowerName.length < 3 || RegExp(r'^[0-9]+$').hasMatch(contactName)) {
      return 0.1;
    }
    
    return -0.1; // Ter nome é bom sinal
  }

  // Analisar tipo de mensagem
  double _analyzeMessageType(MessageType messageType) {
    switch (messageType) {
      case MessageType.received:
        return 0.4; // SMS recebidos têm suspeita moderada
      case MessageType.sent:
        return 0.1; // SMS enviados são menos suspeitos
    }
  }

  // Analisar frequência de chamadas
  Future<double> _analyzeCallFrequency(String phoneNumber) async {
    try {
      final calls = await _repository.getCallHistory('current_user');
      final recentCalls = calls.where((call) => 
        call.phoneNumber == phoneNumber &&
        call.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7)))
      ).length;
      
      if (recentCalls > 10) {
        return 0.3; // Muitas chamadas recentes
      } else if (recentCalls > 5) {
        return 0.1;
      }
      
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // Analisar frequência de SMS
  Future<double> _analyzeSmsFrequency(String sender) async {
    try {
      final smsHistory = await _repository.getMessageHistory('current_user');
      final filteredHistory = smsHistory.where((sms) => sms.sender == sender).take(5).toList();
      final recentSms = filteredHistory.where((sms) => 
        sms.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7)))
      ).length;
      
      if (recentSms > 5) {
        return 0.3; // Muitos SMS recentes
      } else if (recentSms > 2) {
        return 0.1;
      }
      
      return filteredHistory.length.toDouble() * 0.05;
    } catch (e) {
      return 0.0;
    }
  }

  // Analisar horário da chamada
  double _analyzeCallTime() {
    final now = DateTime.now();
    final hour = now.hour;
    
    // Horários suspeitos (muito cedo ou muito tarde)
    if (hour < 7 || hour > 22) {
      return 0.2;
    }
    
    // Horário comercial é menos suspeito
    if (hour >= 9 && hour <= 18) {
      return -0.05;
    }
    
    return 0.0;
  }

  // Analisar horário da mensagem
  double _analyzeMessageTime() {
    final now = DateTime.now();
    final hour = now.hour;
    
    // Horários suspeitos para SMS
    if (hour < 6 || hour > 23) {
      return 0.15;
    }
    
    return 0.0;
  }

  // Treinar modelo com feedback do usuário
  Future<void> trainWithFeedback({
    required String phoneNumber,
    String? content,
    required bool isSpam,
    required String type,
  }) async {
    try {
      await _updateModelWeights(
        phoneNumber: phoneNumber,
        content: content,
        isSpam: isSpam,
        type: type,
      );
      
      // Salvar modelo atualizado
      await _saveModel();
      
      // Limpar cache para recalcular scores
      _phoneScoreCache.clear();
      _contentScoreCache.clear();
      
      debugPrint('Modelo treinado com feedback: $phoneNumber (Spam: $isSpam)');
    } catch (e) {
      debugPrint('Erro ao treinar modelo: $e');
    }
  }

  // Atualizar pesos do modelo
  Future<void> _updateModelWeights({
    required String phoneNumber,
    String? content,
    required bool isSpam,
    required String type,
  }) async {
    const learningRate = 0.01;
    
    // Calcular erro de predição
    double predictedScore;
    if (type == 'call') {
      predictedScore = await calculateSpamScore(
        phoneNumber: phoneNumber,
        callType: CallType.incoming,
      );
    } else {
      predictedScore = await calculateSmsSpamScore(
        sender: phoneNumber,
        content: content ?? '',
        messageType: MessageType.received,
      );
    }
    
    final actualScore = isSpam ? 1.0 : 0.0;
    final error = actualScore - predictedScore;
    
    // Atualizar pesos (algoritmo simples de gradiente descendente)
    _phoneWeights.updateAll((key, value) => value + (learningRate * error));
    
    if (content != null) {
      _contentWeights.updateAll((key, value) => value + (learningRate * error));
    }
  }

  // Salvar modelo
  Future<void> _saveModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Salvar threshold
      await prefs.setDouble('spam_threshold', _threshold);
      
      // Aqui seria implementada a serialização dos pesos
      // Por simplicidade, apenas salvamos o threshold
      
      debugPrint('Modelo salvo com sucesso');
    } catch (e) {
      debugPrint('Erro ao salvar modelo: $e');
    }
  }

  // Ajustar threshold de detecção
  Future<void> adjustThreshold(double newThreshold) async {
    _threshold = newThreshold.clamp(0.0, 1.0);
    await _saveModel();
    debugPrint('Threshold ajustado para: $_threshold');
  }

  // Verificar se é spam baseado no threshold
  bool isSpam(double score) {
    return score >= _threshold;
  }

  // Obter estatísticas do modelo
  Map<String, dynamic> getModelStatistics() {
    return {
      'threshold': _threshold,
      'phoneWeights': Map.from(_phoneWeights),
      'contentWeights': Map.from(_contentWeights),
      'cacheSize': _phoneScoreCache.length + _contentScoreCache.length,
      'spamKeywordsCount': _spamKeywords.length,
      'spamPatternsCount': _spamPatterns.length,
    };
  }

  // Limpar cache
  void clearCache() {
    _phoneScoreCache.clear();
    _contentScoreCache.clear();
    debugPrint('Cache de detecção de spam limpo');
  }

  // Adicionar palavra-chave de spam personalizada
  void addCustomSpamKeyword(String keyword) {
    if (!_spamKeywords.contains(keyword.toLowerCase())) {
      _spamKeywords.add(keyword.toLowerCase());
      clearCache(); // Limpar cache para recalcular
    }
  }

  // Remover palavra-chave de spam
  void removeSpamKeyword(String keyword) {
    _spamKeywords.remove(keyword.toLowerCase());
    clearCache();
  }

  // Obter palavras-chave de spam
  List<String> getSpamKeywords() {
    return List.from(_spamKeywords);
  }

  // Limpar recursos
  Future<void> dispose() async {
    await _saveModel();
    clearCache();
  }
}