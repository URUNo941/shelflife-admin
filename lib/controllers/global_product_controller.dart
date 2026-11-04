import 'api_client.dart';
import '../models/global_product_model.dart';

class GlobalProductController {
  GlobalProductController({ApiClient apiClient = const ApiClient()})
      : _api = apiClient;

  final ApiClient _api;

  Future<List<GlobalProductModel>> getProducts() async {
    final response = await _api.get('/products');
    _api.expectStatus(response, 200);
    final data = _api.decode(response) as List<dynamic>;
    return data
        .map((json) => GlobalProductModel.fromJson(
              Map<String, dynamic>.from(json as Map),
            ))
        .toList();
  }

  Future<GlobalProductModel> getProduct(int productId) async {
    final response = await _api.get('/products/$productId');
    _api.expectStatus(response, 200);
    return GlobalProductModel.fromJson(
      Map<String, dynamic>.from(_api.decode(response) as Map),
    );
  }

  Future<GlobalProductModel> getProductByBarcode(String barcode) async {
    final response = await _api.get(
      '/products/master/${Uri.encodeComponent(barcode)}',
    );
    _api.expectStatus(response, 200);
    return GlobalProductModel.fromJson(
      Map<String, dynamic>.from(_api.decode(response) as Map),
    );
  }

  Future<GlobalProductModel> addProduct({
    required String barcode,
    required String productName,
    String category = 'General',
    int? createdBy,
  }) async {
    final response = await _api.post('/products', {
      'barcode': barcode,
      'product_name': productName,
      'category': category,
      if (createdBy != null) 'created_by': createdBy,
    });
    _api.expectStatus(response, 201);
    return GlobalProductModel.fromJson(
      Map<String, dynamic>.from(_api.decode(response) as Map),
    );
  }

  Future<GlobalProductModel> updateProduct(
    int productId,
    Map<String, dynamic> changes,
  ) async {
    final response = await _api.patch('/products/$productId', changes);
    _api.expectStatus(response, 200);
    return GlobalProductModel.fromJson(
      Map<String, dynamic>.from(_api.decode(response) as Map),
    );
  }

  Future<void> deleteProduct(int productId) async {
    final response = await _api.delete('/products/$productId');
    _api.expectStatus(response, 204);
  }
}
