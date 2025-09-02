# App Chamadas Avançado 📱

Um aplicativo Flutter avançado para bloqueio inteligente de chamadas e SMS indesejados, utilizando inteligência artificial e análise comportamental.

## 🚀 Características Principais

### 🛡️ Proteção Inteligente
- **Detecção de Spam com IA**: Utiliza TensorFlow Lite para identificar padrões de spam
- **Análise Comportamental**: Monitora comportamentos suspeitos em tempo real
- **Bloqueio Automático**: Sistema integrado de bloqueio baseado em regras personalizáveis
- **Aprendizado Contínuo**: O sistema melhora com o uso, adaptando-se aos padrões locais

### 📊 Funcionalidades Avançadas
- **Dashboard Completo**: Visualização detalhada de chamadas e mensagens bloqueadas
- **Histórico Detalhado**: Registro completo de todas as atividades
- **Estatísticas em Tempo Real**: Gráficos e métricas de proteção
- **Configurações Personalizáveis**: Regras de bloqueio adaptáveis às suas necessidades

### 🔒 Segurança e Privacidade
- **Criptografia Avançada**: Todos os dados são criptografados localmente
- **Armazenamento Seguro**: Utiliza Flutter Secure Storage
- **Autenticação Biométrica**: Suporte a impressão digital e reconhecimento facial
- **Controle Total**: Todos os dados permanecem no seu dispositivo

## 🛠️ Tecnologias Utilizadas

- **Flutter 3.8+**: Framework multiplataforma
- **Dart**: Linguagem de programação
- **TensorFlow Lite**: Machine Learning para detecção de spam
- **SQLite**: Banco de dados local
- **Provider/Riverpod**: Gerenciamento de estado
- **Flutter Secure Storage**: Armazenamento seguro
- **Permission Handler**: Gerenciamento de permissões

## 📋 Pré-requisitos

- Flutter SDK 3.8.1 ou superior
- Dart SDK 3.0+
- Android SDK (para build Android)
- Android 8.0 (API level 26) ou superior

## 🚀 Instalação e Configuração

### 1. Clone o repositório
```bash
git clone https://github.com/tiago918/app-chamadas.git
cd app-chamadas
```

### 2. Instale as dependências
```bash
flutter pub get
```

### 3. Configure as permissões
O app requer as seguintes permissões:
- `PHONE`: Para interceptar chamadas
- `SMS`: Para interceptar mensagens
- `CONTACTS`: Para gerenciar contatos
- `STORAGE`: Para armazenamento de dados
- `SYSTEM_ALERT_WINDOW`: Para exibir alertas do sistema

### 4. Build do projeto
```bash
# Para debug
flutter build apk --debug

# Para release
flutter build apk --release
```

## 📱 Funcionalidades Detalhadas

### Sistema de Bloqueio Inteligente
- **Listas Negras Dinâmicas**: Atualização automática de números suspeitos
- **Análise de Padrões**: Identificação de comportamentos típicos de spam
- **Bloqueio Contextual**: Considera horário, frequência e origem das chamadas

### Interface do Usuário
- **Design Material**: Interface moderna e intuitiva
- **Tema Escuro/Claro**: Suporte completo a temas
- **Animações Fluidas**: Experiência de usuário premium
- **Acessibilidade**: Suporte completo a recursos de acessibilidade

### Análise e Relatórios
- **Estatísticas Detalhadas**: Gráficos de chamadas bloqueadas por período
- **Relatórios Personalizados**: Exportação de dados em diferentes formatos
- **Tendências**: Análise de padrões de spam ao longo do tempo

## 🔧 Configuração Avançada

### Personalização de Regras
```dart
// Exemplo de regra personalizada
BlockRule customRule = BlockRule(
  name: 'Horário Comercial',
  pattern: r'^\+55\d{10,11}$',
  timeRange: TimeRange(start: '09:00', end: '18:00'),
  action: BlockAction.block,
  priority: RulePriority.high,
);
```

### Configuração de IA
```dart
// Configuração do modelo de ML
MLConfig mlConfig = MLConfig(
  modelPath: 'assets/models/spam_detector.tflite',
  threshold: 0.8,
  enableLearning: true,
  updateFrequency: Duration(hours: 24),
);
```

## 🤝 Contribuição

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## 📞 Suporte

Para suporte e dúvidas:
- Abra uma [issue](https://github.com/tiago918/app-chamadas/issues)
- Entre em contato através do email: suporte@appchamadas.com

## 🎯 Roadmap

- [ ] Integração com APIs de verificação de números
- [ ] Suporte a múltiplos idiomas
- [ ] Sincronização em nuvem (opcional)
- [ ] Widget para tela inicial
- [ ] Integração com assistentes virtuais
- [ ] Modo offline completo

---

**Desenvolvido com ❤️ usando Flutter**
