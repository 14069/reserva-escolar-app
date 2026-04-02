import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../utils/app_formatters.dart';
import 'lesson_slot_admin_screen.dart';
import 'new_booking_screen.dart';
import 'notifications_screen.dart';
import 'resource_admin_screen.dart';
import 'reports_admin_screen.dart';
import 'teacher_admin_screen.dart';
import 'class_group_admin_screen.dart';
import 'subject_admin_screen.dart';
import 'booking_admin_screen.dart';
import 'my_bookings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.instance.logScreenView(screenName: 'home');
      _loadUnreadNotificationCount();
    });
  }

  Future<void> _loadUnreadNotificationCount() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final response = await ApiService.getUnreadNotificationCount(
      schoolId: user.schoolId,
    );

    if (!mounted || response['success'] != true) return;

    final data = response['data'] as Map<String, dynamic>? ?? const {};
    setState(() {
      _unreadNotificationCount = (data['unread_count'] as num?)?.toInt() ?? 0;
    });
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );

    if (!mounted) return;
    _loadUnreadNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final preferences = context.watch<AppPreferencesProvider>();
    final user = authProvider.user!;
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;
    final isMobile = screenWidth < 640;
    final prefersPersonalGreeting = preferences.preferPersonalGreeting;
    final shouldShowPersonalGreeting = isCompact || prefersPersonalGreeting;
    final firstName = _extractFirstName(user.name);
    final heroTitle = shouldShowPersonalGreeting
        ? 'Bem-vindo, $firstName'
        : user.schoolName;
    final heroDescription = user.isTechnician
        ? (shouldShowPersonalGreeting
              ? 'Gerencie recursos, acompanhe reservas e mantenha a rotina da escola organizada com a sua conta técnica.'
              : 'Painel central para acompanhar agendamentos, reservas e administração da escola.')
        : (shouldShowPersonalGreeting
              ? 'Reserve recursos, acompanhe seus pedidos e organize a sua rotina com mais rapidez.'
              : 'Bem-vindo ao painel da escola. Escolha uma opção abaixo para reservar recursos e acompanhar suas solicitações.');
    final primaryProfessorItem = _HomeMenuItem(
      icon: Icons.add_box,
      label: 'Novo Agendamento',
      description: 'Monte uma nova reserva escolhendo recurso, data e aulas.',
      accentColor: const Color(0xFF0F766E),
      builder: () => const NewBookingScreen(),
    );
    final everydayItems = <_HomeMenuItem>[
      if (user.isTechnician)
        primaryProfessorItem
      else
        _HomeMenuItem(
          icon: Icons.list_alt,
          label: 'Meus Agendamentos',
          description: 'Consulte reservas ativas, histórico e cancelamentos.',
          accentColor: const Color(0xFF1D7A6D),
          builder: () => const MyBookingsV2Screen(),
        ),
      if (user.isTechnician)
        _HomeMenuItem(
          icon: Icons.list_alt,
          label: 'Meus Agendamentos',
          description: 'Consulte reservas ativas, histórico e cancelamentos.',
          accentColor: const Color(0xFF1D7A6D),
          builder: () => const MyBookingsV2Screen(),
        ),
    ];
    final adminItems = <_HomeMenuItem>[
      if (user.isTechnician)
        _HomeMenuItem(
          icon: Icons.assignment,
          label: 'Painel de Agendamentos',
          description:
              'Acompanhe reservas da escola e intervenha quando preciso.',
          accentColor: const Color(0xFFB54747),
          builder: () => const BookingAdminScreen(),
        ),
      if (user.isTechnician)
        _HomeMenuItem(
          icon: Icons.bar_chart_rounded,
          label: 'Relatórios',
          description:
              'Consulte indicadores, rankings de uso e tendências dos agendamentos.',
          accentColor: const Color(0xFF126180),
          builder: () => const ReportsAdminScreen(),
        ),
      if (user.isTechnician)
        _HomeMenuItem(
          icon: Icons.settings,
          label: 'Gerenciar Recursos',
          description:
              'Cadastre e organize laboratórios, salas e equipamentos.',
          accentColor: const Color(0xFF8A6A10),
          builder: () => const ResourceAdminScreen(),
        ),
      if (user.isTechnician)
        _HomeMenuItem(
          icon: Icons.people,
          label: 'Gerenciar Professores',
          description: 'Atualize docentes, acessos e dados de contato.',
          accentColor: const Color(0xFF315FA8),
          builder: () => const TeacherAdminScreen(),
        ),
      if (user.isTechnician)
        _HomeMenuItem(
          icon: Icons.groups,
          label: 'Gerenciar Turmas',
          description: 'Mantenha as turmas sincronizadas com o ano letivo.',
          accentColor: const Color(0xFF7A4A9E),
          builder: () => const ClassGroupAdminScreen(),
        ),
      if (user.isTechnician)
        _HomeMenuItem(
          icon: Icons.menu_book,
          label: 'Gerenciar Disciplinas',
          description: 'Revise os componentes curriculares disponiveis.',
          accentColor: const Color(0xFFAA5F2C),
          builder: () => const SubjectAdminScreen(),
        ),
      if (user.isTechnician)
        _HomeMenuItem(
          icon: Icons.schedule,
          label: 'Gerenciar Aulas',
          description: 'Configure horários, rótulos e sequências das aulas.',
          accentColor: const Color(0xFF0B7285),
          builder: () => const LessonSlotAdminScreen(),
        ),
    ];
    final quickStats = <_HomeQuickStat>[
      _HomeQuickStat(
        label: 'Perfil',
        value: user.roleLabel,
        icon: user.isTechnician ? Icons.verified_user : Icons.person,
      ),
      _HomeQuickStat(
        label: 'Codigo',
        value: user.schoolCode,
        icon: Icons.qr_code_2,
      ),
      _HomeQuickStat(
        label: 'Usuario',
        value: user.name,
        icon: Icons.badge_outlined,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompact ? 'Início' : user.schoolName),
        actions: [
          IconButton(
            onPressed: _openNotifications,
            icon: _NotificationBellIcon(count: _unreadNotificationCount),
            tooltip: 'Notificações',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _AccountMenuAction(isCompact: isCompact, user: user),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 14 : 16,
          8,
          isCompact ? 14 : 16,
          24,
        ),
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 18 : 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, const Color(0xFF184E44)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    user.isTechnician
                        ? 'Painel técnico'
                        : 'Painel do professor',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  heroTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  heroDescription,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.84),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (isMobile)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final stat in quickStats)
                  SizedBox(
                    width: (screenWidth - ((isCompact ? 28 : 32) + 12)) / 2,
                    child: _HomeStatCard(stat: stat, compact: true),
                  ),
              ],
            )
          else
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quickStats.length,
                separatorBuilder: (_, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final stat = quickStats[index];
                  return _HomeStatCard(stat: stat);
                },
              ),
            ),
          const SizedBox(height: 24),
          if (!user.isTechnician) ...[
            _FeaturedProfessorAction(
              item: primaryProfessorItem,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => primaryProfessorItem.builder(),
                  ),
                );
                if (!mounted) return;
                _loadUnreadNotificationCount();
              },
            ),
            const SizedBox(height: 24),
          ],
          _HomeSection(
            title: user.isTechnician ? 'Rotina do dia' : 'Suas ações',
            subtitle: user.isTechnician
                ? 'Atalhos mais usados para acompanhar reservas e agir rápido.'
                : 'Acompanhe suas reservas e acesse rapidamente as funções principais.',
            items: everydayItems,
            compactHeader: !user.isTechnician,
            onReturnFromItem: _loadUnreadNotificationCount,
          ),
          if (user.isTechnician) ...[
            const SizedBox(height: 24),
            _HomeSection(
              title: isCompact ? 'Administração' : 'Administração da escola',
              subtitle:
                  'Cadastros, configurações e gestão do ambiente escolar.',
              items: adminItems,
              emphasize: true,
              onReturnFromItem: _loadUnreadNotificationCount,
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationBellIcon extends StatelessWidget {
  final int count;

  const _NotificationBellIcon({required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none_outlined),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFB54747),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum _AccountMenuActionValue { profile, changePassword, preferences, logout }

class _AccountMenuAction extends StatelessWidget {
  final bool isCompact;
  final UserModel user;

  const _AccountMenuAction({required this.isCompact, required this.user});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final preferences = context.watch<AppPreferencesProvider>();
    final isLoggingOut = authProvider.isLoggingOut;
    final colorScheme = Theme.of(context).colorScheme;
    final initials = _buildInitials(user.name);

    Future<void> handleLogout() async {
      if (isLoggingOut) return;

      final shouldLogout = preferences.confirmLogoutBeforeExit
          ? await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  title: const Text('Sair da conta?'),
                  content: Text(
                    'Você está conectado como ${user.name}. Para voltar, será preciso fazer login novamente.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Sair'),
                    ),
                  ],
                );
              },
            )
          : true;

      if (shouldLogout != true || !context.mounted) return;

      await context.read<AuthProvider>().logout();
    }

    Future<void> openAccountDetails() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _AccountDetailsSheet(user: user, initials: initials),
      );
    }

    Future<void> openChangePassword() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _ChangePasswordSheet(user: user),
      );
    }

    Future<void> openPreferences() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _AccountPreferencesSheet(),
      );
    }

    final buttonChild = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 6 : 5,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: isCompact ? 16 : 18,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                foregroundColor: colorScheme.primary,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: isCompact ? 11 : 12,
                  ),
                ),
              ),
              if (isLoggingOut)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.surface, width: 2),
                    ),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          if (!isCompact) ...[
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  isLoggingOut ? 'Saindo...' : user.roleLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ],
      ),
    );

    return PopupMenuButton<_AccountMenuActionValue>(
      enabled: !isLoggingOut,
      tooltip: 'Abrir menu da conta',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      onSelected: (value) async {
        switch (value) {
          case _AccountMenuActionValue.profile:
            await openAccountDetails();
            break;
          case _AccountMenuActionValue.changePassword:
            await openChangePassword();
            break;
          case _AccountMenuActionValue.preferences:
            await openPreferences();
            break;
          case _AccountMenuActionValue.logout:
            await handleLogout();
            break;
        }
      },
      itemBuilder: (menuContext) => [
        PopupMenuItem<_AccountMenuActionValue>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                  foregroundColor: colorScheme.primary,
                  child: Text(
                    initials,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _AccountBadge(label: user.roleLabel),
                          _AccountBadge(label: 'Código ${user.schoolCode}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<_AccountMenuActionValue>(
          value: _AccountMenuActionValue.profile,
          child: Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 20),
              SizedBox(width: 12),
              Text(
                'Minha conta',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const PopupMenuItem<_AccountMenuActionValue>(
          value: _AccountMenuActionValue.changePassword,
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 20),
              SizedBox(width: 12),
              Text(
                'Alterar senha',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const PopupMenuItem<_AccountMenuActionValue>(
          value: _AccountMenuActionValue.preferences,
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 20),
              SizedBox(width: 12),
              Text(
                'Preferências',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        PopupMenuItem<_AccountMenuActionValue>(
          value: _AccountMenuActionValue.logout,
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: Color(0xFFB54747)),
              SizedBox(width: 12),
              Text(
                'Sair da conta',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7F1D1D),
                ),
              ),
            ],
          ),
        ),
      ],
      child: buttonChild,
    );
  }

  String _buildInitials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'U';

    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return '$first$last'.toUpperCase();
  }
}

