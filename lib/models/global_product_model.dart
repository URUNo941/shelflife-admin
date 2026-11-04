class GlobalProductModel {
  const GlobalProductModel({
    required this.productId,
    required this.barcode,
    required this.productName,
    required this.category,
    this.createdBy,
    this.createdAt,
  });

  final int productId;
  final String barcode;
  final String productName;
  final String category;
  final int? createdBy;
  final DateTime? createdAt;

  factory GlobalProductModel.fromJson(Map<String, dynamic> json) {
    return GlobalProductModel(
      productId: int.parse(json['product_id'].toString()),
      barcode: json['barcode'] as String,
      productName: json['product_name'] as String,
      category: json['category'] as String? ?? 'General',
      createdBy: json['created_by'] == null
          ? null
          : int.parse(json['created_by'].toString()),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'].toString()),
    );
  }
}
