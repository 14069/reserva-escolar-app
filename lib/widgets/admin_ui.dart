import 'package:flutter/material.dart';

class AdminHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const AdminHeaderCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 380;

    return Container(
      padding: EdgeInsets.all(isCompact ? 18 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF184E44)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isCompact ? 48 : 54,
            height: isCompact ? 48 : 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: colorScheme.onPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: isCompact ? 24 : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.84),
                    height: 1.4,
                    fontSize: isCompact ? 14 : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminStatsPanel extends StatelessWidget {
  final List<Widget> children;

  const AdminStatsPanel({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        late final int columns;

        if (width < 420) {
          columns = 1;
        } else if (width < 760) {
          columns = 2;
        } else {
          columns = children.length >= 3 ? 3 : children.length;
        }

        final spacing = 12.0;
        final tileWidth = columns <= 1
            ? width
            : (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

class AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 380;

    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD6E1DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: const Color(0xFF5A7069)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: isCompact ? 24 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD6E1DA)),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              icon,
              size: 34,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5A7069),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class AdminStatusBadge extends StatelessWidget {
  final String label;
  final Color accentColor;

  const AdminStatusBadge({
    super.key,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class AdminFormDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget content;
  final List<Widget> actions;

  const AdminFormDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 380;
    final maxHeight =
        MediaQuery.of(context).size.height * (isCompact ? 0.7 : 0.75);

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 24,
        vertical: 24,
      ),
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titlePadding: EdgeInsets.fromLTRB(
        isCompact ? 18 : 24,
        isCompact ? 18 : 24,
        isCompact ? 18 : 24,
        0,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        isCompact ? 18 : 24,
        20,
        isCompact ? 18 : 24,
        8,
      ),
      actionsPadding: EdgeInsets.fromLTRB(16, 0, 16, isCompact ? 12 : 16),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isCompact ? 44 : 48,
            height: isCompact ? 44 : 48,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: isCompact ? 20 : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5A7069),
                    height: 1.35,
                    fontSize: isCompact ? 13 : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(child: content),
      ),
      actions: actions,
    );
  }
}

class AdminConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String confirmLabel;
  final String cancelLabel;
  final Color accentColor;

  const AdminConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.confirmLabel = 'Confirmar',
    this.cancelLabel = 'Cancelar',
    this.accentColor = const Color(0xFFB54747),
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 380;
    final maxHeight = MediaQuery.of(context).size.height * 0.55;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 24,
        vertical: 24,
      ),
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titlePadding: EdgeInsets.fromLTRB(
        isCompact ? 18 : 24,
        isCompact ? 18 : 24,
        isCompact ? 18 : 24,
        0,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        isCompact ? 18 : 24,
        20,
        isCompact ? 18 : 24,
        8,
      ),
      actionsPadding: EdgeInsets.fromLTRB(16, 0, 16, isCompact ? 12 : 16),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: isCompact ? 20 : null,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: const Color(0xFF5A7069),
              fontSize: isCompact ? 13 : null,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: accentColor),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class AdminDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const AdminDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    color: Color(0xFF5A7069),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: value, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AdminEntityCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final Widget? trailing;
  final List<Widget> details;
  final List<Widget> footerActions;

  const AdminEntityCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    this.subtitle,
    this.badge,
    this.trailing,
    this.details = const [],
    this.footerActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF5A7069)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (badge != null) ...[const SizedBox(width: 8), badge!],
                if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 16),
              ..._withSpacing(details, 10),
            ],
            if (footerActions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.end,
                runSpacing: 8,
                spacing: 8,
                children: footerActions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<Widget> _withSpacing(List<Widget> children, double spacing) {
  final items = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) {
      items.add(SizedBox(height: spacing));
    }
    items.add(children[i]);
  }
  return items;
}