class _AccountBadge extends StatelessWidget {
  final String label;

  const _AccountBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _AccountDetailsSheet extends StatelessWidget {
  final UserModel user;
  final String initials;

  const _AccountDetailsSheet({required this.user, required this.initials});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primary, const Color(0xFF184E44)],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    foregroundColor: colorScheme.onPrimary,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onPrimary.withValues(
                                  alpha: 0.86,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Detalhes da conta',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _AccountInfoCard(
              children: [
                _AccountInfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Perfil',
                  value: user.roleLabel,
                ),
                _AccountInfoRow(
                  icon: Icons.school_outlined,
                  label: 'Escola',
                  value: user.schoolName,
                ),
                _AccountInfoRow(
                  icon: Icons.qr_code_2_outlined,
                  label: 'Código da escola',
                  value: user.schoolCode,
                ),
                _AccountInfoRow(
                  icon: Icons.schedule_rounded,
                  label: 'Sessão expira em',
                  value: _formatSessionExpiry(user.authTokenExpiresAt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountPreferencesSheet extends StatelessWidget {
  const _AccountPreferencesSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppPreferencesProvider>(
      builder: (context, preferences, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Preferências',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Essas escolhas são salvas automaticamente neste dispositivo.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (!preferences.isLoaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _AccountInfoCard(
                    children: [
                      Text(
                        'Tema do aplicativo',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded),
                            label: Text('Claro'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded),
                            label: Text('Escuro'),
                          ),
                        ],
                        selected: {preferences.themeMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) {
                          preferences.setThemeMode(selection.first);
                        },
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        value: preferences.confirmLogoutBeforeExit,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Confirmar antes de sair'),
                        subtitle: const Text(
                          'Pede confirmação antes de encerrar a sessão.',
                        ),
                        onChanged: preferences.setConfirmLogoutBeforeExit,
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        value: preferences.preferPersonalGreeting,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Saudação personalizada na home'),
                        subtitle: const Text(
                          'Mostra seu nome no destaque principal da tela inicial.',
                        ),
                        onChanged: preferences.setPreferPersonalGreeting,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  final UserModel user;

  const _ChangePasswordSheet({required this.user});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSaving = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
    });

    final response = await ApiService.changeMyPassword(
      schoolId: widget.user.schoolId,
      userId: widget.user.id,
      currentPassword: _currentPasswordController.text.trim(),
      newPassword: _newPasswordController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response['message'] ?? 'Operação concluída.')),
    );

    if (response['success'] == true) {
      await AnalyticsService.instance.logPasswordChanged();
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Alterar senha',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Atualize sua senha com segurança para manter o acesso protegido.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _AccountInfoCard(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Use pelo menos 6 caracteres e evite repetir a senha atual.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: !_showCurrentPassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Senha atual',
                            prefixIcon: const Icon(Icons.lock_open_outlined),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _showCurrentPassword = !_showCurrentPassword;
                                });
                              },
                              icon: Icon(
                                _showCurrentPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value?.trim() ?? '').isEmpty) {
                              return 'Informe a senha atual';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: !_showNewPassword,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'Nova senha',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _showNewPassword = !_showNewPassword;
                                });
                              },
                              icon: Icon(
                                _showNewPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Informe a nova senha';
                            }
                            if (text.length < 6) {
                              return 'Use ao menos 6 caracteres';
                            }
                            if (text ==
                                _currentPasswordController.text.trim()) {
                              return 'A nova senha deve ser diferente da atual';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_showConfirmPassword,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'Confirmar nova senha',
                            prefixIcon: const Icon(
                              Icons.verified_user_outlined,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _showConfirmPassword = !_showConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Confirme a nova senha';
                            }
                            if (text != _newPasswordController.text.trim()) {
                              return 'As senhas não conferem';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_reset),
                    label: Text(_isSaving ? 'Salvando...' : 'Atualizar senha'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  final List<Widget> children;

  const _AccountInfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AccountInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMenuItem {
  final IconData icon;
  final String label;
  final String description;
  final Color accentColor;
  final Widget Function() builder;

  const _HomeMenuItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.accentColor,
    required this.builder,
  });
}

