import 'dart:async';
import 'package:call_log/call_log.dart' as CallLogPlugin;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../database/repository.dart';
import 'spam_detection_service.dart';
import 'block_service.dart';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final Repository _repository = Repository();
  final SpamDetectionService _spamDetection = SpamDetectionService();
  final BlockService _blockService = BlockService();
  final Uuid _uuid = const Uuid();

  Timer? _callMonitorTimer;
  DateTime? _lastCallCheck;
  final List<StreamController<CallLog>> _callStreamControllers = [];

  // Stream para notificar sobre novas chamadas
  Stream<CallLog> get callStream {
    final controller = StreamController<CallLog>.broadcast();
    _callStreamControllers.add(controller);
    return controller.stream;
  }

  // Inicializar o serviço de chamadas
  Future<bool> initialize() async {
    try {
      // Verificar permissões necessárias
      final hasPermissions = await _checkPermissions();
      if (!hasPermissions) {
        debugPrint('Permissões necessárias não concedidas');
        return false;
      }

      // Inicializar monitoramento de chamadas
      await _startCallMonitoring();
      
      debugPrint('Serviço de chamadas inicializado com sucesso');
      return true;
    } catch (e) {
      debugPrint('Erro ao inicializar serviço de chamadas: $e');
      return false;
    }
  }

  // Verificar permissões necessárias
  Future<bool> _checkPermissions() async {
    final permissions = [
      Permission.phone,
      Permission.contacts,
      Permission.storage,
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

  // Iniciar monitoramento de chamadas
  Future<void> _startCallMonitoring() async {
    _lastCallCheck = DateTime.now().subtract(const Duration(minutes: 1));
    
    _callMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkForNewCalls();
    });
  }

  // Verificar novas chamadas
  Future<void> _checkForNewCalls() async {
    try {
      final entries = await CallLogPlugin.CallLog.query(
        dateFrom: _lastCallCheck!.millisecondsSinceEpoch,
        dateTo: DateTime.now().millisecondsSinceEpoch,
      );

      for (final entry in entries) {
        await _processCallEntry(entry);
      }

      _lastCallCheck = DateTime.now();
    } catch (e) {
      debugPrint('Erro ao verificar novas chamadas: $e');
    }
  }

  // Processar entrada de chamada
  Future<void> _processCallEntry(CallLogPlugin.CallLogEntry entry) async {
    try {
      final phoneNumber = entry.number ?? 'Desconhecido';
      final timestamp = DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0);
      
      // Determinar tipo de chamada
      CallType callType;
      switch (entry.callType) {
        case CallLogPlugin.CallType.incoming:
          callType = CallType.incoming;
          break;
        case CallLogPlugin.CallType.outgoing:
          callType = CallType.outgoing;
          break;
        case CallLogPlugin.CallType.missed:
          callType = CallType.missed;
          break;
        case CallLogPlugin.CallType.rejected:
          callType = CallType.missed; // rejected não existe no nosso enum
          break;
        default:
          callType = CallType.incoming;
      }

      // Buscar nome do contato
      String? contactName;
      try {
        contactName = entry.name;
      } catch (e) {
        contactName = null;
      }

      // Verificar se deve ser bloqueada
      final shouldBlock = await _shouldBlockCall(phoneNumber, contactName);
      
      // Calcular score de spam
      final spamScore = await _spamDetection.calculateSpamScore(
        phoneNumber: phoneNumber,
        contactName: contactName,
        callType: callType,
      );

      // Criar log de chamada
      final callLog = CallLog(
        id: _uuid.v4(),
        userId: 'current_user', // TODO: Obter do usuário logado
        phoneNumber: phoneNumber,
        contactName: contactName,
        timestamp: timestamp,
        duration: entry.duration ?? 0,
        callType: callType,
        isBlocked: shouldBlock,
        spamScore: spamScore,
      );

      // Salvar no banco de dados
      await _repository.saveCallLog(callLog);

      // Notificar listeners
      for (final controller in _callStreamControllers) {
        if (!controller.isClosed) {
          controller.add(callLog);
        }
      }

      // Se foi bloqueada, executar ação de bloqueio
      if (shouldBlock) {
        await _executeCallBlock(phoneNumber, callLog);
      }

      debugPrint('Chamada processada: $phoneNumber (Bloqueada: $shouldBlock)');
    } catch (e) {
      debugPrint('Erro ao processar entrada de chamada: $e');
    }
  }

  // Verificar se chamada deve ser bloqueada
  Future<bool> _shouldBlockCall(String phoneNumber, String? contactName) async {
    try {
      return await _blockService.shouldBlockCall(phoneNumber, contactName);
    } catch (e) {
      debugPrint('Erro ao verificar bloqueio de chamada: $e');
      return false;
    }
  }

  // Executar bloqueio de chamada
  Future<void> _executeCallBlock(String phoneNumber, CallLog callLog) async {
    try {
      // Registrar tentativa de bloqueio
      debugPrint('Bloqueando chamada de: $phoneNumber');
      
      // Aqui seria implementada a lógica real de bloqueio
      // No Android, isso requer permissões especiais e pode usar:
      // - TelecomManager para rejeitar chamadas
      // - Broadcast receivers para interceptar chamadas
      // - Accessibility services
      
      // Por enquanto, apenas logamos a ação
      await _logBlockAction(phoneNumber, 'call', 'Chamada bloqueada automaticamente');
      
    } catch (e) {
      debugPrint('Erro ao executar bloqueio de chamada: $e');
    }
  }

  // Registrar ação de bloqueio
  Future<void> _logBlockAction(String phoneNumber, String type, String reason) async {
    try {
      debugPrint('[$type] Bloqueado: $phoneNumber - Motivo: $reason');
      // Aqui poderia ser implementado um sistema de logs mais robusto
    } catch (e) {
      debugPrint('Erro ao registrar ação de bloqueio: $e');
    }
  }

  // Obter histórico de chamadas
  Future<List<CallLog>> getCallHistory({int? limit}) async {
    try {
      return await _repository.getCallHistory('current_user', limit: limit);
    } catch (e) {
      debugPrint('Erro ao obter histórico de chamadas: $e');
      return [];
    }
  }

  // Obter chamadas bloqueadas
  Future<List<CallLog>> getBlockedCalls() async {
    try {
      return await _repository.getBlockedCalls('current_user');
    } catch (e) {
      debugPrint('Erro ao obter chamadas bloqueadas: $e');
      return [];
    }
  }

  // Marcar chamada como spam manualmente
  Future<bool> markAsSpam(String callId, bool isSpam) async {
    try {
      // Buscar chamada
      final calls = await _repository.getCallHistory('current_user');
      final call = calls.firstWhere((c) => c.id == callId);
      
      // Atualizar score de spam
      final updatedCall = call.copyWith(
        spamScore: isSpam ? 1.0 : 0.0,
        isBlocked: isSpam,
      );
      
      // Salvar alteração
      final success = await _repository.updateCallLog(updatedCall);
      
      if (success && isSpam) {
        // Treinar modelo de detecção de spam
        await _spamDetection.trainWithFeedback(
          phoneNumber: call.phoneNumber,
          isSpam: true,
          type: 'call',
        );
      }
      
      return success;
    } catch (e) {
      debugPrint('Erro ao marcar como spam: $e');
      return false;
    }
  }

  // Adicionar número à lista negra
  Future<bool> addToBlacklist(String phoneNumber, String reason) async {
    try {
      final blockRule = BlockRule(
        id: _uuid.v4(),
        userId: 'current_user',
        ruleName: 'Bloqueio Manual - $phoneNumber',
        ruleType: RuleType.blacklist,
        pattern: phoneNumber,
        isActive: true,
        priority: 10,
        createdAt: DateTime.now(),
      );
      
      return await _repository.createBlockRule(blockRule);
    } catch (e) {
      debugPrint('Erro ao adicionar à lista negra: $e');
      return false;
    }
  }

  // Remover número da lista negra
  Future<bool> removeFromBlacklist(String phoneNumber) async {
    try {
      final rules = await _repository.getBlockRules('current_user');
      final rule = rules.firstWhere(
        (r) => r.ruleType == RuleType.blacklist && r.pattern == phoneNumber,
      );
      
      return await _repository.deleteBlockRule(rule.id);
    } catch (e) {
      debugPrint('Erro ao remover da lista negra: $e');
      return false;
    }
  }

  // Obter estatísticas de chamadas
  Future<Map<String, dynamic>> getCallStatistics() async {
    try {
      final stats = await _repository.getStatistics('current_user');
      final effectiveness = await _repository.getBlockingEffectiveness('current_user');
      
      return {
        'totalCalls': stats['totalCalls'] ?? 0,
        'blockedCalls': stats['blockedCalls'] ?? 0,
        'blockRate': effectiveness['callBlockRate'] ?? 0,
        'recentActivity': await _repository.getRecentActivity('current_user', limit: 10),
      };
    } catch (e) {
      debugPrint('Erro ao obter estatísticas: $e');
      return {
        'totalCalls': 0,
        'blockedCalls': 0,
        'blockRate': 0,
        'recentActivity': [],
      };
    }
  }

  // Sincronizar com logs do sistema
  Future<void> syncWithSystemLogs() async {
    try {
      debugPrint('Sincronizando com logs do sistema...');
      
      // Buscar todas as chamadas dos últimos 7 dias
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final entries = await CallLogPlugin.CallLog.query(
        dateFrom: weekAgo.millisecondsSinceEpoch,
        dateTo: DateTime.now().millisecondsSinceEpoch,
      );

      int syncedCount = 0;
      for (final entry in entries) {
        // Verificar se já existe no banco
        final existingCalls = await _repository.getCallHistory('current_user');
        final exists = existingCalls.any((call) => 
          call.phoneNumber == (entry.number ?? '') &&
          call.timestamp.millisecondsSinceEpoch == (entry.timestamp ?? 0)
        );
        
        if (!exists) {
          await _processCallEntry(entry);
          syncedCount++;
        }
      }
      
      debugPrint('Sincronização concluída: $syncedCount novas chamadas');
    } catch (e) {
      debugPrint('Erro na sincronização: $e');
    }
  }

  // Parar monitoramento
  void stopMonitoring() {
    _callMonitorTimer?.cancel();
    _callMonitorTimer = null;
    
    // Fechar streams
    for (final controller in _callStreamControllers) {
      controller.close();
    }
    _callStreamControllers.clear();
    
    debugPrint('Monitoramento de chamadas parado');
  }

  // Limpar recursos
  Future<void> dispose() async {
    stopMonitoring();
    await _repository.close();
  }
}