class InventoryItemModel {
  final int itemId;
  final int userId;
  final String? barcode;
  final String productName;
  final String category;
  final int quantity;
  final DateTime expirationDate;
  final String status; // 'active', 'consumed', 'discarded'

  InventoryItemModel({
    required this.itemId,
    required this.userId,
    this.barcode,
    required this.productName,
    required this.category,
    required this.quantity,
    required this.expirationDate,
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
      status: json['status'] ?? 'active',
    );
  }

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