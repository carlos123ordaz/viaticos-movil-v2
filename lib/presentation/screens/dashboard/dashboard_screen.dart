import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/expense_model.dart';
import '../../providers/expense_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final provider = context.watch<ExpenseProvider>();
    final all = provider.allExpenses;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _DashHeader(expenses: all)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (provider.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 72),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (all.isEmpty)
                    _EmptyDash(c: c)
                  else ...[
                    const SizedBox(height: 20),
                    _StatsRow(expenses: all),
                    const SizedBox(height: 24),
                    _MonthlyChart(expenses: all),
                    const SizedBox(height: 24),
                    _CategoryBreakdown(expenses: all),
                    const SizedBox(height: 24),
                    _TypeBreakdown(expenses: all),
                    const SizedBox(height: 24),
                    _TopProviders(expenses: all),
                    const SizedBox(height: 24),
                    _RecentExpenses(expenses: all),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DashHeader extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _DashHeader({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final penMonth = expenses
        .where((e) =>
            e.date.month == now.month &&
            e.date.year == now.year &&
            e.currency == 'PEN')
        .fold(0.0, (s, e) => s + e.amount);
    final monthCount = expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .length;
    final fmt = NumberFormat('#,##0.00', 'es_PE');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, Color(0xFF5B83F0)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.32),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.6,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat('MMM yyyy', 'es').format(now),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'TOTAL ESTE MES (S/)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white60,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fmt.format(penMonth),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.5,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$monthCount ${monthCount == 1 ? 'gasto registrado' : 'gastos registrados'} este mes',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyDash extends StatelessWidget {
  final AppColors c;
  const _EmptyDash({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_chart_outlined_rounded, size: 64, color: c.muted2),
          const SizedBox(height: 18),
          Text('Sin datos aún',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 6),
          Text('Registra gastos para ver tus estadísticas',
              style: TextStyle(fontSize: 13, color: c.muted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── KPI stats row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _StatsRow({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final penExpenses =
        expenses.where((e) => e.currency == 'PEN').toList();
    final monthExpenses = expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .toList();
    final monthTotal =
        monthExpenses.fold(0.0, (s, e) => e.currency == 'PEN' ? s + e.amount : s);
    final avg = penExpenses.isEmpty
        ? 0.0
        : penExpenses.fold(0.0, (s, e) => s + e.amount) / penExpenses.length;
    final pending =
        expenses.where((e) => e.status == 'pending').length;

    final fmt = NumberFormat('#,##0.00', 'es_PE');
    final fmtShort = NumberFormat('#,##0', 'es_PE');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Resumen general'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Gastos este mes',
                value: monthExpenses.length.toString(),
                icon: Icons.receipt_long_rounded,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Pendientes',
                value: pending.toString(),
                icon: Icons.hourglass_top_rounded,
                color: AppTheme.warn,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Promedio por gasto',
                value: 'S/ ${fmtShort.format(avg)}',
                icon: Icons.trending_up_rounded,
                color: AppTheme.mint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Total acumulado',
                value: 'S/ ${fmtShort.format(monthTotal)}',
                icon: Icons.account_balance_wallet_rounded,
                color: AppTheme.violet,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: c.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: c.muted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ── Monthly bar chart ─────────────────────────────────────────────────────────

class _MonthlyChart extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _MonthlyChart({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final now = DateTime.now();

    // Build last 6 months data
    final months = List.generate(6, (i) {
      final m = DateTime(now.year, now.month - 5 + i, 1);
      return m;
    });

    final values = months.map((m) {
      return expenses
          .where((e) =>
              e.currency == 'PEN' &&
              e.date.month == m.month &&
              e.date.year == m.year)
          .fold(0.0, (s, e) => s + e.amount);
    }).toList();

    final labels =
        months.map((m) => DateFormat('MMM', 'es').format(m)).toList();

    return _SectionCard(
      title: 'Gasto mensual (S/)',
      child: SizedBox(
        height: 180,
        child: CustomPaint(
          painter: _BarChartPainter(
            values: values,
            labels: labels,
            barColor: AppTheme.primary,
            barColorFaded: AppTheme.primary.withOpacity(0.18),
            labelColor: c.muted,
            valueColor: c.ink,
            gridColor: c.line,
            highlightIndex: 5, // current month
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color barColor;
  final Color barColorFaded;
  final Color labelColor;
  final Color valueColor;
  final Color gridColor;
  final int highlightIndex;

  _BarChartPainter({
    required this.values,
    required this.labels,
    required this.barColor,
    required this.barColorFaded,
    required this.labelColor,
    required this.valueColor,
    required this.gridColor,
    required this.highlightIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = values.reduce(math.max);
    if (maxVal == 0) return;

    const bottomPad = 28.0;
    const topPad = 24.0;
    final chartH = size.height - bottomPad - topPad;
    final barW = (size.width - 16) / values.length * 0.55;
    final slotW = (size.width - 16) / values.length;

    // Grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = topPad + chartH - (chartH / 3 * i);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final fmt = NumberFormat.compactCurrency(
        locale: 'es_PE', symbol: '', decimalDigits: 0);

    for (int i = 0; i < values.length; i++) {
      final x = 8 + slotW * i + (slotW - barW) / 2;
      final pct = maxVal > 0 ? values[i] / maxVal : 0.0;
      final barH = chartH * pct;
      final y = topPad + chartH - barH;
      final isHighlight = i == highlightIndex;

      // Bar
      final barPaint = Paint()
        ..color = isHighlight ? barColor : barColorFaded
        ..style = PaintingStyle.fill;
      final rRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barW, barH),
        const Radius.circular(6),
      );
      canvas.drawRRect(rRect, barPaint);

      // Value label (only if bar is tall enough)
      if (values[i] > 0) {
        final valText = fmt.format(values[i]);
        final valSpan = TextSpan(
          text: valText,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: isHighlight ? barColor : labelColor,
          ),
        );
        final valTp = TextPainter(
            text: valSpan, textDirection: ui.TextDirection.ltr)
          ..layout();
        valTp.paint(
          canvas,
          Offset(x + barW / 2 - valTp.width / 2, y - valTp.height - 3),
        );
      }

      // Month label
      final labelSpan = TextSpan(
        text: labels[i],
        style: TextStyle(
          fontSize: 10,
          fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
          color: isHighlight ? barColor : labelColor,
        ),
      );
      final labelTp =
          TextPainter(text: labelSpan, textDirection: ui.TextDirection.ltr)
            ..layout();
      labelTp.paint(
        canvas,
        Offset(x + barW / 2 - labelTp.width / 2,
            topPad + chartH + 8),
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.values != values;
}

// ── Category donut ────────────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _CategoryBreakdown({required this.expenses});

  static const _catColors = [
    AppTheme.primary,
    AppTheme.mint,
    AppTheme.coral,
    AppTheme.violet,
    AppTheme.sky,
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final penExpenses =
        expenses.where((e) => e.currency == 'PEN').toList();
    final total = penExpenses.fold(0.0, (s, e) => s + e.amount);

    // Group by category
    final catMap = <ExpenseCategory, double>{};
    for (final e in penExpenses) {
      catMap[e.category] = (catMap[e.category] ?? 0) + e.amount;
    }
    final sorted = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final slices = sorted.asMap().entries.map((entry) {
      return _DonutSlice(
        color: _catColors[entry.key % _catColors.length],
        fraction: total > 0 ? entry.value.value / total : 0,
        label: entry.value.key.label,
        amount: entry.value.value,
      );
    }).toList();

    final fmt = NumberFormat('#,##0.00', 'es_PE');

    return _SectionCard(
      title: 'Por categoría (S/)',
      child: Row(
        children: [
          // Donut
          SizedBox(
            width: 130,
            height: 130,
            child: CustomPaint(
              painter: _DonutPainter(slices: slices),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sorted.length.toString(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      'categ.',
                      style: TextStyle(fontSize: 10, color: c.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: slices.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'S/ ${fmt.format(s.amount)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: s.color,
                            ),
                          ),
                          Text(
                            '${(s.fraction * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10,
                              color: c.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutSlice {
  final Color color;
  final double fraction;
  final String label;
  final double amount;
  const _DonutSlice(
      {required this.color,
      required this.fraction,
      required this.label,
      required this.amount});
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSlice> slices;
  _DonutPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const strokeW = 22.0;
    const gapAngle = 0.06;

    double startAngle = -math.pi / 2;

    for (final slice in slices) {
      if (slice.fraction <= 0) continue;
      final sweep =
          slice.fraction * 2 * math.pi - gapAngle;
      final paint = Paint()
        ..color = slice.color
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep + gapAngle;
    }

    // Background track
    if (slices.isEmpty) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.grey.withOpacity(0.15)
          ..strokeWidth = strokeW
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices;
}

// ── Type breakdown ────────────────────────────────────────────────────────────

class _TypeBreakdown extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _TypeBreakdown({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final viaticos =
        expenses.where((e) => e.type == 'viatico').toList();
    final compras =
        expenses.where((e) => e.type == 'compra').toList();
    final totalV =
        viaticos.fold(0.0, (s, e) => e.currency == 'PEN' ? s + e.amount : s);
    final totalC =
        compras.fold(0.0, (s, e) => e.currency == 'PEN' ? s + e.amount : s);
    final grand = totalV + totalC;

    final fmt = NumberFormat('#,##0.00', 'es_PE');

    return _SectionCard(
      title: 'Tipo de gasto (S/)',
      child: Column(
        children: [
          Row(
            children: [
              _TypePill(
                label: 'Viático',
                count: viaticos.length,
                amount: totalV,
                color: AppTheme.primary,
                fmt: fmt,
              ),
              const SizedBox(width: 12),
              _TypePill(
                label: 'Compra',
                count: compras.length,
                amount: totalC,
                color: AppTheme.coral,
                fmt: fmt,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LayoutBuilder(builder: (_, constraints) {
              final w = constraints.maxWidth;
              final vPct = grand > 0 ? totalV / grand : 0.5;
              return Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    width: w * vPct,
                    height: 12,
                    color: AppTheme.primary,
                  ),
                  Expanded(
                    child: Container(
                      height: 12,
                      color: AppTheme.coral,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                grand > 0
                    ? '${(totalV / grand * 100).toStringAsFixed(0)}% Viáticos'
                    : '—',
                style:
                    const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600),
              ),
              Text(
                grand > 0
                    ? '${(totalC / grand * 100).toStringAsFixed(0)}% Compras'
                    : '—',
                style:
                    const TextStyle(fontSize: 11, color: AppTheme.coral, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final int count;
  final double amount;
  final Color color;
  final NumberFormat fmt;
  const _TypePill(
      {required this.label,
      required this.count,
      required this.amount,
      required this.color,
      required this.fmt});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.4)),
            const SizedBox(height: 6),
            Text(
              'S/ ${fmt.format(amount)}',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: c.ink),
            ),
            Text(
              '$count ${count == 1 ? 'gasto' : 'gastos'}',
              style: TextStyle(fontSize: 11, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top providers ─────────────────────────────────────────────────────────────

class _TopProviders extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _TopProviders({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    // Group by businessName
    final map = <String, double>{};
    for (final e in expenses) {
      if (e.businessName != null &&
          e.businessName!.isNotEmpty &&
          e.currency == 'PEN') {
        map[e.businessName!] = (map[e.businessName!] ?? 0) + e.amount;
      }
    }
    if (map.isEmpty) return const SizedBox.shrink();

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final maxVal = top.first.value;
    final fmt = NumberFormat('#,##0.00', 'es_PE');

    return _SectionCard(
      title: 'Top proveedores (S/)',
      child: Column(
        children: top.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          const colors = [
            AppTheme.primary,
            AppTheme.mint,
            AppTheme.coral,
            AppTheme.violet,
            AppTheme.sky,
          ];
          final color = colors[i % colors.length];
          final pct = maxVal > 0 ? item.value / maxVal : 0.0;

          return Padding(
            padding:
                EdgeInsets.only(bottom: i < top.length - 1 ? 14 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.key,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'S/ ${fmt.format(item.value)}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: c.surfaceTinted,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Recent expenses ───────────────────────────────────────────────────────────

class _RecentExpenses extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _RecentExpenses({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final sorted = List<ExpenseModel>.from(expenses)
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent = sorted.take(5).toList();

    return _SectionCard(
      title: 'Últimos gastos',
      trailing: TextButton(
        onPressed: () => context.go('/home'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          foregroundColor: AppTheme.primary,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('Ver todos',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
      child: Column(
        children: recent.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final fmt = NumberFormat('#,##0.00', 'es_PE');
          final symbol = e.currency == 'USD'
              ? '\$'
              : e.currency == 'EUR'
                  ? '€'
                  : 'S/';
          return InkWell(
            onTap: () => context.push('/expense/${e.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  EdgeInsets.only(bottom: i < recent.length - 1 ? 12 : 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _catColor(e.category).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_catIcon(e.category),
                        size: 18, color: _catColor(e.category)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.description.isNotEmpty
                              ? e.description
                              : e.category.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat('dd MMM yyyy', 'es').format(e.date),
                          style: TextStyle(fontSize: 11, color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$symbol ${fmt.format(e.amount)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _catColor(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.alimentacion:
        return AppTheme.coral;
      case ExpenseCategory.transporte:
        return AppTheme.sky;
      case ExpenseCategory.alojamiento:
        return AppTheme.violet;
      case ExpenseCategory.compras:
        return AppTheme.mint;
      case ExpenseCategory.otros:
        return AppTheme.warn;
    }
  }

  IconData _catIcon(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.alimentacion:
        return Icons.restaurant_rounded;
      case ExpenseCategory.transporte:
        return Icons.directions_car_rounded;
      case ExpenseCategory.alojamiento:
        return Icons.hotel_rounded;
      case ExpenseCategory.compras:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.otros:
        return Icons.receipt_rounded;
    }
  }
}

// ── Shared layout widgets ─────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: context.appColors.ink,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard(
      {required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                  letterSpacing: -0.2,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
