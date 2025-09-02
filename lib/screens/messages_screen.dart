import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../services/repository.dart';
import '../database/database_helper.dart';

/// Tela de gerenciamento de mensagens SMS
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Repository _repository = Repository(DatabaseHelper());
  final SmsService _smsService = SmsService();
  final BlockService _blockService = BlockService();
  
  List<SmsLog> _allMessages = [];
  List<SmsLog> _blockedMessages = [];
  List<SmsLog> _spamMessages = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Carrega todas as mensagens
  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
        final allMessages = await _repository.getAllSmsLogs();
      final blockedMessages = allMessages.where((sms) => sms.isBlocked).toList();
      final spamMessages = allMessages.where((sms) => sms.isSpam).toList();

      setState(() {
        _allMessages = allMessages;
        _blockedMessages = blockedMessages;
        _spamMessages = spamMessages;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar mensagens: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Filtra mensagens baseado na busca
  List<SmsLog> _filterMessages(List<SmsLog> messages) {
    if (_searchQuery.isEmpty) return messages;
    
    return messages.where((sms) {
      final query = _searchQuery.toLowerCase();
      return sms.sender.toLowerCase().contains(query) ||
             sms.formattedSender.toLowerCase().contains(query) ||
        sms.content.toLowerCase().contains(query);
    }).toList();
  }

  /// Marca mensagem como spam
  Future<void> _markAsSpam(SmsLog sms) async {
    try {
      await _smsService.markAsSpam(sms.id, true);
      await _loadMessages();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${sms.formattedSender} marcado como spam'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao marcar como spam: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Adiciona número à lista negra
  Future<void> _addToBlacklist(SmsLog sms) async {
    try {
      await _blockService.addToBlacklist(sms.sender, 'Bloqueado manualmente');
      await _loadMessages();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${sms.formattedSender} adicionado à lista negra'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar à lista negra: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Adiciona número à lista branca
  Future<void> _addToWhitelist(SmsLog sms) async {
    try {
      await _blockService.addToWhitelist(sms.sender, 'Adicionado manualmente');
      await _loadMessages();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${sms.formattedSender} adicionado à lista branca'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar à lista branca: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Mostra opções para uma mensagem
  void _showMessageOptions(SmsLog sms) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  sms.messageType == MessageType.received
                      ? Icons.message
                      : Icons.send,
                  color: sms.isBlocked
                      ? Colors.red
                      : sms.messageType == MessageType.received
                          ? Colors.blue
                          : Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sms.sender,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        sms.formattedSender,
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Mensagem
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sms.content,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),
            
            // Opções
            ListTile(
              leading: const Icon(Icons.message, color: Colors.blue),
              title: const Text('Responder'),
              onTap: () {
                Navigator.pop(context);
                _showReplyDialog(sms);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.grey),
              title: const Text('Copiar Mensagem'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: sms.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mensagem copiada'),
                  ),
                );
              },
            ),
            
            if (!sms.isSpam)
              ListTile(
                leading: const Icon(Icons.report, color: Colors.orange),
                title: const Text('Marcar como Spam'),
                onTap: () {
                  Navigator.pop(context);
                  _markAsSpam(sms);
                },
              ),
            
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Adicionar à Lista Negra'),
              onTap: () {
                Navigator.pop(context);
                _addToBlacklist(sms);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Adicionar à Lista Branca'),
              onTap: () {
                Navigator.pop(context);
                _addToWhitelist(sms);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Excluir Mensagem'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(sms);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Mostra diálogo para responder mensagem
  void _showReplyDialog(SmsLog sms) {
    final TextEditingController replyController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Responder para ${sms.formattedSender}'),
        content: TextField(
          controller: replyController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Digite sua mensagem...',
            border: OutlineInputBorder(),
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
              _sendReply(sms.sender, replyController.text);
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  /// Envia resposta
  Future<void> _sendReply(String phoneNumber, String message) async {
    if (message.trim().isEmpty) return;
    
    try {
      await _smsService.sendSms(phoneNumber, message);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensagem enviada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar mensagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Exclui mensagem do histórico
  Future<void> _deleteMessage(SmsLog sms) async {
    try {
      await _repository.deleteSmsLog(sms.id);
      await _loadMessages();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensagem excluída do histórico'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir mensagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mensagens',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF10B981),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Barra de busca
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar mensagens...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              
              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    text: 'Todas (${_allMessages.length})',
                  ),
                  Tab(
                    text: 'Bloqueadas (${_blockedMessages.length})',
                  ),
                  Tab(
                    text: 'Spam (${_spamMessages.length})',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMessagesList(_filterMessages(_allMessages)),
                _buildMessagesList(_filterMessages(_blockedMessages)),
                _buildMessagesList(_filterMessages(_spamMessages)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showComposeDialog(),
        backgroundColor: const Color(0xFF10B981),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Mostra diálogo para compor nova mensagem
  void _showComposeDialog() {
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Mensagem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Número do telefone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mensagem',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendReply(phoneController.text, messageController.text);
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  /// Constrói lista de mensagens
  Widget _buildMessagesList(List<SmsLog> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.message_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Nenhuma mensagem encontrada'
                  : 'Nenhuma mensagem registrada',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tente buscar por outro termo',
                style: TextStyle(
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          return _buildMessageItem(message);
        },
      ),
    );
  }

  /// Constrói item de mensagem
  Widget _buildMessageItem(SmsLog sms) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: sms.isBlocked
              ? Colors.red.shade100
              : sms.messageType == MessageType.received
                  ? Colors.blue.shade100
                  : Colors.green.shade100,
          child: Icon(
            sms.messageType == MessageType.received
                ? Icons.message
                : Icons.send,
            color: sms.isBlocked
                ? Colors.red
                : sms.messageType == MessageType.received
                    ? Colors.blue
                    : Colors.green,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                sms.sender,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (sms.isSpam)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'SPAM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            if (sms.isBlocked)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'BLOQUEADO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sms.formattedSender,
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              sms.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${sms.timestamp.day}/${sms.timestamp.month} ${sms.timestamp.hour}:${sms.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            if (sms.spamScore > 0.5)
              Row(
                children: [
                  Icon(
                    Icons.warning,
                    size: 12,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Score de spam: ${(sms.spamScore * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: IconButton(
          onPressed: () => _showMessageOptions(sms),
          icon: const Icon(Icons.more_vert),
        ),
        onTap: () => _showMessageOptions(sms),
      ),
    );
  }
}