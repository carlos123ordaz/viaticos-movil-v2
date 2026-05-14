import 'package:intl/intl.dart';

class Formatters {
  static String currency(double amount, {String currency = 'PEN'}) {
    final symbol = currency == 'USD' ? '\$' : 'S/';
    final formatter = NumberFormat('#,##0.00', 'es_PE');
    return '$symbol ${formatter.format(amount)}';
  }

  static String date(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'es_PE').format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm', 'es_PE').format(date);
  }

  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return DateFormat('dd MMM', 'es_PE').format(date);
  }

  static String initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