class _HomeQuickStat {
  final String label;
  final String value;
  final IconData icon;

  const _HomeQuickStat({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _HomeButton extends StatelessWidget {
  final _HomeMenuItem item;
  final VoidCallback onTap;

  const _HomeButton({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: item.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(item.icon, color: item.accentColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: item.accentColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeStatCard extends StatelessWidget {
  final _HomeQuickStat stat;
  final bool compact;

  const _HomeStatCard({required this.stat, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: compact ? null : 180,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stat.icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            stat.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 15 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_HomeMenuItem> items;
  final bool emphasize;
  final bool compactHeader;
  final VoidCallback? onReturnFromItem;

  const _HomeSection({
    required this.title,
    required this.subtitle,
    required this.items,
    this.emphasize = false,
    this.compactHeader = false,
    this.onReturnFromItem,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(emphasize ? 16 : 0),
      decoration: emphasize
          ? BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: colorScheme.outlineVariant),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (emphasize)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Técnico',
                style: TextStyle(
                  color: Color(0xFF0F766E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (emphasize) const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (!compactHeader) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              final tileWidth = isWide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: tileWidth,
                      child: _HomeButton(
                        item: item,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => item.builder()),
                          );
                          onReturnFromItem?.call();
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeaturedProfessorAction extends StatelessWidget {
  final _HomeMenuItem item;
  final VoidCallback onTap;

  const _FeaturedProfessorAction({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [item.accentColor, const Color(0xFF184E44)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(item.icon, color: colorScheme.onPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ação principal para montar uma nova reserva em poucos passos.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.84),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward, color: colorScheme.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

String _extractFirstName(String fullName) {
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) return 'Usuario';

  return trimmed.split(RegExp(r'\s+')).first;
}

String _formatSessionExpiry(String rawValue) {
  return AppFormatters.formatSessionExpiry(rawValue);
}
