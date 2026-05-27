import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/expense_model.dart';

class CategoryConfig {
  final IconData icon;
  final Color color;
  final Color background;

  const CategoryConfig(this.icon, this.color, this.background);
}

const _categoryConfigs = {
  ExpenseCategory.alimentacion:
      CategoryConfig(Icons.restaurant_rounded, AppTheme.coral, AppTheme.coralTint),
  ExpenseCategory.transporte:
      CategoryConfig(Icons.directions_car_rounded, AppTheme.sky, AppTheme.skyTint),
  ExpenseCategory.alojamiento:
      CategoryConfig(Icons.hotel_rounded, AppTheme.violet, AppTheme.violetTint),
  ExpenseCategory.compras:
      CategoryConfig(Icons.shopping_bag_rounded, AppTheme.mint, AppTheme.mintTint),
  ExpenseCategory.otros:
      CategoryConfig(Icons.receipt_rounded, AppTheme.primary, AppTheme.primaryContainer),
};

Color getCategoryColor(ExpenseCategory cat) =>
    _categoryConfigs[cat]?.color ?? AppTheme.primary;

Color getCategoryBg(ExpenseCategory cat) =>
    _categoryConfigs[cat]?.background ?? AppTheme.primaryContainer;

IconData getCategoryIcon(ExpenseCategory cat) =>
    _categoryConfigs[cat]?.icon ?? Icons.receipt_rounded;

class ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExpenseCard({
    super.key,
    required this.expense,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final config = _categoryConfigs[expense.category] ?? _categoryConfigs[ExpenseCategory.otros]!;
    final c = context.appColors;

    final card = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: config.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(config.icon, color: config.color, size: 22),
            ),
            const SizedBox(width: 14),
            // Description + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: config.background,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          expense.category.label,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: config.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.muted2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Formatters.relativeDate(expense.date),
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Amount
            Text(
              Formatters.currency(expense.amount, currency: expense.currency),
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: c.ink,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );

    final styledCard = Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: card,
      ),
    );

    if (onDelete == null) return styledCard;

    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar gasto'),
            content: Text('¿Eliminar "${expense.description}"? Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: AppTheme.error),
      ),
      child: styledCard,
    );
  }
}
