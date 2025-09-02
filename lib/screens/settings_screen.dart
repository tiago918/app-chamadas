import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/services.dart';
import '../database/database_helper.dart';
import '../services/repository.dart';
import '../models/models.dart';

/// Tela de configurações do aplicativo
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Repository _repository = Repository(DatabaseHelper());
  final BlockService _blockService = BlockService();
  final PermissionService _permissionService = PermissionService();
  final SecurityService _securityService = SecurityService();
  final IntegratedSpamDetector _spamDetector = IntegratedSpamDetector();
  
  List<BlockRule> _blockRules = [];
  Map<String, bool> _permissions = {};
  bool _isLoading = true;
  double _spamThreshold = 0.7;
  bool _autoBlock = true;
  bool _notificationsEnabled = true;
  bool _vibrationEnabled = true;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Carrega configurações
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final blockRules = await _repository.getAllBlockRules();
      final permissions = <String, bool>{
        'phone': await _permissionService.canInterceptCalls(),
        'sms': await _permissionService.canInterceptSms(),
        'contacts': await _permissionService.canAccessContacts(),
        'storage': await _permissionService.canAccessStorage(),
      };
      
      setState(() {
        _blockRules = blockRules;
        _permissions = permissions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar configurações: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Mostra diálogo para criar nova regra de bloqueio
  void _showCreateRuleDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController patternController = TextEditingController();
    RuleType selectedType = RuleType.phoneNumber;
    bool isActive = true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova Regra de Bloqueio'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da regra',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<RuleType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de regra',
                    border: OutlineInputBorder(),
                  ),
                  items: RuleType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getRuleTypeLabel(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: patternController,
                  decoration: InputDecoration(
                    labelText: 'Padrão',
                    hintText: _getRulePatternHint(selectedType),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                SwitchListTile(
                  title: const Text('Regra ativa'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _createBlockRule(
                  nameController.text,
                  selectedType,
                  patternController.text,
                  isActive,
                );
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Cria nova regra de bloqueio
  Future<void> _createBlockRule(
    String name,
    RuleType type,
    String pattern,
    bool isActive,
  ) async {
    if (name.trim().isEmpty || pattern.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nome e padrão são obrigatórios'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final rule = BlockRule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'current_user',
        ruleName: name.trim(),
        ruleType: type,
        pattern: pattern.trim(),
        isActive: isActive,
        priority: 50,
        createdAt: DateTime.now(),
      );
      
      await _blockService.createBlockRule(rule);
      await _loadSettings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Regra criada com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar regra: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Alterna status da regra
  Future<void> _toggleRule(BlockRule rule) async {
    try {
      await _blockService.toggleRule(rule.id!, !rule.isActive);
      await _loadSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar regra: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Exclui regra
  Future<void> _deleteRule(BlockRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir a regra "${rule.ruleName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _blockService.deleteBlockRule(rule.id!);
        await _loadSettings();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Regra excluída'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir regra: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Solicita permissão
  Future<void> _requestPermission(String permission) async {
    try {
      Permission permissionEnum;
      switch (permission) {
        case 'phone':
          permissionEnum = Permission.phone;
          break;
        case 'sms':
          permissionEnum = Permission.sms;
          break;
        case 'contacts':
          permissionEnum = Permission.contacts;
          break;
        case 'storage':
          permissionEnum = Permission.storage;
          break;
        case 'manageExternalStorage':
          permissionEnum = Permission.manageExternalStorage;
          break;
        case 'systemAlertWindow':
          permissionEnum = Permission.systemAlertWindow;
          break;
        case 'notification':
          permissionEnum = Permission.notification;
          break;
        default:
          return;
      }
      
      final status = await _permissionService.requestPermission(permissionEnum);
      
      if (status.isGranted) {
        await _loadSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissão concedida'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissão negada'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao solicitar permissão: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Abre configurações do sistema
  Future<void> _openAppSettings() async {
    try {
      await _permissionService.openAppSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir configurações: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Obtém label do tipo de regra
  String _getRuleTypeLabel(RuleType type) {
    switch (type) {
      case RuleType.phoneNumber:
        return 'Número de telefone';
      case RuleType.keyword:
        return 'Palavra-chave';
      case RuleType.prefix:
        return 'Prefixo';
      case RuleType.regex:
        return 'Expressão regular';
      case RuleType.pattern:
        return 'Padrão';
      case RuleType.blacklist:
        return 'Lista negra';
      case RuleType.whitelist:
        return 'Lista branca';
      case RuleType.international:
        return 'Internacional';
      case RuleType.unknown:
        return 'Desconhecido';
      case RuleType.shortCode:
        return 'Código curto';
      case RuleType.smsBlacklist:
        return 'SMS lista negra';
      case RuleType.keywordFilter:
        return 'Filtro palavra-chave';
      case RuleType.timeBased:
        return 'Baseado em tempo';
    }
  }

  /// Obtém dica do padrão da regra
  String _getRulePatternHint(RuleType type) {
    switch (type) {
      case RuleType.phoneNumber:
        return 'Ex: +5511999999999';
      case RuleType.keyword:
        return 'Ex: promoção, oferta';
      case RuleType.prefix:
        return 'Ex: 0800, 4003';
      case RuleType.regex:
        return 'Ex: ^\\d{4}\$';
      case RuleType.pattern:
        return 'Ex: *123*';
      case RuleType.blacklist:
        return 'Lista de números bloqueados';
      case RuleType.whitelist:
        return 'Lista de números permitidos';
      case RuleType.international:
        return 'Números internacionais';
      case RuleType.unknown:
        return 'Números desconhecidos';
      case RuleType.shortCode:
        return 'Ex: 1234, 5678';
      case RuleType.smsBlacklist:
        return 'SMS de números bloqueados';
      case RuleType.keywordFilter:
        return 'Filtrar por palavras';
      case RuleType.timeBased:
        return 'Horário específico';
    }
  }

  /// Obtém nome amigável da permissão
  String _getPermissionName(String permission) {
    switch (permission) {
      case 'phone':
        return 'Telefone';
      case 'sms':
        return 'SMS';
      case 'contacts':
        return 'Contatos';
      case 'storage':
        return 'Armazenamento';
      case 'manageExternalStorage':
        return 'Gerenciar armazenamento';
      case 'systemAlertWindow':
        return 'Sobreposição de tela';
      case 'notification':
        return 'Notificações';
      default:
        return permission;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configurações',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF8B5CF6),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seção de Permissões
                  _buildSectionHeader('Permissões', Icons.security),
                  _buildPermissionsSection(),
                  const SizedBox(height: 24),
                  
                  // Seção de Detecção de Spam
                  _buildSectionHeader('Detecção de Spam', Icons.shield),
                  _buildSpamDetectionSection(),
                  const SizedBox(height: 24),
                  
                  // Seção de Regras de Bloqueio
                  _buildSectionHeader('Regras de Bloqueio', Icons.block),
                  _buildBlockRulesSection(),
                  const SizedBox(height: 24),
                  
                  // Seção de Notificações
                  _buildSectionHeader('Notificações', Icons.notifications),
                  _buildNotificationsSection(),
                  const SizedBox(height: 24),
                  
                  // Seção de Dados
                  _buildSectionHeader('Dados', Icons.storage),
                  _buildDataSection(),
                ],
              ),
            ),
    );
  }

  /// Constrói cabeçalho de seção
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B5CF6),
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói seção de permissões
  Widget _buildPermissionsSection() {
    return Card(
      child: Column(
        children: [
          ..._permissions.entries.map((entry) {
            final permission = entry.key;
            final isGranted = entry.value;
            
            return ListTile(
              leading: Icon(
                isGranted ? Icons.check_circle : Icons.error,
                color: isGranted ? Colors.green : Colors.red,
              ),
              title: Text(_getPermissionName(permission)),
              subtitle: Text(
                isGranted ? 'Concedida' : 'Negada',
                style: TextStyle(
                  color: isGranted ? Colors.green : Colors.red,
                ),
              ),
              trailing: !isGranted
                  ? ElevatedButton(
                      onPressed: () => _requestPermission(permission),
                      child: const Text('Solicitar'),
                    )
                  : null,
            );
          }).toList(),
          
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Abrir Configurações do Sistema'),
            subtitle: const Text('Para gerenciar permissões manualmente'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _openAppSettings,
          ),
        ],
      ),
    );
  }

  /// Constrói seção de detecção de spam
  Widget _buildSpamDetectionSection() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Bloqueio Automático'),
            subtitle: const Text('Bloquear automaticamente chamadas/SMS identificadas como spam'),
            value: _autoBlock,
            onChanged: (value) {
              setState(() {
                _autoBlock = value;
              });
              // TODO: Salvar configuração
            },
          ),
          
          const Divider(),
          
          ListTile(
            title: const Text('Sensibilidade de Detecção'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Atual: ${(_spamThreshold * 100).toInt()}%'),
                Slider(
                  value: _spamThreshold,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: '${(_spamThreshold * 100).toInt()}%',
                  onChanged: (value) {
                    setState(() {
                      _spamThreshold = value;
                    });
                    // TODO: Salvar configuração
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói seção de regras de bloqueio
  Widget _buildBlockRulesSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.add, color: Color(0xFF8B5CF6)),
            title: const Text('Criar Nova Regra'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _showCreateRuleDialog,
          ),
          
          if (_blockRules.isNotEmpty) ...[
            const Divider(),
            ..._blockRules.map((rule) {
              return ListTile(
                leading: Icon(
                  rule.isActive ? Icons.check_circle : Icons.cancel,
                  color: rule.isActive ? Colors.green : Colors.grey,
                ),
                title: Text(rule.ruleName),
                subtitle: Text(
                  '${_getRuleTypeLabel(rule.ruleType)}: ${rule.pattern}',
                ),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(
                        rule.isActive ? 'Desativar' : 'Ativar',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Excluir'),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'toggle') {
                      _toggleRule(rule);
                    } else if (value == 'delete') {
                      _deleteRule(rule);
                    }
                  },
                ),
              );
            }).toList(),
          ] else ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nenhuma regra personalizada criada',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Constrói seção de notificações
  Widget _buildNotificationsSection() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Notificações'),
            subtitle: const Text('Mostrar notificações de chamadas/SMS bloqueadas'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              // TODO: Salvar configuração
            },
          ),
          
          SwitchListTile(
            title: const Text('Vibração'),
            subtitle: const Text('Vibrar ao bloquear chamadas/SMS'),
            value: _vibrationEnabled,
            onChanged: (value) {
              setState(() {
                _vibrationEnabled = value;
              });
              // TODO: Salvar configuração
            },
          ),
          
          SwitchListTile(
            title: const Text('Som'),
            subtitle: const Text('Reproduzir som ao bloquear chamadas/SMS'),
            value: _soundEnabled,
            onChanged: (value) {
              setState(() {
                _soundEnabled = value;
              });
              // TODO: Salvar configuração
            },
          ),
        ],
      ),
    );
  }

  /// Constrói seção de dados
  Widget _buildDataSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.orange),
            title: const Text('Limpar Dados Antigos'),
            subtitle: const Text('Remove registros com mais de 30 dias'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Implementar limpeza de dados
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.file_download, color: Colors.blue),
            title: const Text('Exportar Dados'),
            subtitle: const Text('Salvar histórico em arquivo'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Implementar exportação
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.file_upload, color: Colors.green),
            title: const Text('Importar Dados'),
            subtitle: const Text('Carregar histórico de arquivo'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Implementar importação
            },
          ),
          
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Limpar Todos os Dados'),
            subtitle: const Text('Remove todo o histórico (irreversível)'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Implementar limpeza total
            },
          ),
        ],
      ),
    );
  }
}