import 'package:flutter/material.dart';

import 'user_data.dart';
import 'user_item_form_view.dart';

/// รายการสินค้าของฉัน (หน้า 3 ฝั่ง User): ค้นหา + กรองหมวด + แก้/ลบ
class UserInventoryView extends StatefulWidget {
  const UserInventoryView({super.key});

  @override
  State<UserInventoryView> createState() => _UserInventoryViewState();
}

class _UserInventoryViewState extends State<UserInventoryView> {
  String _query = '';
  String _cat = 'All';

  void _openForm([UserItem? item]) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => UserItemFormView(item: item)));
  }

  Future<void> _delete(UserItem item) async {
    if (await confirmDeleteItem(context, item)) {
      try {
        await UserInventory.instance.remove(item.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = UserInventory.instance;
    return ListenableBuilder(
      listenable: inv,
      builder: (context, _) {
        final all = inv.items;
        final q = _query.toLowerCase();
        final shown = all
            .where((i) =>
                (_cat == 'All' || i.category == _cat) &&
                (i.name.toLowerCase().contains(q) || i.barcode.contains(q)))
            .toList()
          ..sort((a, b) => a.expiry.compareTo(b.expiry));

        int count(String c) =>
            c == 'All' ? all.length : all.where((i) => i.category == c).length;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: kUserGreen,
                  minimumSize: const Size.fromHeight(52)),
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search by barcode or product name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: ['All', ...kCategories]
                  .map((c) => ChoiceChip(
                        label: Text('$c (${count(c)})'),
                        selected: _cat == c,
                        selectedColor: kUserGreen,
                        labelStyle:
                            TextStyle(color: _cat == c ? Colors.white : null),
                        checkmarkColor: Colors.white,
                        onSelected: (_) => setState(() => _cat = c),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No items found')),
              ),
            for (final item in shown)
              Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  onTap: () => _openForm(item),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.category == 'Medicine'
                          ? Icons.medication_outlined
                          : Icons.restaurant_outlined,
                      color: item.statusColor,
                    ),
                  ),
                  title: Text('${item.name}  ×${item.qty}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${item.barcode} · ${item.category}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(item.statusText,
                        style: TextStyle(
                            color: item.statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    PopupMenuButton<String>(
                      onSelected: (v) =>
                          v == 'edit' ? _openForm(item) : _delete(item),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}
