import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../database/repository.dart';
import 'spam_detection_service.dart';
import 'block_service.dart';

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final Repository _repository = Repository();
  final SpamDetectionService _spamDetection = SpamDetectionService();
  final BlockService _blockService = BlockService();
  final Uuid _uuid = const Uuid();

  Timer? _smsMonitorTimer;
  DateTime? _lastSmsCheck;
  final List<StreamController<SmsLog>> _smsStreamControllers = [];

  // Stream para notificar sobre novas mensagens
  Stream<SmsLog> get smsStream {
    final controller = StreamController<SmsLog>.broadcast();
    _smsStreamControllers.add(controller);
    return controller.stream;
  }

  // Inicializar o serviço de SMS
  Future<bool> initialize() async {
    try {
      // Verificar permissões necessárias
      final hasPermissions = await _checkPermissions();
      if (!hasPermissions) {
        debugPrint('Permissões de SMS não concedidas');
        return false;
      }
      
      debugPrint('Serviço de SMS inicializado com sucesso (modo simplificado)');
      return true;
    } catch (e) {
      debugPrint('Erro ao inicializar serviço de SMS: $e');
      return false;
    }
  }

  // Verificar permissões necessárias
  Future<bool> _checkPermissions() async {
    final permissions = [
      Permission.sms,
      Permission.phone,
      Permission.contacts,
    ];

    for (final permission in permissions) {
      final status = await permission.status;
      if (!status.isGranted) {
        final result = await permission.request();
        if (!result.isGranted) {
          return false;
        }
      }
    }
    return true;
  }

  // Processar mensagem SMS manualmente (para testes)
  Future<void> processSmsMessage(String sender, String content, {MessageType? messageType}) async {
    try {
      final timestamp = DateTime.now();
      messageType ??= MessageType.received;

      // Verificar se deve ser bloqueada
      final shouldBlock = await _shouldBlockSms(sender, content);
      
      // Calcular score de spam
      final spamScore = await _spamDetection.calculateSmsSpamScore(
        sender: sender,
        content: content,
        messageType: messageType,
      );

      // Criar log de SMS
      final smsLog = SmsLog(
        id: _uuid.v4(),
        userId: 'current_user', // TODO: Obter do usuário logado
        sender: sender,
        content: content,
        timestamp: timestamp,
        messageType: messageType,
        isBlocked: shouldBlock,
        spamScore: spamScore,
      );

      // Salvar no banco de dados
      await _repository.saveSmsLog(smsLog);

      // Notificar listeners
      for (final controller in _smsStreamControllers) {
        if (!controller.isClosed) {
          controller.add(smsLog);
        }
      }

      // Se foi bloqueada, executar ação de bloqueio
      if (shouldBlock) {
        await _executeSmsBlock(sender, smsLog);
      }

      debugPrint('SMS processado: $sender (Bloqueado: $shouldBlock)');
    } catch (e) {
      debugPrint('Erro ao processar SMS: $e');
    }
  }

  // Verificar se é código curto
  bool _isShortCode(String sender) {
    return sender.length <= 6 && RegExp(r'^[0-9]+$').hasMatch(sender);
  }

  // Verificar se é número internacional
  bool _isInternational(String sender) {
    return sender.startsWith('+') && sender.length > 10;
  }

  // Verificar se SMS deve ser bloqueado
  Future<bool> _shouldBlockSms(String sender, String content) async {
    try {
      return await _blockService.shouldBlockSms(sender, content);
    } catch (e) {
      debugPrint('Erro ao verificar bloqueio de SMS: $e');
      return false;
    }
  }

  // Executar bloqueio de SMS
  Future<void> _executeSmsBlock(String sender, SmsLog smsLog) async {
    try {
      // Registrar tentativa de bloqueio
      debugPrint('Bloqueando SMS de: $sender');
      
      // Aqui seria implementada a lógica real de bloqueio
      // No Android, isso pode incluir:
      // - Mover para pasta de spam
      // - Deletar automaticamente
      // - Marcar como lida
      // - Notificar o usuário sobre bloqueio
      
      // Por enquanto, apenas logamos a ação
      await _logBlockAction(sender, 'sms', 'SMS bloqueado automaticamente');
      
    } catch (e) {
      debugPrint('Erro ao executar bloqueio de SMS: $e');
    }
  }

  // Registrar ação de bloqueio
  Future<void> _logBlockAction(String sender, String type, String reason) async {
    try {
      debugPrint('[$type] Bloqueado: $sender - Motivo: $reason');
      // Aqui poderia ser implementado um sistema de logs mais robusto
    } catch (e) {
      debugPrint('Erro ao registrar ação de bloqueio: $e');
    }
  }

  // Método simplificado para simular monitoramento
  Future<void> startSimulatedMonitoring() async {
    debugPrint('Monitoramento de SMS iniciado (modo simulado)');
    // Em uma implementação real, aqui seria configurado o listener nativo
  }

  // Obter histórico de SMS
  Future<List<SmsLog>> getSmsHistory({int? limit}) async {
    try {
      return await _repository.getMessageHistory('current_user', limit: limit);
    } catch (e) {
      debugPrint('Erro ao obter histórico de SMS: $e');
      return [];
    }
  }

  // Obter SMS bloqueados
  Future<List<SmsLog>> getBlockedSms() async {
    try {
      return await _repository.getBlockedMessages('current_user');
    } catch (e) {
      debugPrint('Erro ao obter SMS bloqueados: $e');
      return [];
    }
  }

  // Marcar SMS como spam manualmente
  Future<bool> markAsSpam(String smsId, bool isSpam) async {
    try {
      // Buscar SMS
      final smsList = await _repository.getMessageHistory('current_user');
      final sms = smsList.firstWhere((s) => s.id == smsId);
      
      // Atualizar score de spam
      final updatedSms = sms.copyWith(
        spamScore: isSpam ? 1.0 : 0.0,
        isBlocked: isSpam,
      );
      
      // Salvar alteração
      final success = await _repository.updateSmsLog(updatedSms);
      
      if (success && isSpam) {
        // Treinar modelo de detecção de spam
        await _spamDetection.trainWithFeedback(
          phoneNumber: sms.sender,
          content: sms.content,
          isSpam: true,
          type: 'sms',
        );
      }
      
      return success;
    } catch (e) {
      debugPrint('Erro ao marcar SMS como spam: $e');
      return false;
    }
  }

  // Adicionar remetente à lista negra
  Future<bool> addSenderToBlacklist(String sender, String reason) async {
    try {
      final blockRule = BlockRule(
        id: _uuid.v4(),
        userId: 'current_user',
        ruleName: 'Bloqueio SMS - $sender',
        ruleType: RuleType.blacklist,
        pattern: sender,
        isActive: true,
        priority: 10,
        createdAt: DateTime.now(),
      );
      
      return await _repository.createBlockRule(blockRule);
    } catch (e) {
      debugPrint('Erro ao adicionar remetente à lista negra: $e');
      return false;
    }
  }

  // Adicionar palavra-chave de spam
  Future<bool> addSpamKeyword(String keyword) async {
    try {
      final blockRule = BlockRule(
        id: _uuid.v4(),
        userId: 'current_user',
        ruleName: 'Palavra-chave Spam - $keyword',
        ruleType: RuleType.pattern,
        pattern: keyword.toLowerCase(),
        isActive: true,
        priority: 5,
        createdAt: DateTime.now(),
      );
      
      return await _repository.createBlockRule(blockRule);
    } catch (e) {
      debugPrint('Erro ao adicionar palavra-chave de spam: $e');
      return false;
    }
  }

  // Enviar SMS (simulado)
  Future<bool> sendSms(String phoneNumber, String message) async {
    try {
      // Em uma implementação real, aqui seria usado um plugin nativo para enviar SMS
      debugPrint('Simulando envio de SMS para: $phoneNumber');
      
      // Registrar SMS enviado
      final smsLog = SmsLog(
        id: _uuid.v4(),
        userId: 'current_user',
        sender: 'Eu', // Indica que foi enviado pelo usuário
        content: message,
        timestamp: DateTime.now(),
        messageType: MessageType.sent,
        isBlocked: false,
        spamScore: 0.0,
      );
      
      await _repository.saveSmsLog(smsLog);
      
      debugPrint('SMS registrado como enviado para: $phoneNumber');
      return true;
    } catch (e) {
      debugPrint('Erro ao registrar SMS enviado: $e');
      return false;
    }
  }

  // Obter estatísticas de SMS
  Future<Map<String, dynamic>> getSmsStatistics() async {
    try {
      final stats = await _repository.getStatistics('current_user');
      final effectiveness = await _repository.getBlockingEffectiveness('current_user');
      
      return {
        'totalSms': stats['totalSms'] ?? 0,
        'blockedSms': stats['blockedSms'] ?? 0,
        'blockRate': effectiveness['smsBlockRate'] ?? 0,
        'spamKeywords': await _getTopSpamKeywords(),
        'topSpammers': await _getTopSpammers(),
      };
    } catch (e) {
      debugPrint('Erro ao obter estatísticas de SMS: $e');
      return {
        'totalSms': 0,
        'blockedSms': 0,
        'blockRate': 0,
        'spamKeywords': [],
        'topSpammers': [],
      };
    }
  }

  // Obter principais palavras-chave de spam
  Future<List<String>> _getTopSpamKeywords() async {
    try {
      final rules = await _repository.getBlockRules('current_user');
      return rules
          .where((rule) => rule.ruleType == RuleType.pattern)
          .map((rule) => rule.pattern ?? '')
          .where((pattern) => pattern.isNotEmpty)
          .take(10)
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Obter principais spammers
  Future<List<Map<String, dynamic>>> _getTopSpammers() async {
    try {
      final smsList = await _repository.getBlockedMessages('current_user');
      final spammerCount = <String, int>{};
      
      for (final sms in smsList) {
        spammerCount[sms.sender] = (spammerCount[sms.sender] ?? 0) + 1;
      }
      
      final sortedSpammers = spammerCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return sortedSpammers
          .take(10)
          .map((entry) => {
                'sender': entry.key,
                'count': entry.value,
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Sincronizar com SMS do sistema (simulado)
  Future<void> syncWithSystemSms() async {
    try {
      debugPrint('Sincronização com SMS do sistema (modo simulado)');
      // Em uma implementação real, aqui seria feita a sincronização com o sistema
      debugPrint('Sincronização simulada concluída');
    } catch (e) {
      debugPrint('Erro na sincronização de SMS: $e');
    }
  }

  // Parar monitoramento
  void stopMonitoring() {
    _smsMonitorTimer?.cancel();
    _smsMonitorTimer = null;
    
    // Fechar streams
    for (final controller in _smsStreamControllers) {
      controller.close();
    }
    _smsStreamControllers.clear();
    
    debugPrint('Monitoramento de SMS parado');
  }

  // Limpar recursos
  Future<void> dispose() async {
    stopMonitoring();
    await _repository.close();
  }
}