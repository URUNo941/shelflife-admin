import '../services/api_client.dart';
import '../models/inventory_item_model.dart';

class InventoryController {
  Future<List<InventoryItemModel>> getInventoryItems(int userId) async {
    final data =
        await ApiClient.instance.request('GET', '/me/inventory') as List;
    return data.map((j) => InventoryItemModel.fromJson(j)).toList();
  }

  Future<void> addItem(Map<String, dynamic> itemData) async {
    final body = Map<String, dynamic>.from(itemData)
      ..remove('user_id')
      ..remove('item_id');
    await ApiClient.instance.request('POST', '/me/inventory', body);
  }
}
