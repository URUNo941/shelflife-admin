import 'api_client.dart';
import '../models/inventory_item_model.dart';

class InventoryController {
  InventoryController({ApiClient apiClient = const ApiClient()})
      : _api = apiClient;

  final ApiClient _api;

  Future<List<InventoryItemModel>> getInventoryItems(int userId) async {
    final response = await _api.get('/items/$userId');
    _api.expectStatus(response, 200);
    final data = _api.decode(response) as List<dynamic>;
    return data
        .map((json) => InventoryItemModel.fromJson(
              Map<String, dynamic>.from(json as Map),
            ))
        .toList();
  }

  Future<InventoryItemModel> getInventoryItem(int userId, int itemId) async {
    final response = await _api.get('/items/$userId/$itemId');
    _api.expectStatus(response, 200);
    return InventoryItemModel.fromJson(
      Map<String, dynamic>.from(_api.decode(response) as Map),
    );
  }

  Future<void> addItem(Map<String, dynamic> itemData) async {
    final response = await _api.post('/items', itemData);
    _api.expectStatus(response, 201);
  }

  Future<InventoryItemModel> updateItem(
    int itemId,
    Map<String, dynamic> changes,
  ) async {
    final response = await _api.patch('/items/$itemId', changes);
    _api.expectStatus(response, 200);
    return InventoryItemModel.fromJson(
      Map<String, dynamic>.from(_api.decode(response) as Map),
    );
  }

  Future<void> deleteItem(int itemId) async {
    final response = await _api.delete('/items/$itemId');
    _api.expectStatus(response, 204);
  }
}
