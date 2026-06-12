import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double value) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }
}
