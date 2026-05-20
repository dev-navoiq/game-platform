import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String coins(int amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return amount.toString();
  }

  static String gems(int amount) {
    return NumberFormat.compact().format(amount);
  }

  static String duration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String date(DateTime dateTime) {
    return DateFormat.yMMMd().format(dateTime);
  }

  static String time(DateTime dateTime) {
    return DateFormat.jm().format(dateTime);
  }

  static String price(double amount, {String currency = '\$'}) {
    return '$currency${amount.toStringAsFixed(2)}';
  }

  static String roomCode(String code) {
    return code.toUpperCase();
  }
}
