import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'chamadas_avancado.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Criar tabela de usuários
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        phone_number TEXT UNIQUE NOT NULL,
        is_premium INTEGER DEFAULT 0,
        settings TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Criar tabela de logs de chamadas
    await db.execute('''
      CREATE TABLE call_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        contact_name TEXT,
        timestamp INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        call_type TEXT NOT NULL,
        is_blocked INTEGER DEFAULT 0,
        spam_score REAL DEFAULT 0.0,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Criar tabela de logs de SMS
    await db.execute('''
      CREATE TABLE sms_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        sender TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        message_type TEXT NOT NULL,
        is_blocked INTEGER DEFAULT 0,
        spam_score REAL DEFAULT 0.0,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Criar tabela de regras de bloqueio
    await db.execute('''
      CREATE TABLE block_rules (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        rule_name TEXT NOT NULL,
        rule_type TEXT NOT NULL,
        pattern TEXT,
        is_active INTEGER DEFAULT 1,
        priority INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Criar tabela de contatos
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        is_trusted INTEGER DEFAULT 0,
        is_blocked INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        last_contact_at INTEGER,
        photo_url TEXT,
        notes TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Criar índices para melhor performance
    await db.execute('CREATE INDEX idx_call_logs_user_id ON call_logs (user_id)');
    await db.execute('CREATE INDEX idx_call_logs_timestamp ON call_logs (timestamp)');
    await db.execute('CREATE INDEX idx_sms_logs_user_id ON sms_logs (user_id)');
    await db.execute('CREATE INDEX idx_sms_logs_timestamp ON sms_logs (timestamp)');
    await db.execute('CREATE INDEX idx_block_rules_user_id ON block_rules (user_id)');
    await db.execute('CREATE INDEX idx_contacts_user_id ON contacts (user_id)');
    await db.execute('CREATE INDEX idx_contacts_phone_number ON contacts (phone_number)');

    // Inserir dados iniciais
    await _insertInitialData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Implementar migrações futuras aqui
    if (oldVersion < newVersion) {
      // Exemplo de migração
      // await db.execute('ALTER TABLE users ADD COLUMN new_field TEXT');
    }
  }

  Future<void> _insertInitialData(Database db) async {
    // Inserir regras de bloqueio padrão do sistema
    final defaultRules = [
      {
        'id': 'system_rule_1',
        'user_id': 'system',
        'rule_name': 'Números Desconhecidos',
        'rule_type': 'pattern',
        'pattern': r'^(?!.*contacts).*$',
        'is_active': 0, // Desativado por padrão
        'priority': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      {
        'id': 'system_rule_2',
        'user_id': 'system',
        'rule_name': 'Chamadas Internacionais',
        'rule_type': 'pattern',
        'pattern': r'^\\+(?!55).*$',
        'is_active': 0,
        'priority': 2,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      {
        'id': 'system_rule_3',
        'user_id': 'system',
        'rule_name': 'Códigos Curtos Suspeitos',
        'rule_type': 'pattern',
        'pattern': r'^[0-9]{4,6}$',
        'is_active': 1, // Ativado por padrão
        'priority': 3,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
    ];

    for (final rule in defaultRules) {
      await db.insert('block_rules', rule);
    }
  }

  // Métodos CRUD para Users
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUserById(String id) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(String id) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Métodos CRUD para CallLogs
  Future<int> insertCallLog(CallLog callLog) async {
    final db = await database;
    return await db.insert('call_logs', callLog.toMap());
  }

  Future<List<CallLog>> getCallLogsByUserId(String userId, {int? limit}) async {
    final db = await database;
    final maps = await db.query(
      'call_logs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((map) => CallLog.fromMap(map)).toList();
  }

  Future<List<CallLog>> getBlockedCalls(String userId) async {
    final db = await database;
    final maps = await db.query(
      'call_logs',
      where: 'user_id = ? AND is_blocked = 1',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => CallLog.fromMap(map)).toList();
  }

  Future<int> updateCallLog(CallLog callLog) async {
    final db = await database;
    return await db.update(
      'call_logs',
      callLog.toMap(),
      where: 'id = ?',
      whereArgs: [callLog.id],
    );
  }

  Future<int> deleteCallLog(String id) async {
    final db = await database;
    return await db.delete(
      'call_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Métodos CRUD para SmsLogs
  Future<int> insertSmsLog(SmsLog smsLog) async {
    final db = await database;
    return await db.insert('sms_logs', smsLog.toMap());
  }

  Future<List<SmsLog>> getSmsLogsByUserId(String userId, {int? limit}) async {
    final db = await database;
    final maps = await db.query(
      'sms_logs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((map) => SmsLog.fromMap(map)).toList();
  }

  Future<List<SmsLog>> getBlockedMessages(String userId) async {
    final db = await database;
    final maps = await db.query(
      'sms_logs',
      where: 'user_id = ? AND is_blocked = 1',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => SmsLog.fromMap(map)).toList();
  }

  Future<int> updateSmsLog(SmsLog smsLog) async {
    final db = await database;
    return await db.update(
      'sms_logs',
      smsLog.toMap(),
      where: 'id = ?',
      whereArgs: [smsLog.id],
    );
  }

  Future<int> deleteSmsLog(String id) async {
    final db = await database;
    return await db.delete(
      'sms_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Métodos CRUD para BlockRules
  Future<int> insertBlockRule(BlockRule blockRule) async {
    final db = await database;
    return await db.insert('block_rules', blockRule.toMap());
  }

  Future<List<BlockRule>> getBlockRulesByUserId(String userId) async {
    final db = await database;
    final maps = await db.query(
      'block_rules',
      where: 'user_id = ? OR user_id = "system"',
      whereArgs: [userId],
      orderBy: 'priority ASC',
    );
    return maps.map((map) => BlockRule.fromMap(map)).toList();
  }

  Future<List<BlockRule>> getActiveBlockRules(String userId) async {
    final db = await database;
    final maps = await db.query(
      'block_rules',
      where: '(user_id = ? OR user_id = "system") AND is_active = 1',
      whereArgs: [userId],
      orderBy: 'priority ASC',
    );
    return maps.map((map) => BlockRule.fromMap(map)).toList();
  }

  Future<int> updateBlockRule(BlockRule blockRule) async {
    final db = await database;
    return await db.update(
      'block_rules',
      blockRule.toMap(),
      where: 'id = ?',
      whereArgs: [blockRule.id],
    );
  }

  Future<int> deleteBlockRule(String id) async {
    final db = await database;
    return await db.delete(
      'block_rules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Métodos CRUD para Contacts
  Future<int> insertContact(Contact contact) async {
    final db = await database;
    return await db.insert('contacts', contact.toMap());
  }

  Future<List<Contact>> getContactsByUserId(String userId) async {
    final db = await database;
    final maps = await db.query(
      'contacts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Contact.fromMap(map)).toList();
  }

  Future<Contact?> getContactByPhoneNumber(String userId, String phoneNumber) async {
    final db = await database;
    final maps = await db.query(
      'contacts',
      where: 'user_id = ? AND phone_number = ?',
      whereArgs: [userId, phoneNumber],
    );
    if (maps.isNotEmpty) {
      return Contact.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Contact>> getTrustedContacts(String userId) async {
    final db = await database;
    final maps = await db.query(
      'contacts',
      where: 'user_id = ? AND is_trusted = 1',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Contact.fromMap(map)).toList();
  }

  Future<List<Contact>> getBlockedContacts(String userId) async {
    final db = await database;
    final maps = await db.query(
      'contacts',
      where: 'user_id = ? AND is_blocked = 1',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Contact.fromMap(map)).toList();
  }

  Future<int> updateContact(Contact contact) async {
    final db = await database;
    return await db.update(
      'contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<int> deleteContact(String id) async {
    final db = await database;
    return await db.delete(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Métodos de busca e estatísticas
  Future<Map<String, int>> getStatistics(String userId) async {
    final db = await database;
    
    final totalCalls = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM call_logs WHERE user_id = ?', [userId])
    ) ?? 0;
    
    final blockedCalls = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM call_logs WHERE user_id = ? AND is_blocked = 1', [userId])
    ) ?? 0;
    
    final totalMessages = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sms_logs WHERE user_id = ?', [userId])
    ) ?? 0;
    
    final blockedMessages = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sms_logs WHERE user_id = ? AND is_blocked = 1', [userId])
    ) ?? 0;
    
    final totalContacts = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM contacts WHERE user_id = ?', [userId])
    ) ?? 0;
    
    final activeRules = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM block_rules WHERE (user_id = ? OR user_id = "system") AND is_active = 1', [userId])
    ) ?? 0;

    return {
      'totalCalls': totalCalls,
      'blockedCalls': blockedCalls,
      'totalMessages': totalMessages,
      'blockedMessages': blockedMessages,
      'totalContacts': totalContacts,
      'activeRules': activeRules,
    };
  }

  // Limpar dados antigos
  Future<void> cleanOldData(String userId, {int daysToKeep = 90}) async {
    final db = await database;
    final cutoffTime = DateTime.now().subtract(Duration(days: daysToKeep)).millisecondsSinceEpoch ~/ 1000;
    
    await db.delete(
      'call_logs',
      where: 'user_id = ? AND timestamp < ?',
      whereArgs: [userId, cutoffTime],
    );
    
    await db.delete(
      'sms_logs',
      where: 'user_id = ? AND timestamp < ?',
      whereArgs: [userId, cutoffTime],
    );
  }

  // Fechar banco de dados
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}