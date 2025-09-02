import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Serviço responsável por gerenciar todas as permissões do aplicativo
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // Lista de permissões necessárias para o funcionamento completo do app
  static const List<Permission> _requiredPermissions = [
    Permission.phone,
    Permission.sms,
    Permission.contacts,
    Permission.storage,
    Permission.manageExternalStorage,
    Permission.systemAlertWindow,
    Permission.notification,
  ];

  // Permissões críticas que são obrigatórias
  static const List<Permission> _criticalPermissions = [
    Permission.phone,
    Permission.sms,
  ];

  /// Verifica se todas as permissões necessárias foram concedidas
  Future<bool> hasAllRequiredPermissions() async {
    try {
      for (Permission permission in _requiredPermissions) {
        final status = await permission.status;
        if (!status.isGranted) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Erro ao verificar permissões: $e');
      return false;
    }
  }

  /// Verifica se as permissões críticas foram concedidas
  Future<bool> hasCriticalPermissions() async {
    try {
      for (Permission permission in _criticalPermissions) {
        final status = await permission.status;
        if (!status.isGranted) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Erro ao verificar permissões críticas: $e');
      return false;
    }
  }

  /// Solicita todas as permissões necessárias
  Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    try {
      return await _requiredPermissions.request();
    } catch (e) {
      debugPrint('Erro ao solicitar permissões: $e');
      return {};
    }
  }

  /// Solicita uma permissão específica
  Future<PermissionStatus> requestPermission(Permission permission) async {
    try {
      return await permission.request();
    } catch (e) {
      debugPrint('Erro ao solicitar permissão $permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Verifica o status de uma permissão específica
  Future<PermissionStatus> checkPermission(Permission permission) async {
    try {
      return await permission.status;
    } catch (e) {
      debugPrint('Erro ao verificar permissão $permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Verifica se o aplicativo pode interceptar chamadas
  Future<bool> canInterceptCalls() async {
    try {
      final phoneStatus = await Permission.phone.status;
      final systemAlertStatus = await Permission.systemAlertWindow.status;
      return phoneStatus.isGranted && systemAlertStatus.isGranted;
    } catch (e) {
      debugPrint('Erro ao verificar permissões de chamada: $e');
      return false;
    }
  }

  /// Verifica se o aplicativo pode interceptar SMS
  Future<bool> canInterceptSms() async {
    try {
      final smsStatus = await Permission.sms.status;
      return smsStatus.isGranted;
    } catch (e) {
      debugPrint('Erro ao verificar permissões de SMS: $e');
      return false;
    }
  }

  /// Verifica se o aplicativo pode acessar contatos
  Future<bool> canAccessContacts() async {
    try {
      final contactsStatus = await Permission.contacts.status;
      return contactsStatus.isGranted;
    } catch (e) {
      debugPrint('Erro ao verificar permissões de contatos: $e');
      return false;
    }
  }

  /// Verifica se o aplicativo pode acessar armazenamento
  Future<bool> canAccessStorage() async {
    try {
      final storageStatus = await Permission.storage.status;
      final manageStorageStatus = await Permission.manageExternalStorage.status;
      return storageStatus.isGranted || manageStorageStatus.isGranted;
    } catch (e) {
      debugPrint('Erro ao verificar permissões de armazenamento: $e');
      return false;
    }
  }

  /// Abre as configurações do aplicativo
  Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('Erro ao abrir configurações: $e');
      return false;
    }
  }

  /// Retorna uma lista de permissões negadas
  Future<List<Permission>> getDeniedPermissions() async {
    List<Permission> deniedPermissions = [];
    
    try {
      for (Permission permission in _requiredPermissions) {
        final status = await permission.status;
        if (status.isDenied || status.isPermanentlyDenied) {
          deniedPermissions.add(permission);
        }
      }
    } catch (e) {
      debugPrint('Erro ao obter permissões negadas: $e');
    }
    
    return deniedPermissions;
  }

  /// Retorna uma lista de permissões permanentemente negadas
  Future<List<Permission>> getPermanentlyDeniedPermissions() async {
    List<Permission> permanentlyDeniedPermissions = [];
    
    try {
      for (Permission permission in _requiredPermissions) {
        final status = await permission.status;
        if (status.isPermanentlyDenied) {
          permanentlyDeniedPermissions.add(permission);
        }
      }
    } catch (e) {
      debugPrint('Erro ao obter permissões permanentemente negadas: $e');
    }
    
    return permanentlyDeniedPermissions;
  }

  /// Retorna o nome amigável de uma permissão
  String getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.phone:
        return 'Telefone';
      case Permission.sms:
        return 'SMS';
      case Permission.contacts:
        return 'Contatos';
      case Permission.storage:
        return 'Armazenamento';
      case Permission.manageExternalStorage:
        return 'Gerenciar Armazenamento';
      case Permission.systemAlertWindow:
        return 'Sobreposição de Tela';
      case Permission.notification:
        return 'Notificações';
      default:
        return permission.toString().split('.').last;
    }
  }

  /// Retorna a descrição de uma permissão
  String getPermissionDescription(Permission permission) {
    switch (permission) {
      case Permission.phone:
        return 'Necessário para interceptar e gerenciar chamadas';
      case Permission.sms:
        return 'Necessário para interceptar e gerenciar mensagens SMS';
      case Permission.contacts:
        return 'Necessário para identificar contatos conhecidos';
      case Permission.storage:
        return 'Necessário para salvar logs e configurações';
      case Permission.manageExternalStorage:
        return 'Necessário para gerenciar arquivos do aplicativo';
      case Permission.systemAlertWindow:
        return 'Necessário para mostrar alertas sobre chamadas';
      case Permission.notification:
        return 'Necessário para enviar notificações sobre bloqueios';
      default:
        return 'Permissão necessária para o funcionamento do aplicativo';
    }
  }

  /// Verifica se o dispositivo suporta uma permissão específica
  Future<bool> isPermissionSupported(Permission permission) async {
    try {
      final status = await permission.status;
      return status != PermissionStatus.restricted;
    } catch (e) {
      debugPrint('Erro ao verificar suporte da permissão $permission: $e');
      return false;
    }
  }

  /// Solicita permissões em lote com tratamento de erros
  Future<PermissionRequestResult> requestPermissionsBatch(
    List<Permission> permissions,
  ) async {
    Map<Permission, PermissionStatus> results = {};
    List<Permission> granted = [];
    List<Permission> denied = [];
    List<Permission> permanentlyDenied = [];
    
    try {
      results = await permissions.request();
      
      for (var entry in results.entries) {
        if (entry.value.isGranted) {
          granted.add(entry.key);
        } else if (entry.value.isPermanentlyDenied) {
          permanentlyDenied.add(entry.key);
        } else {
          denied.add(entry.key);
        }
      }
    } catch (e) {
      debugPrint('Erro ao solicitar permissões em lote: $e');
    }
    
    return PermissionRequestResult(
      granted: granted,
      denied: denied,
      permanentlyDenied: permanentlyDenied,
      results: results,
    );
  }

  /// Verifica se o aplicativo está configurado como aplicativo padrão para chamadas
  Future<bool> isDefaultCallApp() async {
    try {
      // Esta verificação pode variar dependendo da implementação específica
      // Por enquanto, retornamos false como padrão
      return false;
    } catch (e) {
      debugPrint('Erro ao verificar aplicativo padrão de chamadas: $e');
      return false;
    }
  }

  /// Solicita para definir como aplicativo padrão de chamadas
  Future<bool> requestDefaultCallApp() async {
    try {
      // Implementação específica para definir como app padrão
      // Isso geralmente requer configurações específicas do Android
      return false;
    } catch (e) {
      debugPrint('Erro ao solicitar definição como app padrão: $e');
      return false;
    }
  }
}

/// Classe para resultado de solicitação de permissões em lote
class PermissionRequestResult {
  final List<Permission> granted;
  final List<Permission> denied;
  final List<Permission> permanentlyDenied;
  final Map<Permission, PermissionStatus> results;

  const PermissionRequestResult({
    required this.granted,
    required this.denied,
    required this.permanentlyDenied,
    required this.results,
  });

  bool get hasAllGranted => denied.isEmpty && permanentlyDenied.isEmpty;
  bool get hasAnyDenied => denied.isNotEmpty || permanentlyDenied.isNotEmpty;
  bool get hasAnyPermanentlyDenied => permanentlyDenied.isNotEmpty;
  
  int get totalRequested => granted.length + denied.length + permanentlyDenied.length;
  double get grantedPercentage => totalRequested > 0 ? granted.length / totalRequested : 0.0;
}