import 'dart:async';
import '../models/models.dart';
import '../database/repository.dart';
import 'spam_detection_service.dart';

class BlockService {
  static final BlockService _instance = BlockService._internal();
  factory BlockService() => _instance;
  BlockService._internal();

  final Repository _repository = Repository();
  final SpamDetectionService _spamDetection = SpamDetectionService();
  
  // Cache de regras para melhor performance
  List<BlockRule>? _cachedRules;
  DateTime? _lastRulesUpdate;
  final Duration _cacheTimeout = const Duration(minutes: 5);

  // Inicializar o serviço
  Future<bool> initialize() async {
    try {
      await _loadBlockRules();
      print('Serviço de bloqueio inicializado');
      return true;
    } catch (e) {
      print('Erro ao inicializar serviço de bloqueio: $e');
      return false;
    }
  }

  // Carregar regras de bloqueio
  Future<void> _loadBlockRules() async {
    try {
      _cachedRules = await _repository.getBlockRules('current_user');
      _lastRulesUpdate = DateTime.now();
      
      // Se não há regras, criar regras padrão
      if (_cachedRules!.isEmpty) {
        await _createDefaultRules();
        _cachedRules = await _repository.getBlockRules('current_user');
      }
      
      print('${_cachedRules!.length} regras de bloqueio carregadas');
    } catch (e) {
      print('Erro ao carregar regras de bloqueio: $e');
      _cachedRules = [];
    }
  }

  // Criar regras padrão
  Future<void> _createDefaultRules() async {
    try {
      final defaultRules = BlockRule.getDefaultRules('current_user');
      
      for (final rule in defaultRules) {
        await _repository.createBlockRule(rule);
      }
      
      print('Regras padrão criadas');
    } catch (e) {
      print('Erro ao criar regras padrão: $e');
    }
  }

  // Obter regras atualizadas
  Future<List<BlockRule>> _getUpdatedRules() async {
    // Verificar se o cache ainda é válido
    if (_cachedRules != null && 
        _lastRulesUpdate != null &&
        DateTime.now().difference(_lastRulesUpdate!) < _cacheTimeout) {
      return _cachedRules!;
    }
    
    // Recarregar regras
    await _loadBlockRules();
    return _cachedRules ?? [];
  }

  // Verificar se chamada deve ser bloqueada
  Future<bool> shouldBlockCall(String phoneNumber, String? contactName) async {
    try {
      final rules = await _getUpdatedRules();
      
      // Verificar regras por prioridade (maior prioridade primeiro)
      final sortedRules = List<BlockRule>.from(rules)
        ..sort((a, b) => b.priority.compareTo(a.priority));
      
      for (final rule in sortedRules) {
        if (!rule.isActive) continue;
        
        // Verificar se a regra se aplica a chamadas
        if (!_ruleAppliesToCalls(rule.ruleType)) continue;
        
        // Verificar se a regra corresponde
        if (rule.matches(phoneNumber)) {
          print('Chamada bloqueada pela regra: ${rule.ruleName}');
          return true;
        }
        
        // Verificar nome do contato se disponível
        if (contactName != null && rule.matchesMessage('', contactName!)) {
          print('Chamada bloqueada pelo nome do contato: ${rule.ruleName}');
          return true;
        }
      }
      
      // Verificar usando detecção de spam por ML
      final spamScore = await _spamDetection.calculateSpamScore(
        phoneNumber: phoneNumber,
        contactName: contactName,
        callType: CallType.incoming,
      );
      
      if (_spamDetection.isSpam(spamScore)) {
        print('Chamada bloqueada por detecção de spam (score: $spamScore)');
        return true;
      }
      
      return false;
    } catch (e) {
      print('Erro ao verificar bloqueio de chamada: $e');
      return false;
    }
  }

  // Verificar se SMS deve ser bloqueado
  Future<bool> shouldBlockSms(String sender, String content) async {
    try {
      final rules = await _getUpdatedRules();
      
      // Verificar regras por prioridade
      final sortedRules = List<BlockRule>.from(rules)
        ..sort((a, b) => b.priority.compareTo(a.priority));
      
      for (final rule in sortedRules) {
        if (!rule.isActive) continue;
        
        // Verificar se a regra se aplica a SMS
        if (!_ruleAppliesToSms(rule.ruleType)) continue;
        
        // Verificar remetente
        if (rule.matches(sender)) {
          print('SMS bloqueado pela regra de remetente: ${rule.ruleName}');
          return true;
        }
        
        // Verificar conteúdo
        if (rule.matchesMessage(sender, content)) {
          print('SMS bloqueado pela regra de conteúdo: ${rule.ruleName}');
          return true;
        }
      }
      
      // Verificar usando detecção de spam por ML
      final spamScore = await _spamDetection.calculateSmsSpamScore(
        sender: sender,
        content: content,
        messageType: _determineMessageType(sender),
      );
      
      if (_spamDetection.isSpam(spamScore)) {
        print('SMS bloqueado por detecção de spam (score: $spamScore)');
        return true;
      }
      
      return false;
    } catch (e) {
      print('Erro ao verificar bloqueio de SMS: $e');
      return false;
    }
  }

