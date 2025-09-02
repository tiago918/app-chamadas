import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

/// Serviço responsável pela segurança e criptografia do aplicativo
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Chaves para armazenamento seguro
  static const String _userTokenKey = 'user_token';
  static const String _encryptionKeyKey = 'encryption_key';
  static const String _appSecretKey = 'app_secret';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _pinHashKey = 'pin_hash';
  static const String _saltKey = 'salt';

  /// Inicializa o serviço de segurança
  Future<void> initialize() async {
    try {
      // Gera chave de criptografia se não existir
      final encryptionKey = await _secureStorage.read(key: _encryptionKeyKey);
      if (encryptionKey == null) {
        await _generateEncryptionKey();
      }

      // Gera segredo do app se não existir
      final appSecret = await _secureStorage.read(key: _appSecretKey);
      if (appSecret == null) {
        await _generateAppSecret();
      }

      // Gera salt se não existir
      final salt = await _secureStorage.read(key: _saltKey);
      if (salt == null) {
        await _generateSalt();
      }
    } catch (e) {
      debugPrint('Erro ao inicializar serviço de segurança: $e');
    }
  }

  /// Gera uma chave de criptografia aleatória
  Future<void> _generateEncryptionKey() async {
    try {
      final random = Random.secure();
      final key = List<int>.generate(32, (i) => random.nextInt(256));
      final keyString = base64Encode(key);
      await _secureStorage.write(key: _encryptionKeyKey, value: keyString);
    } catch (e) {
      debugPrint('Erro ao gerar chave de criptografia: $e');
    }
  }

  /// Gera um segredo único para o aplicativo
  Future<void> _generateAppSecret() async {
    try {
      final random = Random.secure();
      final secret = List<int>.generate(64, (i) => random.nextInt(256));
      final secretString = base64Encode(secret);
      await _secureStorage.write(key: _appSecretKey, value: secretString);
    } catch (e) {
      debugPrint('Erro ao gerar segredo do app: $e');
    }
  }

  /// Gera um salt para hash de senhas
  Future<void> _generateSalt() async {
    try {
      final random = Random.secure();
      final salt = List<int>.generate(16, (i) => random.nextInt(256));
      final saltString = base64Encode(salt);
      await _secureStorage.write(key: _saltKey, value: saltString);
    } catch (e) {
      debugPrint('Erro ao gerar salt: $e');
    }
  }

  /// Criptografa dados sensíveis
  Future<String?> encryptData(String data) async {
    try {
      final key = await _secureStorage.read(key: _encryptionKeyKey);
      if (key == null) return null;

      final keyBytes = base64Decode(key);
      final dataBytes = utf8.encode(data);
      
      // Implementação simples de XOR (em produção, use AES)
      final encryptedBytes = <int>[];
      for (int i = 0; i < dataBytes.length; i++) {
        encryptedBytes.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      
      return base64Encode(encryptedBytes);
    } catch (e) {
      debugPrint('Erro ao criptografar dados: $e');
      return null;
    }
  }

  /// Descriptografa dados sensíveis
  Future<String?> decryptData(String encryptedData) async {
    try {
      final key = await _secureStorage.read(key: _encryptionKeyKey);
      if (key == null) return null;

      final keyBytes = base64Decode(key);
      final encryptedBytes = base64Decode(encryptedData);
      
      // Implementação simples de XOR (em produção, use AES)
      final decryptedBytes = <int>[];
      for (int i = 0; i < encryptedBytes.length; i++) {
        decryptedBytes.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      
      return utf8.decode(decryptedBytes);
    } catch (e) {
      debugPrint('Erro ao descriptografar dados: $e');
      return null;
    }
  }

  /// Gera hash seguro de uma senha com salt
  Future<String?> hashPassword(String password) async {
    try {
      final salt = await _secureStorage.read(key: _saltKey);
      if (salt == null) return null;

      final saltBytes = base64Decode(salt);
      final passwordBytes = utf8.encode(password);
      final combined = [...passwordBytes, ...saltBytes];
      
      final digest = sha256.convert(combined);
      return digest.toString();
    } catch (e) {
      debugPrint('Erro ao gerar hash da senha: $e');
      return null;
    }
  }

  /// Verifica se uma senha corresponde ao hash armazenado
  Future<bool> verifyPassword(String password, String storedHash) async {
    try {
      final hash = await hashPassword(password);
      return hash == storedHash;
    } catch (e) {
      debugPrint('Erro ao verificar senha: $e');
      return false;
    }
  }

  /// Define um PIN de segurança
  Future<bool> setSecurityPin(String pin) async {
    try {
      final hash = await hashPassword(pin);
      if (hash == null) return false;
      
      await _secureStorage.write(key: _pinHashKey, value: hash);
      return true;
    } catch (e) {
      debugPrint('Erro ao definir PIN: $e');
      return false;
    }
  }

  /// Verifica o PIN de segurança
  Future<bool> verifySecurityPin(String pin) async {
    try {
      final storedHash = await _secureStorage.read(key: _pinHashKey);
      if (storedHash == null) return false;
      
      return await verifyPassword(pin, storedHash);
    } catch (e) {
      debugPrint('Erro ao verificar PIN: $e');
      return false;
    }
  }

  /// Verifica se existe um PIN configurado
  Future<bool> hasPinConfigured() async {
    try {
      final pinHash = await _secureStorage.read(key: _pinHashKey);
      return pinHash != null;
    } catch (e) {
      debugPrint('Erro ao verificar PIN configurado: $e');
      return false;
    }
  }

  /// Remove o PIN de segurança
  Future<bool> removeSecurityPin() async {
    try {
      await _secureStorage.delete(key: _pinHashKey);
      return true;
    } catch (e) {
      debugPrint('Erro ao remover PIN: $e');
      return false;
    }
  }

  /// Armazena token de usuário de forma segura
  Future<bool> storeUserToken(String token) async {
    try {
      final encryptedToken = await encryptData(token);
      if (encryptedToken == null) return false;
      
      await _secureStorage.write(key: _userTokenKey, value: encryptedToken);
      return true;
    } catch (e) {
      debugPrint('Erro ao armazenar token: $e');
      return false;
    }
  }

  /// Recupera token de usuário
  Future<String?> getUserToken() async {
    try {
      final encryptedToken = await _secureStorage.read(key: _userTokenKey);
      if (encryptedToken == null) return null;
      
      return await decryptData(encryptedToken);
    } catch (e) {
      debugPrint('Erro ao recuperar token: $e');
      return null;
    }
  }

  /// Remove token de usuário
  Future<bool> removeUserToken() async {
    try {
      await _secureStorage.delete(key: _userTokenKey);
      return true;
    } catch (e) {
      debugPrint('Erro ao remover token: $e');
      return false;
    }
  }

  /// Habilita/desabilita autenticação biométrica
  Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      await _secureStorage.write(
        key: _biometricEnabledKey, 
        value: enabled.toString(),
      );
      return true;
    } catch (e) {
      debugPrint('Erro ao configurar biometria: $e');
      return false;
    }
  }

  /// Verifica se a autenticação biométrica está habilitada
  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _secureStorage.read(key: _biometricEnabledKey);
      return enabled == 'true';
    } catch (e) {
      debugPrint('Erro ao verificar biometria: $e');
      return false;
    }
  }

  /// Gera um ID único para sessão
  String generateSessionId() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = List<int>.generate(16, (i) => random.nextInt(256));
    final combined = [...utf8.encode(timestamp.toString()), ...randomBytes];
    return sha256.convert(combined).toString().substring(0, 32);
  }

  /// Valida a integridade de dados
  String generateDataHash(String data) {
    final bytes = utf8.encode(data);
    return sha256.convert(bytes).toString();
  }

  /// Verifica a integridade de dados
  bool verifyDataIntegrity(String data, String expectedHash) {
    final actualHash = generateDataHash(data);
    return actualHash == expectedHash;
  }

  /// Limpa todos os dados seguros (usar com cuidado)
  Future<bool> clearAllSecureData() async {
    try {
      await _secureStorage.deleteAll();
      return true;
    } catch (e) {
      debugPrint('Erro ao limpar dados seguros: $e');
      return false;
    }
  }

  /// Verifica se o aplicativo está sendo executado em um ambiente seguro
  Future<SecurityCheckResult> performSecurityCheck() async {
    List<String> issues = [];
    List<String> warnings = [];
    
    try {
      // Verifica se as chaves de segurança existem
      final encryptionKey = await _secureStorage.read(key: _encryptionKeyKey);
      if (encryptionKey == null) {
        issues.add('Chave de criptografia não encontrada');
      }
      
      final appSecret = await _secureStorage.read(key: _appSecretKey);
      if (appSecret == null) {
        issues.add('Segredo do aplicativo não encontrado');
      }
      
      // Verifica se está em modo debug
      if (kDebugMode) {
        warnings.add('Aplicativo em modo debug');
      }
      
      // Adicione mais verificações conforme necessário
      
    } catch (e) {
      issues.add('Erro durante verificação de segurança: $e');
    }
    
    return SecurityCheckResult(
      isSecure: issues.isEmpty,
      issues: issues,
      warnings: warnings,
    );
  }
}

/// Resultado da verificação de segurança
class SecurityCheckResult {
  final bool isSecure;
  final List<String> issues;
  final List<String> warnings;
  
  const SecurityCheckResult({
    required this.isSecure,
    required this.issues,
    required this.warnings,
  });
  
  bool get hasIssues => issues.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  int get totalProblems => issues.length + warnings.length;
}