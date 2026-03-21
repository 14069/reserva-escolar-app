import 'package:flutter/material.dart';

import '../services/api_service.dart';

class SchoolRegistrationDraft {
  final String schoolCode;
  final String technicianEmail;

  const SchoolRegistrationDraft({
    required this.schoolCode,
    required this.technicianEmail,
  });
}

class RegisterSchoolScreen extends StatefulWidget {
  const RegisterSchoolScreen({super.key});

  @override
  State<RegisterSchoolScreen> createState() => _RegisterSchoolScreenState();
}

class _RegisterSchoolScreenState extends State<RegisterSchoolScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolNameController = TextEditingController();
  final _schoolCodeController = TextEditingController();
  final _schoolPasswordController = TextEditingController();
  final _confirmSchoolPasswordController = TextEditingController();
  final _technicianNameController = TextEditingController();
  final _technicianEmailController = TextEditingController();
  final _technicianPasswordController = TextEditingController();
  final _confirmTechnicianPasswordController = TextEditingController();
  final _chromebooksCountController = TextEditingController(text: '0');
  final _audiovisualCountController = TextEditingController(text: '0');
  final _spacesCountController = TextEditingController(text: '0');
  final _lessonCountController = TextEditingController(text: '6');
  final _classGroupsController = TextEditingController();
  final _subjectsController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscureSchoolPassword = true;
  bool _obscureConfirmSchoolPassword = true;
  bool _obscureTechnicianPassword = true;
  bool _obscureConfirmTechnicianPassword = true;

  @override
  void dispose() {
    _schoolNameController.dispose();
    _schoolCodeController.dispose();
    _schoolPasswordController.dispose();
    _confirmSchoolPasswordController.dispose();
    _technicianNameController.dispose();
    _technicianEmailController.dispose();
    _technicianPasswordController.dispose();
    _confirmTechnicianPasswordController.dispose();
    _chromebooksCountController.dispose();
    _audiovisualCountController.dispose();
    _spacesCountController.dispose();
    _lessonCountController.dispose();
    _classGroupsController.dispose();
    _subjectsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    final normalizedSchoolCode = _schoolCodeController.text
        .trim()
        .toUpperCase();
    final classGroups = _parseMultilineItems(_classGroupsController.text);
    final subjects = _parseMultilineItems(_subjectsController.text);
    final response = await ApiService.registerSchool(
      schoolName: _schoolNameController.text.trim(),
      schoolCode: normalizedSchoolCode,
      schoolPassword: _schoolPasswordController.text.trim(),
      technicianName: _technicianNameController.text.trim(),
      technicianEmail: _technicianEmailController.text.trim(),
      technicianPassword: _technicianPasswordController.text.trim(),
      chromebooksCount: _parseCount(_chromebooksCountController.text),
      audiovisualCount: _parseCount(_audiovisualCountController.text),
      spacesCount: _parseCount(_spacesCountController.text),
      classGroups: classGroups,
      subjects: subjects,
      lessonCount: _parseCount(_lessonCountController.text),
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    final message =
        response['message']?.toString() ??
        'Não foi possível concluir o cadastro da escola.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (response['success'] == true) {
      Navigator.pop(
        context,
        SchoolRegistrationDraft(
          schoolCode: normalizedSchoolCode,
          technicianEmail: _technicianEmailController.text.trim(),
        ),
      );
    }
  }

  int _parseCount(String value) {
    return int.tryParse(value.trim()) ?? 0;
  }

  List<String> _parseMultilineItems(String value) {
    return value
        .split(RegExp(r'[\n,;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;

    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar escola')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withValues(alpha: 0.12),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isCompact ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.all(isCompact ? 18 : 24),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: isCompact ? 58 : 66,
                          height: isCompact ? 58 : 66,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.domain_add_rounded,
                            color: colorScheme.onPrimary,
                            size: isCompact ? 30 : 34,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Criar acesso da escola',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cadastre a escola e o primeiro técnico responsável. Depois disso, esse acesso poderá entrar no sistema e alimentar os demais dados.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                        ),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dados da escola',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _schoolNameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nome da escola',
                                prefixIcon: Icon(Icons.school_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Informe o nome da escola';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _schoolCodeController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Código da escola',
                                hintText: 'Ex.: ESC001',
                                prefixIcon: Icon(Icons.qr_code_2_outlined),
                              ),
                              validator: (value) {
                                final trimmed = value?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return 'Informe o código da escola';
                                }
                                if (trimmed.length < 4) {
                                  return 'Use pelo menos 4 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Segurança da escola',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _schoolPasswordController,
                              obscureText: _obscureSchoolPassword,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Senha institucional da escola',
                                prefixIcon: const Icon(Icons.shield_outlined),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscureSchoolPassword =
                                          !_obscureSchoolPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscureSchoolPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final trimmed = value?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return 'Informe a senha da escola';
                                }
                                if (trimmed.length < 6) {
                                  return 'Use pelo menos 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmSchoolPasswordController,
                              obscureText: _obscureConfirmSchoolPassword,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Confirmar senha da escola',
                                prefixIcon: const Icon(Icons.verified_outlined),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmSchoolPassword =
                                          !_obscureConfirmSchoolPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscureConfirmSchoolPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if ((value?.trim() ?? '').isEmpty) {
                                  return 'Confirme a senha da escola';
                                }
                                if (value!.trim() !=
                                    _schoolPasswordController.text.trim()) {
                                  return 'As senhas da escola não conferem';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Primeiro técnico',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _technicianNameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nome do técnico',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Informe o nome do técnico';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _technicianEmailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email do técnico',
                                hintText: 'tecnico@escola.com',
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                              validator: (value) {
                                final trimmed = value?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return 'Informe o email do técnico';
                                }
                                if (!trimmed.contains('@')) {
                                  return 'Informe um email válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _technicianPasswordController,
                              obscureText: _obscureTechnicianPassword,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Senha inicial',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscureTechnicianPassword =
                                          !_obscureTechnicianPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscureTechnicianPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final trimmed = value?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return 'Informe uma senha inicial';
                                }
                                if (trimmed.length < 6) {
                                  return 'Use pelo menos 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmTechnicianPasswordController,
                              obscureText: _obscureConfirmTechnicianPassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_isSubmitting) {
                                  _submit();
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Confirmar senha',
                                prefixIcon: const Icon(
                                  Icons.verified_user_outlined,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmTechnicianPassword =
                                          !_obscureConfirmTechnicianPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscureConfirmTechnicianPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if ((value?.trim() ?? '').isEmpty) {
                                  return 'Confirme a senha';
                                }
                                if (value!.trim() !=
                                    _technicianPasswordController.text.trim()) {
                                  return 'As senhas não conferem';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Configuração inicial',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Esses dados alimentam a escola logo no primeiro cadastro, usando o contrato que sua API ja implementa.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 560;
                                final fieldWidth = isWide
                                    ? (constraints.maxWidth - 24) / 3
                                    : constraints.maxWidth;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: fieldWidth,
                                      child: TextFormField(
                                        controller: _chromebooksCountController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Chromebooks',
                                          prefixIcon: Icon(
                                            Icons.laptop_chromebook,
                                          ),
                                        ),
                                        validator: _validateNonNegativeCount,
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth,
                                      child: TextFormField(
                                        controller: _audiovisualCountController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Audiovisual',
                                          prefixIcon: Icon(Icons.tv_outlined),
                                        ),
                                        validator: _validateNonNegativeCount,
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth,
                                      child: TextFormField(
                                        controller: _spacesCountController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Espaços',
                                          prefixIcon: Icon(
                                            Icons.meeting_room_outlined,
                                          ),
                                        ),
                                        validator: _validateNonNegativeCount,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _lessonCountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantidade de aulas',
                                prefixIcon: Icon(Icons.schedule_outlined),
                              ),
                              validator: (value) {
                                final parsed = int.tryParse(
                                  value?.trim() ?? '',
                                );
                                if (parsed == null || parsed <= 0) {
                                  return 'Informe uma quantidade maior que zero';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _classGroupsController,
                              minLines: 3,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: 'Turmas iniciais',
                                hintText: 'Uma por linha. Ex.: 1 Ano A',
                                prefixIcon: Icon(Icons.groups_outlined),
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _subjectsController,
                              minLines: 3,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: 'Disciplinas iniciais',
                                hintText: 'Uma por linha. Ex.: Matemática',
                                prefixIcon: Icon(Icons.menu_book_outlined),
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                'API real verificada em /opt/lampp/htdocs/reserva_escolar_api_v2/register_school.php. Esta tela envia os campos que esse endpoint já espera hoje.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : _submit,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                        ),
                                      )
                                    : const Icon(Icons.domain_add_rounded),
                                label: Text(
                                  _isSubmitting
                                      ? 'Cadastrando...'
                                      : 'Cadastrar escola',
                                ),
                              ),
                            ),
                          ],
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

  String? _validateNonNegativeCount(String? value) {
    final trimmed = value?.trim() ?? '';
    final parsed = int.tryParse(trimmed);
    if (trimmed.isEmpty || parsed == null || parsed < 0) {
      return 'Use 0 ou mais';
    }
    return null;
  }
}
