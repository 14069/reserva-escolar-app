import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Divider(color: colorScheme.outlineVariant, thickness: 1),
          const SizedBox(height: 12),
          Text(
            'Reserva Escolar - Projeto Desenvolvido por Antonio Agacy e Márcio Junior durante o Programa Institucional de Bolsas de Iniciação à Docência (PIBID)',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© ${DateTime.now().year} · v1.0.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}
