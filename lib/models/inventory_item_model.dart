import 'package:flutter/material.dart';

import '../utils/expiry_status.dart';

// =============================================================================
// InventoryItemModel = สินค้าในตู้ 1 รายการ "ในรูปแบบที่ได้จาก API / ฐานข้อมูล"
// -----------------------------------------------------------------------------
// - ตรงกับตาราง `inventory_items` ทุกคอลัมน์ (item_id, user_id, quantity, status ...)
// - ใช้คู่กับ InventoryController ที่ยิง HTTP ไปที่ backend: GET /api/items/:userId
// - ต่างจาก UserItem ยังไง?
//     InventoryItemModel = ฝั่ง "ข้อมูลจาก server" (field เป็น final, มี userId, status)
//                          เตรียมไว้สำหรับต่อ backend จริง (Sprint 4)
//     UserItem           = ฝั่ง "หน้าจอแอป" ตอนนี้ใช้กับ mock data (แก้ค่าได้ เช่น qty)
//   ใน Sprint 3 หน้าจอยังใช้ UserItem เพราะยังไม่ต่อ backend
// =============================================================================
class InventoryItemModel {
  // ทุก field เป็น final = immutable (ข้อมูลที่ได้จาก server ไม่ควรถูกแก้ในแอปโดยตรง)
  final int itemId; // คอลัมน์ item_id (Primary Key)
  final int userId; // คอลัมน์ user_id = เป็นของผู้ใช้คนไหน (Foreign Key ไปตาราง users)
  final String? barcode; // บาร์โค้ด `String?` = เป็น null ได้ (สินค้าบางชิ้นไม่มีบาร์โค้ด)
  final String productName; // ชื่อสินค้า
  final String category; // หมวดหมู่
  final int quantity; // จำนวนชิ้น
  final DateTime expirationDate; // วันหมดอายุ
  final DateTime createdAt; // วันที่เพิ่มเข้าตู้
  // สถานะของสินค้า ตรงกับ enum ใน DB:
  //   'active'    = ยังอยู่ในตู้
  //   'consumed'  = ใช้/กินหมดแล้ว
  //   'discarded' = ทิ้งไป (เช่นหมดอายุ) ใช้ทำสถิติในหน้า Analytics
  final String status;

  InventoryItemModel({
    required this.itemId,
    required this.userId,
    this.barcode, // ไม่บังคับ เพราะเป็น null ได้
    required this.productName,
    required this.category,
    required this.quantity,
    required this.expirationDate,
    required this.createdAt,
    required this.status,
  });

  // ---------------------------------------------------------------------------
  // fromJson: แปลง JSON 1 แถวที่ API ส่งมา -> object
  // `??` = ถ้าค่าเป็น null ให้ใช้ค่า default ทางขวา (ตรงกับ DEFAULT ในฐานข้อมูล)
  // ---------------------------------------------------------------------------
  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryItemModel(
      itemId: json['item_id'],
      userId: json['user_id'],
      barcode: json['barcode'],
      productName: json['product_name'],
      category: json['category'] ?? 'General', // DB default = 'General'
      quantity: json['quantity'] ?? 1, // DB default = 1
      // วันที่จาก API มาเป็นข้อความ เช่น "2026-11-05T00:00:00.000Z" -> แปลงเป็น DateTime
      expirationDate: DateTime.parse(json['expiration_date']),
      createdAt: DateTime.parse(json['created_at']),
      status: json['status'] ?? 'active', // DB default = 'active'
    );
  }

  // อายุที่เหลือเป็น % (0-100) ใช้สูตรเดียวกับ UserItem ผ่าน ExpiryStatus
  // => (arrow) = เขียนฟังก์ชันบรรทัดเดียว เท่ากับ { return ...; }
  double get remainingLifePercentage => ExpiryStatus.remainingPercentage(
        addedAt: createdAt,
        expiryDate: expirationDate,
      );

  // สีเตือนวันหมดอายุ: เขียว (>= 30%), เหลือง (10-30% หรือเหลือ 1 วัน), แดง (< 10% / หมดแล้ว)
  Color get expiryColor => ExpiryStatus.color(
        addedAt: createdAt,
        expiryDate: expirationDate,
      );

  // toJson: object -> JSON สำหรับส่งไป API (เช่น POST /api/items ตอนเพิ่มสินค้า)
  // ไม่ส่ง created_at ไป เพราะ DB ใส่ให้เองอัตโนมัติ (DEFAULT current_timestamp)
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
