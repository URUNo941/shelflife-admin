import 'package:flutter/material.dart';

import '../utils/expiry_status.dart';

// =============================================================================
// UserItem = สินค้าในตู้ของผู้ใช้ 1 "ล็อต"
// -----------------------------------------------------------------------------
// - ตรงกับตาราง `inventory_items` ในฐานข้อมูล
// - ใช้ที่หน้า: Home, My Inventory, ฟอร์มเพิ่ม/แก้ไขสินค้า
// - 1 ล็อต = barcode เดียวกัน + วันหมดอายุเดียวกัน
//   เช่น นม 2 กล่องหมด 10 พ.ย. = 1 ล็อต (qty = 2)
//        แต่นมอีกกล่องหมด 15 พ.ย. = อีกล็อตหนึ่ง แยกกัน เพราะต้องติดตามวันหมดอายุแยกกัน
// - เป็นโมเดลที่มี logic มากที่สุด เพราะคำนวณสถานะวันหมดอายุและสีเตือนเองได้
// =============================================================================
class UserItem {
  // ต่างจาก UserModel / ProductModel: field ส่วนใหญ่ "ไม่ใช่ final" (แก้ค่าได้)
  // เหตุผล: ผู้ใช้แก้ของในตู้บ่อยมาก เช่นกด "Use one" -> qty ลดลง 1 ทันที
  final String id; // รหัสล็อต (เปลี่ยนไม่ได้ เพราะใช้อ้างอิงตอนแก้/ลบ)
  String barcode; // บาร์โค้ดสินค้า
  String name; // ชื่อสินค้า
  String category; // หมวดหมู่: Food / Medicine / Other
  DateTime expiry; // วันหมดอายุ
  final DateTime addedAt; // วันที่เพิ่มเข้าตู้ (ใช้คำนวณ % อายุที่เหลือ จึงห้ามเปลี่ยน)
  int qty; // จำนวนชิ้นในล็อตนี้

  UserItem({
    required this.id,
    required this.barcode,
    required this.name,
    required this.category,
    required this.expiry,
    DateTime? addedAt, // ไม่บังคับส่ง
    this.qty = 1, // ไม่ระบุจำนวน = 1 ชิ้น
  }) : addedAt = addedAt ?? DateTime.now();
  // ↑ initializer list (หลังเครื่องหมาย :) ทำงานก่อนสร้าง object เสร็จ
  //   ถ้าไม่ส่ง addedAt มา ให้ใช้ "เวลาตอนนี้" แทน
  //   ต้องเขียนแบบนี้เพราะ DateTime.now() เป็นค่า default ใน () ตรงๆ ไม่ได้ (ไม่ใช่ const)

  // ---------------------------------------------------------------------------
  // Getter คำนวณสถานะวันหมดอายุ (คำนวณใหม่ทุกครั้งที่เรียก จึงอัปเดตตามวันจริงเสมอ)
  // ---------------------------------------------------------------------------

  // เหลืออีกกี่วันจะหมดอายุ (ติดลบ = หมดไปแล้วกี่วัน)
  // ตัดเวลาของวันนี้ทิ้ง (เหลือแค่ วัน/เดือน/ปี) เพื่อนับเป็น "วันเต็ม"
  // ไม่งั้นตอนบ่ายอาจนับได้น้อยกว่าความจริง 1 วัน
  int get daysLeft {
    final n = DateTime.now();
    return expiry.difference(DateTime(n.year, n.month, n.day)).inDays;
  }

  // หมดอายุแล้วหรือยัง (เลยวันหมดอายุไปแล้ว)
  bool get isExpired => daysLeft < 0;

  // อายุที่เหลือเป็น % (0-100) นับจาก "วันที่เพิ่มเข้าตู้" ถึง "วันหมดอายุ"
  // เช่น เพิ่มวันที่ 1 หมดวันที่ 11 (อายุ 10 วัน) วันนี้วันที่ 8 -> เหลือ 3 วัน = 30%
  // ใช้ % แทนจำนวนวัน เพราะยุติธรรมกับสินค้าทุกแบบ
  //   (นมอายุ 7 วันเหลือ 3 วัน = น่าห่วง แต่ยาอายุ 2 ปีเหลือ 3 วัน = วิกฤต)
  // ส่งไปคำนวณที่ ExpiryStatus (utils) เพื่อให้ทุกหน้าใช้สูตรเดียวกัน
  double get remainingLifePercentage => ExpiryStatus.remainingPercentage(
        addedAt: addedAt,
        expiryDate: expiry,
      );

  // วิกฤต (สีแดง): หมดวันนี้/หมดแล้ว หรือ อายุเหลือน้อยกว่า 10%
  // (กรณีเหลือ 1 วันพอดีไม่นับเป็นวิกฤต ให้เป็นสีเหลืองแทน)
  bool get isCritical =>
      daysLeft <= 0 || (daysLeft > 1 && remainingLifePercentage < 10);

  // ใกล้หมดอายุ (สีเหลือง): ยังไม่หมด และ (เหลือ 1 วัน หรือ อายุเหลือ 10-30%)
  bool get isExpiringSoon =>
      daysLeft >= 0 &&
      (daysLeft == 1 ||
          (remainingLifePercentage >= 10 && remainingLifePercentage < 30));

  // สีสถานะที่ใช้แสดงบนการ์ดสินค้า:
  //   เขียว  = อายุเหลือ >= 30%
  //   เหลือง = เหลือ 10-30% หรือเหลืออีก 1 วัน
  //   แดง   = เหลือ < 10%, หมดวันนี้ หรือหมดอายุแล้ว
  Color get statusColor =>
      ExpiryStatus.color(addedAt: addedAt, expiryDate: expiry);

  // ข้อความสถานะใต้ชื่อสินค้า (ternary ซ้อน: เงื่อนไข ? ค่าถ้าจริง : ค่าถ้าเท็จ)
  //   หมดแล้ว        -> 'Expired 3d ago'   (-daysLeft ทำให้ค่าติดลบเป็นบวก)
  //   หมดวันนี้      -> 'Expires today'
  //   เหลือ 1 วัน    -> '1 day left'        (ไม่เติม s)
  //   เหลือหลายวัน   -> '5 days left'
  String get statusText => isExpired
      ? 'Expired ${-daysLeft}d ago'
      : daysLeft == 0
          ? 'Expires today'
          : '$daysLeft day${daysLeft == 1 ? '' : 's'} left';
}
