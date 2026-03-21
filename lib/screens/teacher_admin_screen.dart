import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../models/teacher_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/admin_ui.dart';

class TeacherAdminScreen extends StatefulWidget {
  const TeacherAdminScreen({super.key});

  @override
  State<TeacherAdminScreen> createState() => _TeacherAdminScreenState();
}

class _TeacherAdminScreenState extends State<TeacherAdminScreen> {
  bool isLoading = true;
  List<TeacherModel> teachers = [];
  Logger logger = Logger();

  int get activeTeachers {
    return teachers.where((teacher) => teacher.active == 1).length;
  }

  @override
  void initState() {
    super.initState();
    loadTeachers();
  }

  Future<void> loadTeachers() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiService.getTeachers(schoolId: user.schoolId);

      if (response['success'] == true) {
        final List data = response['data'];
        teachers = data.map((e) => TeacherModel.fromJson(e)).toList();
      }
    } catch (e) {
      logger.i('ERRO AO CARREGAR PROFESSORES: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> showTeacherDialog({TeacherModel? teacher}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    final nameController = TextEditingController(text: teacher?.name ?? '');
    final emailController = TextEditingController(text: teacher?.email ?? '');
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return AdminFormDialog(
              title: teacher == null ? 'Novo professor' : 'Editar professor',
              subtitle: teacher == null
                  ? 'Cadastre o professor e defina uma senha inicial para liberar o acesso.'
                  : 'Atualize os dados do professor selecionado.',
              icon: Icons.people_outline,
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if ((value?.trim() ?? '').isEmpty) {
                            return 'Informe o nome';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) {
                            return 'Informe o email';
                          }
                          if (!emailPattern.hasMatch(email)) {
                            return 'Informe um email válido';
                          }
                          return null;
                        },
                      ),
                      if (teacher == null) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Senha inicial',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            final password = value?.trim() ?? '';
                            if (password.isEmpty) {
                              return 'Informe a senha inicial';
                            }
                            if (password.length < 6) {
                              return 'Use ao menos 6 caracteres';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final name = nameController.text.trim();
                          final email = emailController.text.trim();
                          final password = passwordController.text.trim();

                          setModalState(() {
                            saving = true;
                          });

                          Map<String, dynamic> response;

                          if (teacher == null) {
                            response = await ApiService.createTeacher(
                              schoolId: user.schoolId,
                              userId: user.id,
                              name: name,
                              email: email,
                              password: password,
                            );
                          } else {
                            response = await ApiService.updateTeacher(
                              schoolId: user.schoolId,
                              userId: user.id,
                              teacherId: teacher.id,
                              name: name,
                              email: email,
                            );
                          }

                          if (!mounted || !modalContext.mounted) return;

                          Navigator.pop(modalContext);

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                response['message'] ?? 'Operação concluída.',
                              ),
                            ),
                          );

                          if (response['success'] == true) {
                            loadTeachers();
                          }
                        },
                  child: Text(teacher == null ? 'Criar' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> toggleTeacher(TeacherModel teacher) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final response = await ApiService.toggleTeacherStatus(
      schoolId: user.schoolId,
      userId: user.id,
      teacherId: teacher.id,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message'] ?? 'Operação concluída.')),
    );

    if (response['success'] == true) {
      loadTeachers();
    }
  }

  Future<void> resetPassword(TeacherModel teacher) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();

    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return AdminFormDialog(
              title: 'Redefinir senha',
              subtitle:
                  'Defina uma nova senha para o professor selecionado com segurança.',
              icon: Icons.lock_reset,
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nova senha',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'Informe a nova senha';
                    }
                    if (text.length < 6) {
                      return 'Use ao menos 6 caracteres';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final newPassword = passwordController.text.trim();

                          setModalState(() {
                            saving = true;
                          });

                          final response =
                              await ApiService.resetTeacherPassword(
                                schoolId: user.schoolId,
                                userId: user.id,
                                teacherId: teacher.id,
                                newPassword: newPassword,
                              );

                          if (!mounted || !modalContext.mounted) return;

                          Navigator.pop(modalContext);

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                response['message'] ?? 'Operação concluída.',
                              ),
                            ),
                          );
                        },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;
    final isCompact = MediaQuery.of(context).size.width < 380;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCompact ? 'Professores' : 'Professores - ${user.schoolName}',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTeacherDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Novo professor'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadTeachers,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 14 : 16,
                  8,
                  isCompact ? 14 : 16,
                  24,
                ),
                children: [
                  const AdminHeaderCard(
                    title: 'Gerenciar professores',
                    subtitle:
                        'Mantenha docentes, acessos e redefinicoes de senha organizados em um só lugar.',
                    icon: Icons.people_outline,
                  ),
                  const SizedBox(height: 16),
                  AdminStatsPanel(
                    children: [
                      AdminStatCard(
                        label: 'Total',
                        value: teachers.length.toString(),
                        icon: Icons.badge_outlined,
                        accentColor: const Color(0xFF315FA8),
                      ),
                      AdminStatCard(
                        label: 'Ativos',
                        value: activeTeachers.toString(),
                        icon: Icons.verified_user_outlined,
                        accentColor: const Color(0xFF1D7A6D),
                      ),
                      AdminStatCard(
                        label: 'Inativos',
                        value: (teachers.length - activeTeachers).toString(),
                        icon: Icons.person_off_outlined,
                        accentColor: const Color(0xFFB54747),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (teachers.isEmpty)
                    const AdminEmptyState(
                      icon: Icons.people_outline,
                      title: 'Nenhum professor cadastrado.',
                      message:
                          'Adicione professores para liberar o acesso e o uso das reservas no aplicativo.',
                    )
                  else
                    ...teachers.map((teacher) {
                      final isActive = teacher.active == 1;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color:
                                        (isActive
                                                ? const Color(0xFF1D7A6D)
                                                : const Color(0xFFB54747))
                                            .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    isActive ? Icons.person : Icons.person_off,
                                    color: isActive
                                        ? const Color(0xFF1D7A6D)
                                        : const Color(0xFFB54747),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        teacher.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        teacher.email,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF5A7069),
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      AdminStatusBadge(
                                        label: isActive ? 'Ativo' : 'Inativo',
                                        accentColor: isActive
                                            ? const Color(0xFF1D7A6D)
                                            : const Color(0xFFB54747),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      showTeacherDialog(teacher: teacher);
                                    } else if (value == 'toggle') {
                                      toggleTeacher(teacher);
                                    } else if (value == 'password') {
                                      resetPassword(teacher);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(
                                        isActive ? 'Desativar' : 'Ativar',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'password',
                                      child: Text('Redefinir senha'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