  // Verificar se regra se aplica a chamadas
  bool _ruleAppliesToCalls(RuleType ruleType) {
    switch (ruleType) {
      case RuleType.blacklist:
      case RuleType.whitelist:
      case RuleType.international:
      case RuleType.unknown:
      case RuleType.shortCode:
      case RuleType.pattern:
      case RuleType.regex:
      case RuleType.phoneNumber:
      case RuleType.prefix:
      case RuleType.timeBased:
        return true;
      case RuleType.smsBlacklist:
      case RuleType.keywordFilter:
      case RuleType.keyword:
        return false;
    }
  }

  // Verificar se regra se aplica a SMS
  bool _ruleAppliesToSms(RuleType ruleType) {
    switch (ruleType) {
      case RuleType.blacklist:
      case RuleType.whitelist:
      case RuleType.smsBlacklist:
      case RuleType.keywordFilter:
      case RuleType.international:
      case RuleType.shortCode:
      case RuleType.pattern:
      case RuleType.regex:
      case RuleType.phoneNumber:
      case RuleType.prefix:
      case RuleType.keyword:
      case RuleType.timeBased:
        return true;
      case RuleType.unknown:
        return false;
    }
  }

  // Determinar tipo de mensagem
  MessageType _determineMessageType(String sender) {
    // Para este enum simples, sempre retornamos 'received' para mensagens recebidas
    // A lógica de detecção de spam será feita em outros lugares
    return MessageType.received;
  }

  // Criar nova regra de bloqueio
  Future<bool> createBlockRule(BlockRule rule) async {
    try {
      final success = await _repository.createBlockRule(rule);
      if (success) {
        // Invalidar cache
        _cachedRules = null;
        _lastRulesUpdate = null;
        print('Nova regra de bloqueio criada: ${rule.ruleName}');
      }
      return success;
    } catch (e) {
      print('Erro ao criar regra de bloqueio: $e');
      return false;
    }
  }

  // Atualizar regra de bloqueio
  Future<bool> updateBlockRule(BlockRule rule) async {
    try {
      final success = await _repository.updateBlockRule(rule);
      if (success) {
        // Invalidar cache
        _cachedRules = null;
        _lastRulesUpdate = null;
        print('Regra de bloqueio atualizada: ${rule.ruleName}');
      }
      return success;
    } catch (e) {
      print('Erro ao atualizar regra de bloqueio: $e');
      return false;
    }
  }

  // Deletar regra de bloqueio
  Future<bool> deleteBlockRule(String ruleId) async {
    try {
      final success = await _repository.deleteBlockRule(ruleId);
      if (success) {
        // Invalidar cache
        _cachedRules = null;
        _lastRulesUpdate = null;
        print('Regra de bloqueio deletada: $ruleId');
      }
      return success;
    } catch (e) {
      print('Erro ao deletar regra de bloqueio: $e');
      return false;
    }
  }

  // Ativar/desativar regra
  Future<bool> toggleRule(String ruleId, bool isActive) async {
    try {
      final rules = await _getUpdatedRules();
      final rule = rules.firstWhere((r) => r.id == ruleId);
      
      final updatedRule = rule.copyWith(isActive: isActive);
      return await updateBlockRule(updatedRule);
    } catch (e) {
      print('Erro ao ativar/desativar regra: $e');
      return false;
    }
  }

  // Obter todas as regras
  Future<List<BlockRule>> getAllRules() async {
    return await _getUpdatedRules();
  }

  // Obter regras por tipo
  Future<List<BlockRule>> getRulesByType(RuleType type) async {
    final rules = await _getUpdatedRules();
    return rules.where((rule) => rule.ruleType == type).toList();
  }

  // Obter regras ativas
  Future<List<BlockRule>> getActiveRules() async {
    final rules = await _getUpdatedRules();
    return rules.where((rule) => rule.isActive).toList();
  }

