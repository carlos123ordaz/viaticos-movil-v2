import 'package:flutter/material.dart';
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
      CategoryConfig(Icons.restaurant_rounded, Color(0xFFD97706), Color(0xFFFEF3C7)),
  ExpenseCategory.transporte:
      CategoryConfig(Icons.directions_car_rounded, Color(0xFF2563EB), Color(0xFFDBEAFE)),
  ExpenseCategory.alojamiento:
      CategoryConfig(Icons.hotel_rounded, Color(0xFF7C3AED), Color(0xFFEDE9FE)),
  ExpenseCategory.compras:
      CategoryConfig(Icons.shopping_bag_rounded, Color(0xFFDB2777), Color(0xFFFCE7F3)),
  ExpenseCategory.otros:
      CategoryConfig(Icons.receipt_rounded, Color(0xFF059669), Color(0xFFD1FAE5)),
};

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
    final config =
        _categoryConfigs[expense.category] ?? _categoryConfigs[ExpenseCategory.otros]!;

    final card = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: config.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(config.icon, color: config.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: config.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          expense.category.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: config.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Formatters.relativeDate(expense.date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Formatters.currency(expense.amount, currency: expense.currency),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );

    if (onDelete == null) {
      return Card(child: card);
    }

    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar gasto'),
            content: Text(
                '¿Eliminar "${expense.description}"? Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error),
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
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_rounded,
            color: Theme.of(context).colorScheme.error),
      ),
      child: Card(child: card),
    );
  }
}
