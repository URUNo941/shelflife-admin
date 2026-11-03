import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/inventory_item_model.dart';

class InventoryController {
  // หากรันใน Android Emulator ใช้ 'http://10.0.2.2:3000/api'
  // หากรันบน Chrome/Windows ใช้ 'http://localhost:3000/api'
  static const String baseURL = 'http://localhost:3000/api';

  // ดึงรายการสินค้าทั้งหมด
  Future<List<InventoryItemModel>> getInventoryItems(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseURL/items/$userId'));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      List data = jsonDecode(response.body);
      return data.map((json) => InventoryItemModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint(e.toString());
      throw Exception('Could not connect to the server.');
    }
  }

  // เพิ่มสินค้าใหม่
  Future<void> addItem(Map<String, dynamic> itemData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/items'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(itemData),
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to add item: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(e.toString());
      throw Exception('Could not connect to the server.');
    }
  }
}