  // Adicionar número à lista branca
  Future<bool> addToWhitelist(String phoneNumber, String reason) async {
    try {
      final rule = BlockRule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'current_user',
        ruleName: 'Lista Branca - $phoneNumber',
        ruleType: RuleType.whitelist,
        pattern: phoneNumber,
        isActive: true,
        priority: 100, // Alta prioridade para lista branca
        createdAt: DateTime.now(),
      );
      
      return await createBlockRule(rule);
    } catch (e) {
      print('Erro ao adicionar à lista branca: $e');
      return false;
    }
  }

  // Adicionar número à lista negra
  Future<bool> addToBlacklist(String phoneNumber, String reason) async {
    try {
      final rule = BlockRule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'current_user',
        ruleName: 'Lista Negra - $phoneNumber',
        ruleType: RuleType.blacklist,
        pattern: phoneNumber,
        isActive: true,
        priority: 50,
        createdAt: DateTime.now(),
      );
      
      return await createBlockRule(rule);
    } catch (e) {
      print('Erro ao adicionar à lista negra: $e');
      return false;
    }
  }

  // Verificar se número está na lista branca
  Future<bool> isWhitelisted(String phoneNumber) async {
    try {
      final whitelistRules = await getRulesByType(RuleType.whitelist);
      return whitelistRules.any((rule) => rule.isActive && rule.matches(phoneNumber));
    } catch (e) {
      return false;
    }
  }

  // Verificar se número está na lista negra
  Future<bool> isBlacklisted(String phoneNumber) async {
    try {
      final blacklistRules = await getRulesByType(RuleType.blacklist);
      return blacklistRules.any((rule) => rule.isActive && rule.matches(phoneNumber));
    } catch (e) {
      return false;
    }
  }

  // Obter estatísticas de bloqueio
  Future<Map<String, dynamic>> getBlockingStatistics() async {
    try {
      final rules = await _getUpdatedRules();
      final activeRules = rules.where((rule) => rule.isActive).length;
      final totalRules = rules.length;
      
      final rulesByType = <String, int>{};
      for (final rule in rules) {
        final typeName = rule.ruleType.toString().split('.').last;
        rulesByType[typeName] = (rulesByType[typeName] ?? 0) + 1;
      }
      
      final effectiveness = await _repository.getBlockingEffectiveness('current_user');
      
      return {
        'totalRules': totalRules,
        'activeRules': activeRules,
        'rulesByType': rulesByType,
        'callBlockRate': effectiveness['callBlockRate'] ?? 0,
        'smsBlockRate': effectiveness['smsBlockRate'] ?? 0,
        'totalBlocked': effectiveness['totalBlocked'] ?? 0,
      };
    } catch (e) {
      print('Erro ao obter estatísticas: $e');
      return {
        'totalRules': 0,
        'activeRules': 0,
        'rulesByType': {},
        'callBlockRate': 0,
        'smsBlockRate': 0,
        'totalBlocked': 0,
      };
    }
  }

  // Testar regra contra um número/conteúdo
  Future<Map<String, dynamic>> testRule(String ruleId, String phoneNumber, [String? content]) async {
    try {
      final rules = await _getUpdatedRules();
      final rule = rules.firstWhere((r) => r.id == ruleId);
      
      final phoneMatches = rule.matches(phoneNumber);
      final contentMatches = content != null ? rule.matchesMessage(phoneNumber, content) : false;
      
      return {
        'ruleId': ruleId,
        'ruleName': rule.ruleName,
        'phoneMatches': phoneMatches,
        'contentMatches': contentMatches,
        'wouldBlock': phoneMatches || contentMatches,
      };
    } catch (e) {
      return {
        'error': 'Erro ao testar regra: $e',
      };
    }
  }

  // Importar regras de um backup
  Future<bool> importRules(List<Map<String, dynamic>> rulesData) async {
    try {
      int importedCount = 0;
      
      for (final ruleData in rulesData) {
        try {
          final rule = BlockRule.fromMap(ruleData);
          final success = await createBlockRule(rule);
          if (success) importedCount++;
        } catch (e) {
          print('Erro ao importar regra: $e');
        }
      }
      
      print('$importedCount regras importadas com sucesso');
      return importedCount > 0;
    } catch (e) {
      print('Erro ao importar regras: $e');
      return false;
    }
  }

  // Exportar regras para backup
  Future<List<Map<String, dynamic>>> exportRules() async {
    try {
      final rules = await _getUpdatedRules();
      return rules.map((rule) => rule.toMap()).toList();
    } catch (e) {
      print('Erro ao exportar regras: $e');
      return [];
    }
  }

  // Resetar para regras padrão
  Future<bool> resetToDefaultRules() async {
    try {
      // Deletar todas as regras existentes
      final rules = await _getUpdatedRules();
      for (final rule in rules) {
        await _repository.deleteBlockRule(rule.id);
      }
      
      // Criar regras padrão
      await _createDefaultRules();
      
      // Invalidar cache
      _cachedRules = null;
      _lastRulesUpdate = null;
      
      print('Regras resetadas para padrão');
      return true;
    } catch (e) {
      print('Erro ao resetar regras: $e');
      return false;
    }
  }

  // Otimizar regras (remover duplicatas, consolidar padrões similares)
  Future<bool> optimizeRules() async {
    try {
      final rules = await _getUpdatedRules();
      final optimizedRules = <BlockRule>[];
      final processedPatterns = <String>{};
      
      for (final rule in rules) {
        // Verificar se já temos uma regra similar
        final pattern = rule.pattern ?? '';
        if (!processedPatterns.contains(pattern)) {
          optimizedRules.add(rule);
          processedPatterns.add(pattern);
        } else {
          // Deletar regra duplicada
          await _repository.deleteBlockRule(rule.id);
        }
      }
      
      // Invalidar cache
      _cachedRules = null;
      _lastRulesUpdate = null;
      
      final removedCount = rules.length - optimizedRules.length;
      print('Otimização concluída: $removedCount regras duplicadas removidas');
      
      return true;
    } catch (e) {
      print('Erro ao otimizar regras: $e');
      return false;
    }
  }

  // Limpar cache
  void clearCache() {
    _cachedRules = null;
    _lastRulesUpdate = null;
    print('Cache de regras de bloqueio limpo');
  }

  // Limpar recursos
  Future<void> dispose() async {
    clearCache();
  }
}