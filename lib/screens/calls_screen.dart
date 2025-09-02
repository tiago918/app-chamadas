import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/services.dart';
import '../models/models.dart';
import '../services/repository.dart';
import '../database/database_helper.dart';

/// Tela de gerenciamento de chamadas
class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Repository _repository = Repository(DatabaseHelper());
  final CallService _callService = CallService();
  final BlockService _blockService = BlockService();
  
  List<CallLog> _allCalls = [];
  List<CallLog> _blockedCalls = [];
  List<CallLog> _spamCalls = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCalls();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Carrega todas as chamadas
  Future<void> _loadCalls() async {
    setState(() {
      _isLoading = true;
    });

    try {
        final allCalls = await _repository.getAllCallLogs();
        final blockedCalls = allCalls.where((call) => call.isBlocked).toList();
      final spamCalls = allCalls.where((call) => call.isSpam).toList();

      setState(() {
        _allCalls = allCalls;
        _blockedCalls = blockedCalls;
        _spamCalls = spamCalls;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar chamadas: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Filtra chamadas baseado na busca
  List<CallLog> _filterCalls(List<CallLog> calls) {
    if (_searchQuery.isEmpty) return calls;
    
    return calls.where((call) {
      final query = _searchQuery.toLowerCase();
      return (call.contactName?.toLowerCase().contains(query) ?? false) ||
             call.phoneNumber.contains(query) ||
             call.phoneNumber.toLowerCase().contains(query);
    }).toList();
  }

  /// Marca chamada como spam
  Future<void> _markAsSpam(CallLog call) async {
    try {
      await _callService.markAsSpam(call.id, true);
      await _loadCalls();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${call.phoneNumber} marcado como spam'),
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
  Future<void> _addToBlacklist(CallLog call) async {
    try {
      await _blockService.addToBlacklist(call.phoneNumber, 'Bloqueado manualmente');
      await _loadCalls();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${call.phoneNumber} adicionado à lista negra'),
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
  Future<void> _addToWhitelist(CallLog call) async {
    try {
      await _blockService.addToWhitelist(call.phoneNumber, 'Adicionado manualmente');
      await _loadCalls();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${call.phoneNumber} adicionado à lista branca'),
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

  /// Mostra opções para uma chamada
  void _showCallOptions(CallLog call) {
    showModalBottomSheet(
      context: context,
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
                  call.callType == CallType.incoming
                      ? Icons.call_received
                      : call.callType == CallType.outgoing
                          ? Icons.call_made
                          : Icons.call_missed,
                  color: call.isBlocked
                      ? Colors.red
                      : call.callType == CallType.missed
                          ? Colors.orange
                          : Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        call.contactName ?? call.phoneNumber,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (call.contactName != null)
                        Text(
                          call.phoneNumber,
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Opções
            ListTile(
              leading: const Icon(Icons.call, color: Colors.green),
              title: const Text('Ligar'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implementar ligação
              },
            ),
            
            if (!call.isSpam)
              ListTile(
                leading: const Icon(Icons.report, color: Colors.orange),
                title: const Text('Marcar como Spam'),
                onTap: () {
                  Navigator.pop(context);
                  _markAsSpam(call);
                },
              ),
            
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Adicionar à Lista Negra'),
              onTap: () {
                Navigator.pop(context);
                _addToBlacklist(call);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Adicionar à Lista Branca'),
              onTap: () {
                Navigator.pop(context);
                _addToWhitelist(call);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Excluir do Histórico'),
              onTap: () {
                Navigator.pop(context);
                _deleteCall(call);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Exclui chamada do histórico
  Future<void> _deleteCall(CallLog call) async {
    try {
      await _repository.deleteCallLog(call.id);
      await _loadCalls();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chamada excluída do histórico'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir chamada: $e'),
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
          'Chamadas',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3B82F6),
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
                    hintText: 'Buscar chamadas...',
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
                    text: 'Todas (${_allCalls.length})',
                  ),
                  Tab(
                    text: 'Bloqueadas (${_blockedCalls.length})',
                  ),
                  Tab(
                    text: 'Spam (${_spamCalls.length})',
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
                _buildCallsList(_filterCalls(_allCalls)),
                _buildCallsList(_filterCalls(_blockedCalls)),
                _buildCallsList(_filterCalls(_spamCalls)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadCalls,
        backgroundColor: const Color(0xFF3B82F6),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  /// Constrói lista de chamadas
  Widget _buildCallsList(List<CallLog> calls) {
    if (calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.call_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Nenhuma chamada encontrada'
                  : 'Nenhuma chamada registrada',
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
      onRefresh: _loadCalls,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: calls.length,
        itemBuilder: (context, index) {
          final call = calls[index];
          return _buildCallItem(call);
        },
      ),
    );
  }

  /// Constrói item de chamada
  Widget _buildCallItem(CallLog call) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: call.isBlocked
              ? Colors.red.shade100
              : call.callType == CallType.missed
                  ? Colors.orange.shade100
                  : Colors.green.shade100,
          child: Icon(
            call.callType == CallType.incoming
                ? Icons.call_received
                : call.callType == CallType.outgoing
                    ? Icons.call_made
                    : Icons.call_missed,
            color: call.isBlocked
                ? Colors.red
                : call.callType == CallType.missed
                    ? Colors.orange
                    : Colors.green,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                call.contactName ?? call.phoneNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (call.isSpam)
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
            if (call.isBlocked)
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
            if (call.contactName != null)
              Text(
                call.phoneNumber,
                style: const TextStyle(fontSize: 12),
              ),
            Row(
              children: [
                Text(
                  '${call.timestamp.day}/${call.timestamp.month} ${call.timestamp.hour}:${call.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                if (call.duration > 0) ...[
                  const Text(' • ', style: TextStyle(color: Colors.grey)),
                  Text(
                    call.formattedDuration,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
            if (call.spamScore > 0.5)
              Row(
                children: [
                  Icon(
                    Icons.warning,
                    size: 12,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Score de spam: ${(call.spamScore * 100).toInt()}%',
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
          onPressed: () => _showCallOptions(call),
          icon: const Icon(Icons.more_vert),
        ),
        onTap: () => _showCallOptions(call),
      ),
    );
  }
}