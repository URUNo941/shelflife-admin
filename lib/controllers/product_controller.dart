import 'package:flutter/foundation.dart';

import '../models/mock_data.dart';
import '../models/product_model.dart';

/// Controller จัดการ Master Barcode Catalog เก็บข้อมูลในหน่วยความจำ
class ProductController extends ChangeNotifier {
  ProductController({List<ProductModel>? seed})
      : _seed = seed,
        _products = [...(seed ?? MockData.globalProducts())] {
    _nextId = _computeNextId();
  }

  static final ProductController instance = ProductController();

  static const sortOptions = ['Barcode', 'Name', 'Category'];

  final List<ProductModel>? _seed;
  final List<ProductModel> _products;
  late int _nextId;

  List<ProductModel> get products => List.unmodifiable(_products);

  int _computeNextId() =>
      _products.fold(0, (m, p) => p.productId > m ? p.productId : m) + 1;

  /// หมวดหมู่ที่มีอยู่ เรียงตามตัวอักษร
  List<String> get categories =>
      (_products.map((p) => p.category).toSet().toList()..sort());

  int countInCategory(String category) => category == 'All'
      ? _products.length
      : _products.where((p) => p.category == category).length;

  ProductModel? findByBarcode(String barcode) {
    final code = barcode.trim();
    for (final product in _products) {
      if (product.barcode == code) return product;
    }
    return null;
  }

  bool barcodeExists(String barcode, {int? excludingId}) {
    final code = barcode.trim();
    return _products
        .any((p) => p.barcode == code && p.productId != excludingId);
  }

  /// ค้นหาด้วย barcode หรือชื่อ, กรองหมวดหมู่ และเรียงลำดับ
  List<ProductModel> search({
    String query = '',
    String category = 'All',
    String sortBy = 'Barcode',
  }) {
    final q = query.trim().toLowerCase();
    final result = _products.where((p) {
      final matchesSearch = p.barcode.toLowerCase().contains(q) ||
          p.productName.toLowerCase().contains(q);
      final matchesCategory = category == 'All' || p.category == category;
      return matchesSearch && matchesCategory;
    }).toList();
    String keyOf(ProductModel p) => switch (sortBy) {
          'Name' => p.productName.toLowerCase(),
          'Category' => p.category.toLowerCase(),
          _ => p.barcode,
        };
    result.sort((a, b) => keyOf(a).compareTo(keyOf(b)));
    return result;
  }

  String? _validate(String barcode, String productName, {int? excludingId}) {
    final code = barcode.trim();
    if (code.isEmpty) return 'Please enter barcode number';
    if (!RegExp(r'^\d+$').hasMatch(code)) {
      return 'Barcode must contain numbers only';
    }
    if (barcodeExists(code, excludingId: excludingId)) {
      return 'This barcode already exists';
    }
    if (productName.trim().isEmpty) return 'Please enter product name';
    return null;
  }

  /// เพิ่มสินค้า คืน error หรือ null ถ้าสำเร็จ
  String? add({
    required String barcode,
    required String productName,
    String category = 'General',
    int? createdBy,
  }) {
    final error = _validate(barcode, productName);
    if (error != null) return error;
    _products.add(ProductModel(
      productId: _nextId++,
      barcode: barcode.trim(),
      productName: productName.trim(),
      category: category,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
    return null;
  }

  /// แก้ไขสินค้า คืน error หรือ null ถ้าสำเร็จ
  String? update(
    int productId, {
    required String barcode,
    required String productName,
    required String category,
  }) {
    final index = _products.indexWhere((p) => p.productId == productId);
    if (index < 0) return 'Product not found';
    final error = _validate(barcode, productName, excludingId: productId);
    if (error != null) return error;
    _products[index] = _products[index].copyWith(
      barcode: barcode.trim(),
      productName: productName.trim(),
      category: category,
    );
    notifyListeners();
    return null;
  }

  bool delete(int productId) {
    final before = _products.length;
    _products.removeWhere((p) => p.productId == productId);
    final removed = _products.length != before;
    if (removed) notifyListeners();
    return removed;
  }

  void reset() {
    _products
      ..clear()
      ..addAll(_seed ?? MockData.globalProducts());
    _nextId = _computeNextId();
    notifyListeners();
  }
}
