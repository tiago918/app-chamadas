import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/services.dart';
import '../database/repository.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Tela de splash exibida ao iniciar o aplicativo
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _isInitializing = true;
  String _initializationStatus = 'Inicializando...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Configura as animações da splash screen
  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    _animationController.forward();
  }

  /// Inicializa todos os serviços do aplicativo
  Future<void> _initializeApp() async {
    try {
      // Lista de tarefas de inicialização
      final initTasks = [
        _initializeDatabase,
        _initializePermissions,
        _initializeSpamDetection,
        _initializeCallService,
        _initializeSmsService,
        _initializeBlockService,
        _checkFirstRun,
      ];

      // Executa tarefas com progresso
      for (int i = 0; i < initTasks.length; i++) {
        await initTasks[i]();
        setState(() {
          _progress = (i + 1) / initTasks.length;
        });
        
        // Pequena pausa para mostrar o progresso
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Aguarda animação completar
      await _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 500));

      // Navega para próxima tela
      await _navigateToNextScreen();
    } catch (e) {
      _handleInitializationError(e);
    }
  }

  /// Inicializa o banco de dados
  Future<void> _initializeDatabase() async {
    setState(() {
      _initializationStatus = 'Configurando banco de dados...';
    });
    
    final repository = Repository();
    // Repository inicializado automaticamente
  }

  /// Verifica e solicita permissões necessárias
  Future<void> _initializePermissions() async {
    setState(() {
      _initializationStatus = 'Verificando permissões...';
    });
    
    final permissionService = PermissionService();
    
    // Verifica permissões críticas
    final hasCriticalPermissions = await permissionService.hasCriticalPermissions();
    if (!hasCriticalPermissions) {
      // Mostra dialog explicativo se necessário
      // Por enquanto, apenas registra
      debugPrint('Permissões críticas pendentes');
    }
  }

  /// Inicializa sistema de detecção de spam
  Future<void> _initializeSpamDetection() async {
    setState(() {
      _initializationStatus = 'Configurando detecção de spam...';
    });
    
    final integratedDetector = IntegratedSpamDetector();
    // Detector inicializado automaticamente
  }

  /// Inicializa serviço de chamadas
  Future<void> _initializeCallService() async {
    setState(() {
      _initializationStatus = 'Configurando monitoramento de chamadas...';
    });
    
    final callService = CallService();
    // Serviço inicializado automaticamente
  }

  /// Inicializa serviço de SMS
  Future<void> _initializeSmsService() async {
    setState(() {
      _initializationStatus = 'Configurando monitoramento de SMS...';
    });
    
    final smsService = SmsService();
    // Serviço inicializado automaticamente
  }

  /// Inicializa serviço de bloqueio
  Future<void> _initializeBlockService() async {
    setState(() {
      _initializationStatus = 'Carregando regras de bloqueio...';
    });
    
    final blockService = BlockService();
    // Serviço inicializado automaticamente
  }

  /// Verifica se é a primeira execução do app
  Future<void> _checkFirstRun() async {
    setState(() {
      _initializationStatus = 'Finalizando configuração...';
    });
    
    final securityService = SecurityService();
    // Serviço inicializado automaticamente
  }

  /// Navega para a próxima tela apropriada
  Future<void> _navigateToNextScreen() async {
    // Verifica se é primeira execução
    final isFirstRun = await _isFirstRun();
    
    if (!mounted) return;
    
    if (isFirstRun) {
      // Navega para onboarding
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      // Navega para tela principal
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  /// Verifica se é a primeira execução
  Future<bool> _isFirstRun() async {
    // Implementa lógica para verificar primeira execução
    // Por enquanto, sempre retorna false (não é primeira execução)
    return false;
  }

  /// Trata erros de inicialização
  void _handleInitializationError(dynamic error) {
    setState(() {
      _isInitializing = false;
      _initializationStatus = 'Erro na inicialização';
    });

    // Mostra dialog de erro
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Erro de Inicialização'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ocorreu um erro ao inicializar o aplicativo:',
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeApp(); // Tenta novamente
            },
            child: const Text('Tentar Novamente'),
          ),
          TextButton(
            onPressed: () {
              SystemNavigator.pop(); // Fecha o app
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A), // Azul escuro
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1E3A8A), // Azul escuro
                  Color(0xFF3B82F6), // Azul médio
                  Color(0xFF60A5FA), // Azul claro
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo e título
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo animado
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.security,
                                size: 60,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Título do app
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: const Column(
                            children: [
                              Text(
                                'CallGuard Pro',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Proteção Avançada contra Spam',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Área de progresso
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isInitializing) ...[
                          // Indicador de progresso
                          // Indicador de progresso
                          Container(
                            width: 200,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Status da inicialização
                          Text(
                            _initializationStatus,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Porcentagem
                          Text(
                            '${(_progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else ...[
                          // Indicador de carregamento simples
                          // Indicador de carregamento simples
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Rodapé
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'Versão 1.0.0',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}