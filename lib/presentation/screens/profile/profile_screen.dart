import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        slivers: [
          // ── Gradient hero header ──────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text(
              'Mi Perfil',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => context.push('/change-password'),
                icon: const Icon(Icons.key_rounded, color: Colors.white),
                tooltip: 'Cambiar contraseña',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _ProfileHero(user: user),
            ),
          ),

          if (user != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Personal info ──────────────────────
                    _SectionLabel('Información personal'),
                    const SizedBox(height: 10),
                    _InfoCard(children: [
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Nombre',
                        value: user.name,
                      ),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Correo',
                        value: user.email,
                      ),
                      if (user.dni != null)
                        _InfoRow(
                          icon: Icons.badge_outlined,
                          label: 'DNI',
                          value: user.dni!,
                          isMono: true,
                        ),
                      if (user.phone != null)
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Teléfono',
                          value: user.phone!,
                        ),
                      if (user.jobTitle != null)
                        _InfoRow(
                          icon: Icons.work_outline_rounded,
                          label: 'Cargo',
                          value: user.jobTitle!,
                        ),
                      if (user.area != null)
                        _InfoRow(
                          icon: Icons.business_outlined,
                          label: 'Área',
                          value: user.area!,
                          last: true,
                        ),
                    ]),

                    const SizedBox(height: 24),

                    // ── Account actions ────────────────────
                    _SectionLabel('Cuenta'),
                    const SizedBox(height: 10),
                    _InfoCard(children: [
                      _MenuRow(
                        icon: Icons.draw_outlined,
                        iconColor: AppTheme.violet,
                        iconBg: AppTheme.violetTint,
                        label: 'Firma digital',
                        onTap: () => context.push('/signature'),
                      ),
                      _MenuRow(
                        icon: Icons.key_rounded,
                        iconColor: AppTheme.primary,
                        iconBg: AppTheme.primaryContainer,
                        label: 'Cambiar contraseña',
                        onTap: () => context.push('/change-password'),
                      ),
                      _DarkModeRow(),
                      _MenuRow(
                        icon: Icons.sync_rounded,
                        iconColor: AppTheme.secondary,
                        iconBg: AppTheme.secondaryContainer,
                        label: 'Sincronizar datos',
                        onTap: () => context.read<AuthProvider>().refreshUser(),
                        last: true,
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── Logout button ──────────────────────
                    GestureDetector(
                      onTap: () => _confirmLogout(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.errorContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, color: AppTheme.error, size: 18),
                            SizedBox(width: 10),
                            Text(
                              'Cerrar sesión',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'AppViáticos v 1.0.0',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          color: AppTheme.muted2,
                        ),
                      ),
                    ),
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
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
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

// ── Hero header ───────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  final dynamic user;
  const _ProfileHero({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B5BFF), Color(0xFF2F49D9)],
        ),
      ),
      child: Stack(
        children: [
          // Deco circle
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x2EFFD66B),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -40,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x4D7FB3FF),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      if (user?.avatarUrl != null)
                        CircleAvatar(
                          radius: 36,
                          backgroundImage: NetworkImage(user!.avatarUrl!),
                        )
                      else
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            user != null ? Formatters.initials(user!.name) : '?',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppTheme.yellow,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primaryDark, width: 3),
                          ),
                          child: const Icon(Icons.edit_rounded, size: 11, color: AppTheme.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user?.name ?? '',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (user?.jobTitle != null)
                          Text(
                            user!.jobTitle!,
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (user?.area != null)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: const BoxDecoration(color: AppTheme.yellow, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  user!.area!,
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: context.appColors.muted,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ── Info Card (container for rows) ───────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;
  final bool isMono;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
    this.isMono = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.muted2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: isMono ? 'monospace' : 'Plus Jakarta Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
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

// ── Dark mode toggle row ──────────────────────────────────────────────────────

class _DarkModeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2D5A) : c.surfaceTinted,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 18,
              color: isDark ? AppTheme.primary : c.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isDark ? 'Modo oscuro' : 'Modo claro',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ),
          Switch(
            value: isDark,
            onChanged: (_) => themeProvider.toggle(),
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

// ── Menu row ──────────────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool last;

  const _MenuRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        color: c.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.muted2),
          ],
        ),
      ),
    );
  }
}
