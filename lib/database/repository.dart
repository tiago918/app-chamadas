import 'package:sqflite/sqflite.dart' as Sqflite;
import '../models/models.dart';
import 'database_helper.dart';

class Repository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // User Repository Methods
  Future<bool> createUser(User user) async {
    try {
      await _databaseHelper.insertUser(user);
      return true;
    } catch (e) {
      print('Erro ao criar usuário: $e');
      return false;
    }
  }

  Future<User?> getUser(String id) async {
    try {
      return await _databaseHelper.getUserById(id);
    } catch (e) {
      print('Erro ao buscar usuário: $e');
      return null;
    }
  }

  Future<User?> getUserByEmail(String email) async {
    try {
      return await _databaseHelper.getUserByEmail(email);
    } catch (e) {
      print('Erro ao buscar usuário por email: $e');
      return null;
    }
  }

  Future<bool> updateUser(User user) async {
    try {
      final result = await _databaseHelper.updateUser(user);
      return result > 0;
    } catch (e) {
      print('Erro ao atualizar usuário: $e');
      return false;
    }
  }

  Future<bool> deleteUser(String id) async {
    try {
      final result = await _databaseHelper.deleteUser(id);
      return result > 0;
    } catch (e) {
      print('Erro ao deletar usuário: $e');
      return false;
    }
  }

  // CallLog Repository Methods
  Future<bool> saveCallLog(CallLog callLog) async {
    try {
      await _databaseHelper.insertCallLog(callLog);
      return true;
    } catch (e) {
      print('Erro ao salvar log de chamada: $e');
      return false;
    }
  }

  Future<List<CallLog>> getCallHistory(String userId, {int? limit}) async {
    try {
      return await _databaseHelper.getCallLogsByUserId(userId, limit: limit);
    } catch (e) {
      print('Erro ao buscar histórico de chamadas: $e');
      return [];
    }
  }

  Future<List<CallLog>> getBlockedCalls(String userId) async {
    try {
      return await _databaseHelper.getBlockedCalls(userId);
    } catch (e) {
      print('Erro ao buscar chamadas bloqueadas: $e');
      return [];
    }
  }

  Future<bool> updateCallLog(CallLog callLog) async {
    try {
      final result = await _databaseHelper.updateCallLog(callLog);
      return result > 0;
    } catch (e) {
      print('Erro ao atualizar log de chamada: $e');
      return false;
    }
  }

  Future<bool> deleteCallLog(String id) async {
    try {
      final result = await _databaseHelper.deleteCallLog(id);
      return result > 0;
    } catch (e) {
      print('Erro ao deletar log de chamada: $e');
      return false;
    }
  }

  // SmsLog Repository Methods
  Future<bool> saveSmsLog(SmsLog smsLog) async {
    try {
      await _databaseHelper.insertSmsLog(smsLog);
      return true;
    } catch (e) {
      print('Erro ao salvar log de SMS: $e');
      return false;
    }
  }

  Future<List<SmsLog>> getMessageHistory(String userId, {int? limit}) async {
    try {
      return await _databaseHelper.getSmsLogsByUserId(userId, limit: limit);
    } catch (e) {
      print('Erro ao buscar histórico de mensagens: $e');
      return [];
    }
  }

  Future<List<SmsLog>> getBlockedMessages(String userId) async {
    try {
      return await _databaseHelper.getBlockedMessages(userId);
    } catch (e) {
      print('Erro ao buscar mensagens bloqueadas: $e');
      return [];
    }
  }

  Future<bool> updateSmsLog(SmsLog smsLog) async {
    try {
      final result = await _databaseHelper.updateSmsLog(smsLog);
      return result > 0;
    } catch (e) {
      print('Erro ao atualizar log de SMS: $e');
      return false;
    }
  }

  Future<bool> deleteSmsLog(String id) async {
    try {
      final result = await _databaseHelper.deleteSmsLog(id);
      return result > 0;
    } catch (e) {
      print('Erro ao deletar log de SMS: $e');
      return false;
    }
  }

  // BlockRule Repository Methods
  Future<bool> createBlockRule(BlockRule blockRule) async {
    try {
      await _databaseHelper.insertBlockRule(blockRule);
      return true;
    } catch (e) {
      print('Erro ao criar regra de bloqueio: $e');
      return false;
    }
  }

  Future<List<BlockRule>> getBlockRules(String userId) async {
    try {
      return await _databaseHelper.getBlockRulesByUserId(userId);
    } catch (e) {
      print('Erro ao buscar regras de bloqueio: $e');
      return [];
    }
  }

  Future<List<BlockRule>> getActiveBlockRules(String userId) async {
    try {
      return await _databaseHelper.getActiveBlockRules(userId);
    } catch (e) {
      print('Erro ao buscar regras ativas: $e');
      return [];
    }
  }

  Future<bool> updateBlockRule(BlockRule blockRule) async {
    try {
      final result = await _databaseHelper.updateBlockRule(blockRule);
      return result > 0;
    } catch (e) {
      print('Erro ao atualizar regra de bloqueio: $e');
      return false;
    }
  }

  Future<bool> deleteBlockRule(String id) async {
    try {
      final result = await _databaseHelper.deleteBlockRule(id);
      return result > 0;
    } catch (e) {
      print('Erro ao deletar regra de bloqueio: $e');
      return false;
    }
  }

  Future<bool> toggleBlockRule(String id, bool isActive) async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.update(
        'block_rules',
        {'is_active': isActive ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      return result > 0;
    } catch (e) {
      print('Erro ao alternar regra de bloqueio: $e');
      return false;
    }
  }

  // Contact Repository Methods
  Future<bool> createContact(Contact contact) async {
    try {
      await _databaseHelper.insertContact(contact);
      return true;
    } catch (e) {
      print('Erro ao criar contato: $e');
      return false;
    }
  }

  Future<List<Contact>> getContacts(String userId) async {
    try {
      return await _databaseHelper.getContactsByUserId(userId);
    } catch (e) {
      print('Erro ao buscar contatos: $e');
      return [];
    }
  }

  Future<Contact?> getContactByPhone(String userId, String phoneNumber) async {
    try {
      return await _databaseHelper.getContactByPhoneNumber(userId, phoneNumber);
    } catch (e) {
      print('Erro ao buscar contato por telefone: $e');
      return null;
    }
  }

  Future<List<Contact>> getTrustedContacts(String userId) async {
    try {
      return await _databaseHelper.getTrustedContacts(userId);
    } catch (e) {
      print('Erro ao buscar contatos confiáveis: $e');
      return [];
    }
  }

  Future<List<Contact>> getBlockedContacts(String userId) async {
    try {
      return await _databaseHelper.getBlockedContacts(userId);
    } catch (e) {
      print('Erro ao buscar contatos bloqueados: $e');
      return [];
    }
  }

  Future<bool> updateContact(Contact contact) async {
    try {
      final result = await _databaseHelper.updateContact(contact);
      return result > 0;
    } catch (e) {
      print('Erro ao atualizar contato: $e');
      return false;
    }
  }

  Future<bool> deleteContact(String id) async {
    try {
      final result = await _databaseHelper.deleteContact(id);
      return result > 0;
    } catch (e) {
      print('Erro ao deletar contato: $e');
      return false;
    }
  }

  Future<bool> toggleContactTrust(String id, bool isTrusted) async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.update(
        'contacts',
        {'is_trusted': isTrusted ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      return result > 0;
    } catch (e) {
      print('Erro ao alternar confiança do contato: $e');
      return false;
    }
  }

  Future<bool> toggleContactBlock(String id, bool isBlocked) async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.update(
        'contacts',
        {'is_blocked': isBlocked ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      return result > 0;
    } catch (e) {
      print('Erro ao alternar bloqueio do contato: $e');
      return false;
    }
  }

  // Statistics and Analytics
  Future<Map<String, int>> getStatistics(String userId) async {
    try {
      return await _databaseHelper.getStatistics(userId);
    } catch (e) {
      print('Erro ao buscar estatísticas: $e');
      return {
        'totalCalls': 0,
        'blockedCalls': 0,
        'totalMessages': 0,
        'blockedMessages': 0,
        'totalContacts': 0,
        'activeRules': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getRecentActivity(String userId, {int limit = 20}) async {
    try {
      final db = await _databaseHelper.database;
      
      // Buscar atividades recentes (chamadas e mensagens)
      final recentCalls = await db.rawQuery('''
        SELECT 'call' as type, phone_number as contact, timestamp, is_blocked
        FROM call_logs 
        WHERE user_id = ? 
        ORDER BY timestamp DESC 
        LIMIT ?
      ''', [userId, limit ~/ 2]);
      
      final recentMessages = await db.rawQuery('''
        SELECT 'message' as type, sender as contact, timestamp, is_blocked
        FROM sms_logs 
        WHERE user_id = ? 
        ORDER BY timestamp DESC 
        LIMIT ?
      ''', [userId, limit ~/ 2]);
      
      final allActivity = [...recentCalls, ...recentMessages];
      allActivity.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      
      return allActivity.take(limit).toList();
    } catch (e) {
      print('Erro ao buscar atividade recente: $e');
      return [];
    }
  }

  Future<Map<String, int>> getBlockingEffectiveness(String userId) async {
    try {
      final db = await _databaseHelper.database;
      
      final last30Days = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000;
      
      final callsBlockedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM call_logs WHERE user_id = ? AND is_blocked = 1 AND timestamp > ?',
        [userId, last30Days]
      );
      final callsBlocked = callsBlockedResult.first['count'] as int? ?? 0;
      
      final messagesBlockedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sms_logs WHERE user_id = ? AND is_blocked = 1 AND timestamp > ?',
        [userId, last30Days]
      );
      final messagesBlocked = messagesBlockedResult.first['count'] as int? ?? 0;
      
      final totalCallsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM call_logs WHERE user_id = ? AND timestamp > ?',
        [userId, last30Days]
      );
      final totalCalls = totalCallsResult.first['count'] as int? ?? 0;
      
      final totalMessagesResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sms_logs WHERE user_id = ? AND timestamp > ?',
        [userId, last30Days]
      );
      final totalMessages = totalMessagesResult.first['count'] as int? ?? 0;
      
      return {
        'callsBlocked': callsBlocked,
        'messagesBlocked': messagesBlocked,
        'totalCalls': totalCalls,
        'totalMessages': totalMessages,
        'callBlockRate': totalCalls > 0 ? ((callsBlocked / totalCalls) * 100).round() : 0,
        'messageBlockRate': totalMessages > 0 ? ((messagesBlocked / totalMessages) * 100).round() : 0,
      };
    } catch (e) {
      print('Erro ao calcular efetividade do bloqueio: $e');
      return {
        'callsBlocked': 0,
        'messagesBlocked': 0,
        'totalCalls': 0,
        'totalMessages': 0,
        'callBlockRate': 0,
        'messageBlockRate': 0,
      };
    }
  }

  // Maintenance Methods
  Future<bool> cleanOldData(String userId, {int daysToKeep = 90}) async {
    try {
      await _databaseHelper.cleanOldData(userId, daysToKeep: daysToKeep);
      return true;
    } catch (e) {
      print('Erro ao limpar dados antigos: $e');
      return false;
    }
  }

  Future<bool> exportData(String userId) async {
    try {
      // Implementar exportação de dados
      // Por enquanto, apenas retorna true
      return true;
    } catch (e) {
      print('Erro ao exportar dados: $e');
      return false;
    }
  }

  Future<bool> importData(String userId, Map<String, dynamic> data) async {
    try {
      // Implementar importação de dados
      // Por enquanto, apenas retorna true
      return true;
    } catch (e) {
      print('Erro ao importar dados: $e');
      return false;
    }
  }

  Future<void> close() async {
    await _databaseHelper.close();
  }
}