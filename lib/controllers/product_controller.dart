import 'package:flutter/foundation.dart';

import '../models/mock_data.dart';
import '../models/product_model.dart';
import '../services/api_client.dart';

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

  // ---------------------------------------------------------------------------
  // เวอร์ชัน async ที่หน้าจอเรียก: ถ้าเปิด API จะไปที่ /api/products
  // ---------------------------------------------------------------------------
  ApiClient get _api => ApiClient.instance;
  bool get _online => _api.enabled;

  Future<String?> load() async {
    if (!_online) return null;
    try {
      final rows = await _api.get('/products') as List;
      _products
        ..clear()
        ..addAll(rows.map((r) => ProductModel.fromJson(r as Map<String, dynamic>)));
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Smart Barcode Auto-Fill: หาสินค้าจากบาร์โค้ด (GET /api/products/master/:barcode)
  Future<ProductModel?> lookup(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    if (!_online) return findByBarcode(code);
    try {
      final row = await _api.get('/products/master/${Uri.encodeComponent(code)}');
      return ProductModel.fromJson(row as Map<String, dynamic>);
    } on ApiException {
      return null; // 404 = ยังไม่มีในแคตตาล็อก ผู้ใช้กรอกเองได้
    }
  }

  Future<String?> create({
    required String barcode,
    required String productName,
    String category = 'General',
    int? createdBy,
  }) async {
    if (!_online) {
      return add(
          barcode: barcode,
          productName: productName,
          category: category,
          createdBy: createdBy);
    }
    final error = _validate(barcode, productName);
    if (error != null) return error;
    try {
      final row = await _api.post('/products', {
        'barcode': barcode.trim(),
        'product_name': productName.trim(),
        'category': category,
      });
      _products.add(ProductModel.fromJson(row as Map<String, dynamic>));
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> edit(
    int productId, {
    required String barcode,
    required String productName,
    required String category,
  }) async {
    if (!_online) {
      return update(productId,
          barcode: barcode, productName: productName, category: category);
    }
    final error = _validate(barcode, productName, excludingId: productId);
    if (error != null) return error;
    try {
      final row = await _api.put('/products/$productId', {
        'barcode': barcode.trim(),
        'product_name': productName.trim(),
        'category': category,
      });
      final index = _products.indexWhere((p) => p.productId == productId);
      if (index >= 0) {
        _products[index] = ProductModel.fromJson(row as Map<String, dynamic>);
      }
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// คืน null ถ้าลบสำเร็จ หรือข้อความ error (เช่น สินค้ายังมีคนเก็บไว้ในตู้)
  Future<String?> remove(int productId) async {
    if (!_online) return delete(productId) ? null : 'Product not found';
    try {
      await _api.delete('/products/$productId');
      _products.removeWhere((p) => p.productId == productId);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.statusCode == 409
          ? 'This product is still in someone\'s inventory, so it cannot be deleted.'
          : e.message;
    }
  }

  void clearCache() {
    _products.clear();
    notifyListeners();
  }

  void reset() {
    _products
      ..clear()
      ..addAll(_seed ?? MockData.globalProducts());
    _nextId = _computeNextId();
    notifyListeners();
  }
}
