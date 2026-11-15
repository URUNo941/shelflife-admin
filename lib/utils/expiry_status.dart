import 'package:flutter/material.dart';

class ExpiryStatus {
  static const green = Color(0xFF10B981);
  static const yellow = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);

  static double remainingPercentage({
    required DateTime addedAt,
    required DateTime expiryDate,
    DateTime? today,
  }) {
    DateTime dateOnly(DateTime date) =>
        DateTime(date.year, date.month, date.day);

    final start = dateOnly(addedAt);
    final expiry = dateOnly(expiryDate);
    final current = dateOnly(today ?? DateTime.now());
    final totalDays = expiry.difference(start).inDays;
    final daysLeft = expiry.difference(current).inDays;

    if (totalDays <= 0 || daysLeft <= 0) return 0;
    return (daysLeft * 100 / totalDays).clamp(0, 100).toDouble();
  }

  static Color color({
    required DateTime addedAt,
    required DateTime expiryDate,
    DateTime? today,
  }) {
    DateTime dateOnly(DateTime date) =>
        DateTime(date.year, date.month, date.day);

    final current = dateOnly(today ?? DateTime.now());
    final expiry = dateOnly(expiryDate);
    final daysLeft = expiry.difference(current).inDays;
    if (daysLeft <= 0) return red;
    if (daysLeft == 1) return yellow;

    final percentage = remainingPercentage(
      addedAt: addedAt,
      expiryDate: expiryDate,
      today: current,
    );
    if (percentage >= 30) return green;
    if (percentage >= 10) return yellow;
    return red;
  }
}
