import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/services.dart';
import '../models/models.dart';

import '../database/repository.dart';
import 'calls_screen.dart';
import 'messages_screen.dart';
import 'settings_screen.dart';

/// Tela principal do aplicativo com navegação por abas
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late TabController _tabController;
  
  // Serviços
  final Repository _repository = Repository();
  final IntegratedSpamDetector _spamDetector = IntegratedSpamDetector();
  final PermissionService _permissionService = PermissionService();
  
  // Dados do dashboard
  int _totalCallsToday = 0;
  int _blockedCallsToday = 0;
  int _totalSmsToday = 0;
  int _blockedSmsToday = 0;
  int _spamDetectedToday = 0;
  List<CallLog> _recentCalls = [];
  List<SmsLog> _recentSms = [];
  bool _isLoading = true;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
    _loadDashboardData();
    _checkPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Carrega dados do dashboard
  Future<void> _loadDashboardData() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Carrega estatísticas do dia
      // Carrega estatísticas básicas usando métodos existentes
      final allCalls = await _repository.getCallHistory('user_id', limit: 100);
      final allSms = await _repository.getMessageHistory('user_id', limit: 100);
      
      // Filtra por hoje
      final todayCalls = allCalls.where((call) => 
        call.timestamp.isAfter(startOfDay) && call.timestamp.isBefore(endOfDay)
      ).toList();
      
      final todaySms = allSms.where((sms) => 
        sms.timestamp.isAfter(startOfDay) && sms.timestamp.isBefore(endOfDay)
      ).toList();
      
      final callStats = {
        'total': todayCalls.length,
        'blocked': todayCalls.where((call) => call.isBlocked).length,
        'spam': todayCalls.where((call) => call.isSpam).length,
      };
      
      final smsStats = {
        'total': todaySms.length,
        'blocked': todaySms.where((sms) => sms.isBlocked).length,
        'spam': todaySms.where((sms) => sms.isSpam).length,
      };

      // Carrega chamadas e SMS recentes
      final recentCalls = await _repository.getCallHistory('user_id', limit: 5);
      final recentSms = await _repository.getMessageHistory('user_id', limit: 5);

      setState(() {
        _totalCallsToday = callStats['total'] ?? 0;
        _blockedCallsToday = callStats['blocked'] ?? 0;
        _totalSmsToday = smsStats['total'] ?? 0;
        _blockedSmsToday = smsStats['blocked'] ?? 0;
        _spamDetectedToday = (callStats['spam'] ?? 0) + (smsStats['spam'] ?? 0);
        _recentCalls = recentCalls;
        _recentSms = recentSms;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados do dashboard: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Verifica status das permissões
  Future<void> _checkPermissions() async {
    try {
      final phoneStatus = await _permissionService.checkPermission(Permission.phone);
        final smsStatus = await _permissionService.checkPermission(Permission.sms);
        final criticalPermissions = [
          MapEntry(Permission.phone, phoneStatus),
          MapEntry(Permission.sms, smsStatus),
        ].where((entry) => entry.value != PermissionStatus.granted).toList();
      
      final hasAllCritical = criticalPermissions.isEmpty;
      
      setState(() {
        _hasPermissions = hasAllCritical;
      });
    } catch (e) {
      debugPrint('Erro ao verificar permissões: $e');
    }
  }

  /// Atualiza dados do dashboard
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    await _loadDashboardData();
    await _checkPermissions();
  }

  /// Navega para tela específica
  void _navigateToScreen(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          const CallsScreen(),
          const MessagesScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,

          indicatorColor: const Color(0xFF3B82F6),
            labelColor: const Color(0xFF3B82F6),
            unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard_outlined),
              text: 'Dashboard',
            ),
            Tab(
              icon: Icon(Icons.call_outlined),
              text: 'Chamadas',
            ),
            Tab(
              icon: Icon(Icons.message_outlined),
              text: 'Mensagens',
            ),
            Tab(
              icon: Icon(Icons.settings_outlined),
              text: 'Configurações',
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói a aba do dashboard
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF3B82F6),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'CallGuard Pro',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF3B82F6),
                      Color(0xFF1E3A8A),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          
          // Conteúdo
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Alerta de permissões (se necessário)
                if (!_hasPermissions) _buildPermissionAlert(),
                
                // Estatísticas do dia
                _buildTodayStats(),
                const SizedBox(height: 20),
                
                // Ações rápidas
                _buildQuickActions(),
                const SizedBox(height: 20),
                
                // Atividade recente
                _buildRecentActivity(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói alerta de permissões
  Widget _buildPermissionAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permissões Necessárias',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Algumas permissões são necessárias para proteção completa.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _permissionService.openAppSettings(),
            child: const Text('Configurar'),
          ),
        ],
      ),
    );
  }

  /// Constrói estatísticas do dia
  Widget _buildTodayStats() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hoje',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Chamadas\nBloqueadas',
                _blockedCallsToday.toString(),
                Icons.call_end,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'SMS\nBloqueados',
                _blockedSmsToday.toString(),
                Icons.message_outlined,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total\nChamadas',
                _totalCallsToday.toString(),
                Icons.call,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Spam\nDetectado',
                _spamDetectedToday.toString(),
                Icons.security,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Constrói card de estatística
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói ações rápidas
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ações Rápidas',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Ver Chamadas',
                Icons.call,
                Colors.blue,
                () => _tabController.animateTo(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Ver Mensagens',
                Icons.message,
                Colors.green,
                () => _tabController.animateTo(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Configurações',
                Icons.settings,
                Colors.purple,
                () => _tabController.animateTo(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Regras de Bloqueio',
                Icons.block,
                Colors.red,
                () => _tabController.animateTo(3), // Vai para settings
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Constrói botão de ação
  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói seção de atividade recente
  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Atividade Recente',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        if (_recentCalls.isEmpty && _recentSms.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Nenhuma atividade recente',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._buildRecentItems(),
      ],
    );
  }

  /// Constrói itens de atividade recente
  List<Widget> _buildRecentItems() {
    final List<Widget> items = [];
    
    // Adiciona chamadas recentes
    for (final call in _recentCalls.take(3)) {
      items.add(_buildRecentCallItem(call));
    }
    
    // Adiciona SMS recentes
    for (final sms in _recentSms.take(3)) {
      items.add(_buildRecentSmsItem(sms));
    }
    
    return items;
  }

  /// Constrói item de chamada recente
  Widget _buildRecentCallItem(CallLog call) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            call.isBlocked ? Icons.call_end : Icons.call,
            color: call.isBlocked ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.contactName ?? call.phoneNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${call.timestamp.day}/${call.timestamp.month} ${call.timestamp.hour}:${call.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (call.isSpam)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
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
        ],
      ),
    );
  }

  /// Constrói item de SMS recente
  Widget _buildRecentSmsItem(SmsLog sms) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            sms.isBlocked ? Icons.message_outlined : Icons.message,
            color: sms.isBlocked ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sms.formattedSender,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sms.contentPreview,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (sms.isSpam)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
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
        ],
      ),
    );
  }
}