import 'package:flutter/material.dart';

import '../models/inventory_item_model.dart';
import '../services/api_client.dart';

/// Controller แบบง่ายที่อ่าน/เพิ่มของในตู้ผ่าน API โดยตรง (ใช้กับ InventoryListView)
/// หน้าจอหลักของผู้ใช้ใช้ [UserInventory] แทน
/// ทุก request แนบ JWT ของผู้ใช้ที่ล็อกอินอยู่ (ผ่าน ApiClient)
class InventoryController {
  InventoryController({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  /// ดึงของในตู้ (active) ของผู้ใช้ที่ล็อกอิน
  /// [userId] เก็บไว้เพื่อความเข้ากันได้กับโค้ดเดิม backend ใช้ user จาก token เสมอ
  Future<List<InventoryItemModel>> getInventoryItems([int? userId]) async {
    try {
      final data = await _api.get('/items') as List;
      return data
          .map((json) => InventoryItemModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint(e.toString());
      throw Exception('Could not connect to the server.');
    }
  }

  /// เพิ่มของใหม่ (backend ใช้เจ้าของจาก token ไม่ใช่ user_id ใน body)
  Future<void> addItem(Map<String, dynamic> itemData) async {
    try {
      await _api.post('/items', itemData);
    } catch (e) {
      debugPrint(e.toString());
      throw Exception('Could not save the item.');
    }
  }
}
