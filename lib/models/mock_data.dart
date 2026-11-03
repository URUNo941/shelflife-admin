class MockData {
  // ข้อมูลจำลอง Master Barcode Catalog (สำหรับ Admin)
  static final List<Map<String, String>> globalProducts = [
    {
      'barcode': '8850123456789',
      'product_name': 'Fresh Milk',
      'category': 'Food',
    },
    {
      'barcode': '8850987654321',
      'product_name': 'Sliced Bread',
      'category': 'Food',
    },
    {
      'barcode': '8850111222333',
      'product_name': 'Paracetamol 500mg',
      'category': 'Medicine',
    },
    {
      'barcode': '8850444555666',
      'product_name': 'Instant Noodles',
      'category': 'Food',
    },
  ];

  // ข้อมูลจำลอง User List (สำหรับ User Management)
  static final List<Map<String, String>> users = [
    {'username': 'tom123', 'role': 'Admin', 'joined': 'Oct 1, 2026'},
    {'username': 'sarah', 'role': 'User', 'joined': 'Oct 5, 2026'},
    {'username': 'john', 'role': 'User', 'joined': 'Oct 10, 2026'},
  ];
}