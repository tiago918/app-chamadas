import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/services.dart';
import 'home_screen.dart';

/// Tela de onboarding para primeira execução do app
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isRequestingPermissions = false;
  
  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Bem-vindo ao CallGuard Pro',
      description: 'Sua proteção completa contra chamadas e mensagens indesejadas com tecnologia de machine learning.',
      icon: Icons.security_outlined,
      color: const Color(0xFF3B82F6),
    ),
    OnboardingPage(
      title: 'Bloqueio Inteligente',
      description: 'Sistema avançado de detecção de spam que aprende com seus hábitos e bloqueia automaticamente números suspeitos.',
      icon: Icons.block_outlined,
      color: const Color(0xFF10B981),
    ),
    OnboardingPage(
      title: 'Análise Comportamental',
      description: 'Monitora padrões de chamadas e mensagens para identificar atividades suspeitas em tempo real.',
      icon: Icons.analytics_outlined,
      color: const Color(0xFF8B5CF6),
    ),
    OnboardingPage(
      title: 'Controle Total',
      description: 'Gerencie listas de bloqueio, configure regras personalizadas e mantenha seus contatos seguros.',
      icon: Icons.tune_outlined,
      color: const Color(0xFFF59E0B),
    ),
    OnboardingPage(
      title: 'Permissões Necessárias',
      description: 'Para funcionar corretamente, o app precisa de algumas permissões. Vamos configurá-las agora.',
      icon: Icons.verified_user_outlined,
      color: const Color(0xFFEF4444),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Avança para próxima página
  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _requestPermissions();
    }
  }

  /// Volta para página anterior
  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Pula para última página (permissões)
  void _skipToPermissions() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  /// Solicita todas as permissões necessárias
  Future<void> _requestPermissions() async {
    setState(() {
      _isRequestingPermissions = true;
    });

    try {
      final permissionService = PermissionService();
      
      // Solicita todas as permissões necessárias
      final results = await permissionService.requestAllPermissions();
      
      // Verifica se todas as permissões críticas foram concedidas
      final criticalDenied = await permissionService.getDeniedPermissions();

      if (criticalDenied.isNotEmpty) {
        // Mostra dialog explicando a importância das permissões
        await _showPermissionDialog(criticalDenied);
      } else {
        // Todas as permissões foram concedidas, finaliza onboarding
        await _completeOnboarding();
      }
    } catch (e) {
      // Erro ao solicitar permissões
      _showErrorDialog('Erro ao solicitar permissões: $e');
    } finally {
      setState(() {
        _isRequestingPermissions = false;
      });
    }
  }

  /// Mostra dialog sobre permissões negadas
  Future<void> _showPermissionDialog(List<Permission> deniedPermissions) async {
    final permissionService = PermissionService();
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permissões Necessárias'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'As seguintes permissões são essenciais para o funcionamento do app:',
            ),
            const SizedBox(height: 12),
            ...deniedPermissions.map((permission) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      permissionService.getPermissionName(permission),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 12),
            const Text(
              'Sem essas permissões, o app não poderá proteger você adequadamente.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeOnboarding(); // Continua mesmo sem permissões
            },
            child: const Text('Continuar Assim Mesmo'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              permissionService.openAppSettings(); // Abre configurações
            },
            child: const Text('Abrir Configurações'),
          ),
        ],
      ),
    );
  }

  /// Mostra dialog de erro
  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erro'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Completa o onboarding e navega para tela principal
  Future<void> _completeOnboarding() async {
    // Marca onboarding como completo
    // TODO: Salvar no SharedPreferences ou banco de dados
    
    if (!mounted) return;
    
    // Navega para tela principal
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF3B82F6),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header com indicadores de página
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botão voltar
                    if (_currentPage > 0)
                      IconButton(
                        onPressed: _previousPage,
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                    
                    // Indicadores de página
                    Row(
                      children: List.generate(
                        _pages.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == _currentPage
                                ? Colors.white
                                : Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                    
                    // Botão pular
                    if (_currentPage < _pages.length - 1)
                      TextButton(
                        onPressed: _skipToPermissions,
                        child: const Text(
                          'Pular',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
              
              // Conteúdo das páginas
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Ícone
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: page.color.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              page.icon,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 40),
                          
                          // Título
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Descrição
                          Text(
                            page.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              // Botões de ação
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isRequestingPermissions ? null : _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E3A8A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: _isRequestingPermissions
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1E3A8A),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Configurando Permissões...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _currentPage == _pages.length - 1
                                ? 'Configurar Permissões'
                                : 'Continuar',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modelo para páginas do onboarding
class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}