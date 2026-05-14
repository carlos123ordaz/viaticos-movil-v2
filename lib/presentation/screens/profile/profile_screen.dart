import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          // Header con avatar
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            title: const Text('Mi Perfil',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                onPressed: () => context.push('/change-password'),
                icon: const Icon(Icons.key_rounded, color: Colors.white),
                tooltip: 'Cambiar contraseña',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _ProfileHeader(user: user),
            ),
          ),
          if (user != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Estadísticas
                    _StatsRow(),
                    const SizedBox(height: 24),
                    // Info personal
                    Text('Información personal',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          _InfoTile(
                            icon: Icons.person_outline_rounded,
                            label: 'Nombre',
                            value: user.name,
                          ),
                          const Divider(height: 1, indent: 56),
                          _InfoTile(
                            icon: Icons.email_outlined,
                            label: 'Correo',
                            value: user.email,
                          ),
                          if (user.dni != null) ...[
                            const Divider(height: 1, indent: 56),
                            _InfoTile(
                              icon: Icons.badge_outlined,
                              label: 'DNI',
                              value: user.dni!,
                            ),
                          ],
                          if (user.phone != null) ...[
                            const Divider(height: 1, indent: 56),
                            _InfoTile(
                              icon: Icons.phone_outlined,
                              label: 'Teléfono',
                              value: user.phone!,
                            ),
                          ],
                          if (user.jobTitle != null) ...[
                            const Divider(height: 1, indent: 56),
                            _InfoTile(
                              icon: Icons.work_outline_rounded,
                              label: 'Cargo',
                              value: user.jobTitle!,
                            ),
                          ],
                          if (user.area != null) ...[
                            const Divider(height: 1, indent: 56),
                            _InfoTile(
                              icon: Icons.business_outlined,
                              label: 'Área',
                              value: user.area!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Acciones
                    Text('Cuenta',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.draw_outlined),
                            title: const Text('Firma digital'),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                                size: 16),
                            onTap: () => context.push('/signature'),
                          ),
                          const Divider(height: 1, indent: 56),
                          ListTile(
                            leading: const Icon(Icons.key_rounded),
                            title: const Text('Cambiar contraseña'),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                                size: 16),
                            onTap: () => context.push('/change-password'),
                          ),
                          const Divider(height: 1, indent: 56),
                          ListTile(
                            leading: const Icon(Icons.sync_rounded),
                            title: const Text('Sincronizar datos'),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                                size: 16),
                            onTap: () => context.read<AuthProvider>().refreshUser(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Cerrar sesión
                    OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: Icon(Icons.logout_rounded,
                          color: colors.error),
                      label: Text('Cerrar sesión',
                          style: TextStyle(color: colors.error)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.error),
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) context.go('/login');
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  final dynamic user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          if (user?.avatarUrl != null)
            CircleAvatar(
              radius: 44,
              backgroundImage: NetworkImage(user!.avatarUrl!),
            )
          else
            CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                user != null ? Formatters.initials(user!.name) : '?',
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            user?.name ?? '',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
          if (user?.jobTitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                user!.jobTitle!,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8)),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.receipt_long_rounded,
            value: provider.expenses.length.toString(),
            label: 'Total gastos',
            color: colors.primary,
            background: colors.primaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_month_rounded,
            value: Formatters.currency(provider.monthAmount),
            label: 'Este mes',
            color: const Color(0xFF059669),
            background: const Color(0xFFD1FAE5),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color background;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colors.outline, size: 22),
      title: Text(label,
          style: TextStyle(fontSize: 12, color: colors.outline)),
      subtitle: Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15)),
    );
  }
}
