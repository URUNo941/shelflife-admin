import 'package:flutter/material.dart';

// Model และ Controller ย้ายไปอยู่ใน lib/models และ lib/controllers แล้ว
// export ต่อไว้ให้ไฟล์ที่ import user_data.dart เดิมยังใช้งานได้
export '../../controllers/user_inventory_controller.dart';
export '../../models/user_item.dart';

const kUserGreen = Color(0xFF0D7A53);
const kCategories = ['Food', 'Medicine', 'Other'];
