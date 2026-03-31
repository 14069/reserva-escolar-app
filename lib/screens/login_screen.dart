import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import 'register_school_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _schoolCodeController = TextEditingController(
    text: kDebugMode ? 'ESC001' : '',
  );
  final _emailController = TextEditingController(
    text: kDebugMode ? 'tecnico@escola.com' : '',
  );
  final _passwordController = TextEditingController(
    text: kDebugMode ? '123456' : '',
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.instance.logScreenView(screenName: 'login');
    });
  }

  Future<void> _openSchoolRegistration() async {
    await AnalyticsService.instance.logOpenSchoolRegistration();

    if (!mounted) return;

    final result = await Navigator.push<SchoolRegistrationDraft>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterSchoolScreen()),
    );

    if (result == null || !mounted) return;

    setState(() {
      _schoolCodeController.text = result.schoolCode;
      _emailController.text = result.technicianEmail;
      _passwordController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Escola cadastrada. Informe a senha criada para acessar.',
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.login(
      schoolCode: _schoolCodeController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.lastErrorMessage ??
                'Falha no login. Verifique código da escola, email e senha.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _schoolCodeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;

    return Scaffold(
      appBar: AppBar(title: const Text('Reserva Escolar'), centerTitle: true),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withValues(alpha: 0.14),
              const Color(0xFFF3F6F2),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isCompact ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.all(isCompact ? 18 : 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: colorScheme.primary.withValues(alpha: 0.08),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: isCompact ? 68 : 84,
                          height: isCompact ? 68 : 84,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Icon(
                            Icons.school,
                            size: isCompact ? 36 : 44,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                        SizedBox(height: isCompact ? 14 : 18),
                        Text(
                          'Acesso',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Entre para reservar recursos e acompanhar seus agendamentos com mais rapidez.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF4E6660),
                                  height: 1.4,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: isCompact ? 16 : 20),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isCompact ? 18 : 24),
                      child: Form(
                        key: _formKey,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Identifique sua escola',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (!isCompact) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Use seu código escolar e suas credenciais para continuar.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF5A7069),
                                      ),
                                ),
                              ],
                              if (kDebugMode) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(isCompact ? 12 : 14),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.science_outlined,
                                        color: colorScheme.primary,
                                        size: isCompact ? 20 : 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Modo debug com dados de exemplo preenchidos.',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: isCompact ? 13 : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              SizedBox(height: isCompact ? 18 : 24),
                              TextFormField(
                                controller: _schoolCodeController,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.organizationName,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Código da escola',
                                  hintText: 'Ex.: ESC001',
                                  prefixIcon: Icon(Icons.domain_outlined),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Informe o código da escola';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'voce@escola.com',
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Informe o email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) {
                                  if (!authProvider.isLoading) {
                                    _handleLogin();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Senha',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Informe a senha';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _handleLogin,
                                  icon: authProvider.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                          ),
                                        )
                                      : const Icon(Icons.login),
                                  label: Text(
                                    authProvider.isLoading
                                        ? 'Entrando...'
                                        : 'Entrar',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _openSchoolRegistration,
                                  icon: const Icon(Icons.domain_add_rounded),
                                  label: const Text('Cadastrar escola'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
