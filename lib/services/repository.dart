import '../database/database_helper.dart';
import '../models/call_log.dart';
import '../models/sms_log.dart';
import '../models/block_rule.dart';
import '../models/contact.dart';
import '../models/user.dart';

/// Classe Repository que centraliza o acesso aos dados
class Repository {
  final DatabaseHelper _databaseHelper;
  
  Repository(this._databaseHelper);

  // Métodos para CallLog
  Future<List<CallLog>> getAllCallLogs() async {
    return await _databaseHelper.getCallLogsByUserId('current_user');
  }

  Future<void> insertCallLog(CallLog callLog) async {
    await _databaseHelper.insertCallLog(callLog);
  }

  Future<void> updateCallLog(CallLog callLog) async {
    await _databaseHelper.updateCallLog(callLog);
  }

  Future<void> deleteCallLog(String id) async {
    await _databaseHelper.deleteCallLog(id);
  }

  Future<List<CallLog>> getCallLogsByNumber(String phoneNumber) async {
    final allCalls = await _databaseHelper.getCallLogsByUserId('current_user');
    return allCalls.where((call) => call.phoneNumber == phoneNumber).toList();
  }

  // Métodos para SmsLog
  Future<List<SmsLog>> getAllSmsLogs() async {
    return await _databaseHelper.getSmsLogsByUserId('current_user');
  }

  Future<void> insertSmsLog(SmsLog smsLog) async {
    await _databaseHelper.insertSmsLog(smsLog);
  }

  Future<void> updateSmsLog(SmsLog smsLog) async {
    await _databaseHelper.updateSmsLog(smsLog);
  }

  Future<void> deleteSmsLog(String id) async {
    await _databaseHelper.deleteSmsLog(id);
  }

  Future<List<SmsLog>> getSmsLogsByNumber(String phoneNumber) async {
    final allSms = await _databaseHelper.getSmsLogsByUserId('current_user');
    return allSms.where((sms) => sms.sender == phoneNumber).toList();
  }

  // Métodos para BlockRule
  Future<List<BlockRule>> getAllBlockRules() async {
    return await _databaseHelper.getBlockRulesByUserId('current_user');
  }

  Future<void> insertBlockRule(BlockRule blockRule) async {
    await _databaseHelper.insertBlockRule(blockRule);
  }

  Future<void> updateBlockRule(BlockRule blockRule) async {
    await _databaseHelper.updateBlockRule(blockRule);
  }

  Future<void> deleteBlockRule(String id) async {
    await _databaseHelper.deleteBlockRule(id);
  }

  Future<List<BlockRule>> getActiveBlockRules() async {
    return await _databaseHelper.getActiveBlockRules('current_user');
  }

  // Métodos para Contact
  Future<List<Contact>> getAllContacts() async {
    return await _databaseHelper.getContactsByUserId('current_user');
  }

  Future<void> insertContact(Contact contact) async {
    await _databaseHelper.insertContact(contact);
  }

  Future<void> updateContact(Contact contact) async {
    await _databaseHelper.updateContact(contact);
  }

  Future<void> deleteContact(String id) async {
    await _databaseHelper.deleteContact(id);
  }

  Future<Contact?> getContactByNumber(String phoneNumber) async {
    return await _databaseHelper.getContactByPhoneNumber('current_user', phoneNumber);
  }

  // Métodos para User
  Future<User?> getCurrentUser() async {
    return await _databaseHelper.getUserById('current_user');
  }

  Future<void> insertUser(User user) async {
    await _databaseHelper.insertUser(user);
  }

  Future<void> updateUser(User user) async {
    await _databaseHelper.updateUser(user);
  }

  // Métodos de estatísticas
  Future<int> getTotalCallsCount() async {
    final calls = await getAllCallLogs();
    return calls.length;
  }

  Future<int> getTotalSmsCount() async {
    final sms = await getAllSmsLogs();
    return sms.length;
  }

  Future<int> getBlockedCallsCount() async {
    final calls = await getAllCallLogs();
    return calls.where((call) => call.isBlocked).length;
  }

  Future<int> getBlockedSmsCount() async {
    final sms = await getAllSmsLogs();
    return sms.where((msg) => msg.isBlocked).length;
  }

  Future<List<CallLog>> getRecentCalls({int limit = 10}) async {
    final calls = await getAllCallLogs();
    calls.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return calls.take(limit).toList();
  }

  Future<List<SmsLog>> getRecentSms({int limit = 10}) async {
    final sms = await getAllSmsLogs();
    sms.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sms.take(limit).toList();
  }
}