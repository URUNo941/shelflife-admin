import 'package:flutter/material.dart';
import '../../controllers/inventory_controller.dart';
import '../../models/inventory_item_model.dart';

class InventoryListView extends StatefulWidget {
  const InventoryListView({super.key});

  @override
  State<InventoryListView> createState() => _InventoryListViewState();
}

class _InventoryListViewState extends State<InventoryListView> {
  final InventoryController _controller = InventoryController();

  // Logic คำนวณสีตามวันหมดอายุ
  Color _getExpiryColor(DateTime expDate) {
    final now = DateTime.now();
    final difference = expDate.difference(DateTime(now.year, now.month, now.day)).inDays;

    if (difference < 0) {
      return Colors.red.shade100; // หมดอายุแล้ว (Red)
    } else if (difference <= 3) {
      return Colors.amber.shade100; // ใกล้หมดอายุภายใน 3 วัน (Yellow)
    } else {
      return Colors.green.shade100; // ปลอดภัย (Green)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ShelfLife - My Inventory'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<List<InventoryItemModel>>(
        future: _controller.getInventoryItems(1), // สมมติ user_id = 1
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('ไม่มีรายการสินค้าในตู้'));
          }

          final items = snapshot.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final cardColor = _getExpiryColor(item.expirationDate);

              return Card(
                color: cardColor,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(
                    item.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Exp: ${item.expirationDate.day}/${item.expirationDate.month}/${item.expirationDate.year} | Category: ${item.category}',
                  ),
                  trailing: Text('Qty: ${item.quantity}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}