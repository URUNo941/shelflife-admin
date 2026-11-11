import 'package:flutter/material.dart';

import '../utils/expiry_status.dart';

class InventoryItemModel {
  final int itemId;
  final int userId;
  final String? barcode;
  final String productName;
  final String category;
  final int quantity;
  final DateTime expirationDate;
  final DateTime createdAt;
  final String status; // 'active', 'consumed', 'discarded'

  InventoryItemModel({
    required this.itemId,
    required this.userId,
    this.barcode,
    required this.productName,
    required this.category,
    required this.quantity,
    required this.expirationDate,
    required this.createdAt,
    required this.status,
  });

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryItemModel(
      itemId: json['item_id'],
      userId: json['user_id'],
      barcode: json['barcode'],
      productName: json['product_name'],
      category: json['category'] ?? 'General',
      quantity: json['quantity'] ?? 1,
      expirationDate: DateTime.parse(json['expiration_date']),
      createdAt: DateTime.parse(json['created_at']),
      status: json['status'] ?? 'active',
    );
  }

  double get remainingLifePercentage => ExpiryStatus.remainingPercentage(
        addedAt: createdAt,
        expiryDate: expirationDate,
      );

  Color get expiryColor => ExpiryStatus.color(
        addedAt: createdAt,
        expiryDate: expirationDate,
      );

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'user_id': userId,
      'barcode': barcode,
      'product_name': productName,
      'category': category,
      'quantity': quantity,
      'expiration_date': expirationDate.toIso8601String(),
      'status': status,
    };
  }
}
