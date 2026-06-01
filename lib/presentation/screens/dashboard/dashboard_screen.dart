import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/expense_model.dart';
import '../../providers/expense_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _currency = 'PEN';

  static String _symbol(String? currency) {
    switch (currency) {
      case 'USD': return '\$';
      case 'EUR': return '€';
      default: return 'S/';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final provider = context.watch<ExpenseProvider>();
    final all = provider.allExpenses;

    // Gastos filtrados por moneda seleccionada
    final filtered = all.where((e) => e.currency == _currency).toList();

    final sym = _symbol(_currency);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _DashHeader(expenses: filtered, currencySymbol: sym)),
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
                    const SizedBox(height: 16),
                    // ── Estadísticas de moneda ────────────────────────────
                    _CurrencyStats(
                      allExpenses: all,
                      selected: _currency,
                      onChanged: (v) => setState(() => _currency = v),
                    ),

                    const SizedBox(height: 16),
                    _StatsRow(expenses: filtered, currencySymbol: sym),
                    const SizedBox(height: 24),
                    _MonthlyChart(expenses: filtered),
                    const SizedBox(height: 24),
                    _CategoryBreakdown(expenses: filtered, currencySymbol: sym),
                    const SizedBox(height: 24),
                    _TypeBreakdown(expenses: filtered, currencySymbol: sym),
                    const SizedBox(height: 24),
                    _TopProviders(expenses: filtered, currencySymbol: sym),
                    const SizedBox(height: 24),
                    _ReceiptTypeBreakdown(expenses: filtered, currencySymbol: sym),
                    const SizedBox(height: 24),
                    _CostCenterBreakdown(expenses: filtered, currencySymbol: sym),
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

// ── Currency stats cards ──────────────────────────────────────────────────────

class _CurrencyStats extends StatelessWidget {
  final List<ExpenseModel> allExpenses;
  final String selected;
  final ValueChanged<String> onChanged;

  const _CurrencyStats({
    required this.allExpenses,
    required this.selected,
    required this.onChanged,
  });

  static const _currencyMeta = {
    'PEN': (label: 'Soles',   symbol: 'S/',  color: AppTheme.primary),
    'USD': (label: 'Dólares', symbol: '\$',   color: AppTheme.mint),
    'EUR': (label: 'Euros',   symbol: '€',    color: AppTheme.violet),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final fmt = NumberFormat('#,##0.00', 'es_PE');

    // Always show all 3 currencies, filling with zeros when no data
    final map = <String, _CurrencyStat>{};
    for (final cur in _currencyMeta.keys) {
      map[cur] = _CurrencyStat(currency: cur, total: 0, count: 0);
    }
    for (final e in allExpenses) {
      final cur = e.currency;
      final prev = map[cur] ?? _CurrencyStat(currency: cur, total: 0, count: 0);
      map[cur] = _CurrencyStat(currency: cur, total: prev.total + e.amount, count: prev.count + 1);
    }

    // Fixed order: PEN, USD, EUR
    final stats = _currencyMeta.keys.map((k) => map[k]!).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Moneda',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.ink)),
        const SizedBox(height: 10),
        Row(
          children: stats.asMap().entries.map((entry) {
            final i = entry.key;
            final stat = entry.value;
            final isSelected = stat.currency == selected;
            final meta = _currencyMeta[stat.currency]!;
            final color = meta.color;
            final symbol = meta.symbol;
            final label = meta.label;
            final isEmpty = stat.count == 0;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < stats.length - 1 ? 10 : 0),
                child: GestureDetector(
                  onTap: isSelected ? null : () => onChanged(stat.currency),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color
                          : isEmpty
                              ? c.surfaceTinted
                              : c.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isEmpty
                            ? c.line
                            : isSelected
                                ? color
                                : color.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                          : isEmpty
                              ? []
                              : AppTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(symbol,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? Colors.white70 : isEmpty ? c.muted2 : color,
                                )),
                            const SizedBox(width: 4),
                            Text(stat.currency,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white60 : c.muted,
                                )),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : isEmpty
                                        ? c.line
                                        : color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('${stat.count}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : isEmpty ? c.muted : color,
                                  )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isEmpty ? '—' : fmt.format(stat.total),
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : isEmpty ? c.muted2 : c.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white70 : c.muted,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CurrencyStat {
  final String currency;
  final double total;
  final int count;
  const _CurrencyStat({required this.currency, required this.total, required this.count});
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DashHeader extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final String currencySymbol;
  const _DashHeader({required this.expenses, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthTotal = expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
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
          Text(
            'TOTAL ESTE MES ($currencySymbol)',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white60,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fmt.format(monthTotal),
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
            '$monthCount ${monthCount == 1 ? 'rendición registrada' : 'rendiciones registradas'} este mes',
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
          Text('Registra rendiciones para ver tus estadísticas',
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
  final String currencySymbol;
  const _StatsRow({required this.expenses, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthExpenses = expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .toList();
    final monthTotal = monthExpenses.fold(0.0, (s, e) => s + e.amount);
    final avg = expenses.isEmpty ? 0.0 : expenses.fold(0.0, (s, e) => s + e.amount) / expenses.length;
    final pending = expenses.where((e) => e.status == 'pending').length;
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
                label: 'Rendiciones este mes',
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
                label: 'Promedio por rendición',
                value: '$currencySymbol ${fmtShort.format(avg)}',
                icon: Icons.trending_up_rounded,
                color: AppTheme.mint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Total acumulado',
                value: '$currencySymbol ${fmtShort.format(monthTotal)}',
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
              e.date.month == m.month &&
              e.date.year == m.year)
          .fold(0.0, (s, e) => s + e.amount);
    }).toList();

    final labels =
        months.map((m) => DateFormat('MMM', 'es').format(m)).toList();

    return _SectionCard(
      title: 'Rendición mensual (S/)',
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
  final String currencySymbol;
  const _CategoryBreakdown({required this.expenses, required this.currencySymbol});

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
    final total = expenses.fold(0.0, (s, e) => s + e.amount);

    // Group by category
    final catMap = <ExpenseCategory, double>{};
    for (final e in expenses) {
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
      title: 'Por categoría ($currencySymbol)',
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
                            '$currencySymbol ${fmt.format(s.amount)}',
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
  final String currencySymbol;
  const _TypeBreakdown({required this.expenses, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final viaticos = expenses.where((e) => e.type == 'viatico').toList();
    final compras = expenses.where((e) => e.type == 'compra').toList();
    final totalV = viaticos.fold(0.0, (s, e) => s + e.amount);
    final totalC = compras.fold(0.0, (s, e) => s + e.amount);
    final grand = totalV + totalC;

    final fmt = NumberFormat('#,##0.00', 'es_PE');

    return _SectionCard(
      title: 'Tipo de rendición ($currencySymbol)',
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
                currencySymbol: currencySymbol,
              ),
              const SizedBox(width: 12),
              _TypePill(
                label: 'Compra',
                count: compras.length,
                amount: totalC,
                color: AppTheme.coral,
                fmt: fmt,
                currencySymbol: currencySymbol,
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
  final String currencySymbol;
  const _TypePill(
      {required this.label,
      required this.count,
      required this.amount,
      required this.color,
      required this.fmt,
      required this.currencySymbol});

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
              '$currencySymbol ${fmt.format(amount)}',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: c.ink),
            ),
            Text(
              '$count ${count == 1 ? 'rendición' : 'rendiciones'}',
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
  final String currencySymbol;
  const _TopProviders({required this.expenses, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    // Group by businessName
    final map = <String, double>{};
    for (final e in expenses) {
      if (e.businessName != null && e.businessName!.isNotEmpty) {
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
                      '$currencySymbol ${fmt.format(item.value)}',
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

// ── Receipt type breakdown ────────────────────────────────────────────────────

class _ReceiptTypeBreakdown extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final String currencySymbol;
  const _ReceiptTypeBreakdown({required this.expenses, required this.currencySymbol});

  static const _colors = [
    AppTheme.primary,
    AppTheme.mint,
    AppTheme.coral,
    AppTheme.violet,
    AppTheme.sky,
    AppTheme.warn,
  ];

  static String _label(String? raw) {
    if (raw == null || raw.isEmpty) return 'Sin sustento';
    final v = raw.toLowerCase();
    if (v.contains('factura')) return 'Factura';
    if (v.contains('boleta')) return 'Boleta';
    if (v.contains('ticket')) return 'Ticket';
    if (v.contains('recibo')) return 'Recibo';
    if (v.contains('nota')) return 'Nota de venta';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final total = expenses.fold(0.0, (s, e) => s + e.amount);

    final map = <String, _ReceiptStat>{};
    for (final e in expenses) {
      final key = _label(e.receiptDetail);
      final prev = map[key] ?? _ReceiptStat(label: key, amount: 0, count: 0);
      map[key] = _ReceiptStat(label: key, amount: prev.amount + e.amount, count: prev.count + 1);
    }
    if (map.isEmpty) return const SizedBox.shrink();

    final sorted = map.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
    final maxVal = sorted.first.amount;
    final fmt = NumberFormat('#,##0.00', 'es_PE');

    final slices = sorted.asMap().entries.map((entry) => _DonutSlice(
      color: _colors[entry.key % _colors.length],
      fraction: total > 0 ? entry.value.amount / total : 0,
      label: entry.value.label,
      amount: entry.value.amount,
    )).toList();

    return _SectionCard(
      title: 'Tipo de sustento ($currencySymbol)',
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _DonutPainter(slices: slices),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(sorted.length.toString(),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.ink)),
                        Text('tipos', style: TextStyle(fontSize: 10, color: c.muted)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sorted.asMap().entries.map((entry) {
                    final i = entry.key;
                    final stat = entry.value;
                    final color = _colors[i % _colors.length];
                    final pct = maxVal > 0 ? stat.amount / maxVal : 0.0;
                    return Padding(
                      padding: EdgeInsets.only(bottom: i < sorted.length - 1 ? 10 : 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(width: 8, height: 8,
                                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(stat.label,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.ink),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Text('${stat.count}',
                                  style: TextStyle(fontSize: 10, color: c.muted)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 5,
                                    backgroundColor: c.surfaceTinted,
                                    color: color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('$currencySymbol ${fmt.format(stat.amount)}',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
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
        ],
      ),
    );
  }
}

class _ReceiptStat {
  final String label;
  final double amount;
  final int count;
  const _ReceiptStat({required this.label, required this.amount, required this.count});
}

// ── Cost center breakdown ─────────────────────────────────────────────────────

class _CostCenterBreakdown extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final String currencySymbol;
  const _CostCenterBreakdown({required this.expenses, required this.currencySymbol});

  static const _colors = [
    AppTheme.violet,
    AppTheme.sky,
    AppTheme.mint,
    AppTheme.coral,
    AppTheme.primary,
    AppTheme.warn,
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final fmt = NumberFormat('#,##0.00', 'es_PE');

    // Build map: costCenterName → weighted amount (amount * percentage / 100)
    final map = <String, double>{};
    for (final e in expenses) {
      for (final alloc in e.costCenterAllocations) {
        final name = alloc.costCenterName ?? alloc.subCostCenterName ?? 'Sin asignar';
        if (name.isEmpty) continue;
        final allocated = e.amount * alloc.percentage / 100;
        map[name] = (map[name] ?? 0) + allocated;
      }
    }
    if (map.isEmpty) return const SizedBox.shrink();

    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    final maxVal = top.first.value;

    return _SectionCard(
      title: 'Centro de costo ($currencySymbol)',
      child: Column(
        children: top.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final color = _colors[i % _colors.length];
          final pct = maxVal > 0 ? item.value / maxVal : 0.0;

          return Padding(
            padding: EdgeInsets.only(bottom: i < top.length - 1 ? 14 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.key,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$currencySymbol ${fmt.format(item.value)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 7,
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
