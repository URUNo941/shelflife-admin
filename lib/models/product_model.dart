// =============================================================================
// ProductModel = สินค้า 1 รายการใน Master Barcode Catalog
// -----------------------------------------------------------------------------
// - ตรงกับตาราง `global_products` ในฐานข้อมูล
// - "Master Catalog" = ฐานข้อมูลกลางของบาร์โค้ด ที่ Admin เป็นคนเพิ่ม/แก้/ลบ
// - ใช้ที่หน้า: Master Catalog (Admin) และตอนผู้ใช้สแกนบาร์โค้ด
//   สแกนแล้วระบบหา ProductModel ที่ barcode ตรงกัน -> เติมชื่อสินค้าและหมวดหมู่ให้อัตโนมัติ
// - ต่างจาก UserItem ตรงที่: ProductModel คือ "ข้อมูลสินค้าทั่วไป" (ใช้ร่วมกันทุกคน)
//   ส่วน UserItem คือ "ของที่อยู่ในตู้ของผู้ใช้แต่ละคน" (มีวันหมดอายุ, จำนวน)
// =============================================================================
class ProductModel {
  // ทุก field เป็น final = immutable (แก้ค่าตรงๆ ไม่ได้ ต้องใช้ copyWith)
  final int productId; // คอลัมน์ product_id (Primary Key)
  final String barcode; // เลขบาร์โค้ด เช่น '8850123456789' (ห้ามซ้ำในระบบ)
  final String productName; // ชื่อสินค้า
  final String category; // หมวดหมู่ เช่น Food, Medicine, Other
  final int? createdBy; // user_id ของ Admin ที่เพิ่มสินค้า
  // `int?` = เป็น null ได้ (เช่นข้อมูลเก่าที่ไม่รู้ว่าใครเพิ่ม หรือ admin คนนั้นถูกลบไปแล้ว)
  final DateTime createdAt; // วันที่เพิ่มเข้าระบบ

  const ProductModel({
    required this.productId,
    required this.barcode,
    required this.productName,
    this.category = 'General', // ไม่ระบุหมวด = 'General' (ตรงกับ DEFAULT ใน DB)
    this.createdBy, // ไม่บังคับ เพราะเป็น null ได้
    required this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // fromJson: JSON จาก API -> object
  // เช่น GET /api/products ส่งกลับมาเป็น:
  //   { "product_id": 1, "barcode": "8850123456789", "product_name": "Fresh Milk 1L",
  //     "category": "Food", "created_by": 1, "created_at": "2026-11-03T13:27:43.000Z" }
  // ---------------------------------------------------------------------------
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      productId: json['product_id'] as int,
      barcode: json['barcode'] as String,
      productName: json['product_name'] as String,
      // ถ้า API ไม่ส่ง category มา ให้ใช้ 'General' กันแอปพัง
      category: (json['category'] as String?) ?? 'General',
      createdBy: json['created_by'] as int?, // `as int?` = รับค่า null ได้
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['created_at'] as String),
    );
  }

  // toJson: object -> JSON ใช้ตอนส่งไป API (เช่น POST /api/products ตอน Admin เพิ่มสินค้า)
  // ชื่อ key ใช้ snake_case ตามชื่อคอลัมน์ใน DB ส่วนตัวแปรใน Dart ใช้ camelCase
  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'barcode': barcode,
        'product_name': productName,
        'category': category,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  // copyWith: ใช้ตอน Admin แก้ไขสินค้า สร้าง object ใหม่ที่เปลี่ยนเฉพาะ field ที่ส่งมา
  //   final edited = milk.copyWith(productName: 'Low-fat Milk');
  // แก้ได้แค่ barcode / ชื่อ / หมวดหมู่ ส่วน productId, createdBy, createdAt ต้องคงเดิม
  // เพราะเป็นข้อมูลประวัติ (ใครเพิ่ม เพิ่มเมื่อไร) ไม่ควรเปลี่ยนตอนแก้ไข
  ProductModel copyWith({
    String? barcode,
    String? productName,
    String? category,
  }) {
    return ProductModel(
      productId: productId,
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}
