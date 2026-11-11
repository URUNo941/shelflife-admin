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

  String _productKey(UserItem item) {
    final barcode = item.barcode.trim().toLowerCase();
    return barcode.isNotEmpty
        ? 'barcode:$barcode'
        : 'name:${item.category.toLowerCase()}:${item.name.toLowerCase()}';
  }

  Map<String, List<UserItem>> _groupByProduct(Iterable<UserItem> items) {
    final groups = <String, List<UserItem>>{};
    for (final item in items) {
      groups.putIfAbsent(_productKey(item), () => []).add(item);
    }
    return groups;
  }

  void _openForm([UserItem? item]) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => UserItemFormView(item: item)));
  }

  Future<void> _delete(UserItem item) async {
    if (await confirmDeleteItem(context, item)) {
      UserInventory.instance.remove(item.id);
    }
  }

  Future<void> _useOne(UserItem item) async {
    final use = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use one item?'),
        content: Text(
          'Use one ${item.name} from the batch expiring ${_formatDate(item.expiry)}? '
          '${item.qty == 1 ? 'This will remove the batch from inventory.' : '${item.qty - 1} will remain.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kUserGreen),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use one'),
          ),
        ],
      ),
    );
    if (use != true) return;
    if (item.qty == 1) {
      UserInventory.instance.remove(item.id);
    } else {
      item.qty--;
      UserInventory.instance.update();
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final inv = UserInventory.instance;
    return ListenableBuilder(
      listenable: inv,
      builder: (context, _) {
        final all = inv.items;
        final q = _query.toLowerCase();
        final filtered = all
            .where((i) =>
                (_cat == 'All' || i.category == _cat) &&
                (i.name.toLowerCase().contains(q) || i.barcode.contains(q)))
            .toList();
        final groups = _groupByProduct(filtered);
        final shown = groups.values.toList()
          ..sort((a, b) {
            DateTime nextExpiry(List<UserItem> batches) {
              final usable = batches.where((item) => !item.isExpired).toList();
              final candidates = usable.isEmpty ? batches : usable;
              return candidates.map((item) => item.expiry).reduce(
                    (first, next) => first.isBefore(next) ? first : next,
                  );
            }

            return nextExpiry(a).compareTo(nextExpiry(b));
          });

        int count(String category) => _groupByProduct(
              category == 'All'
                  ? all
                  : all.where((item) => item.category == category),
            ).length;

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
            for (final productBatches in shown)
              Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: productBatches.first.statusColor
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      productBatches.first.category == 'Medicine'
                          ? Icons.medication_outlined
                          : Icons.restaurant_outlined,
                      color: productBatches.first.statusColor,
                    ),
                  ),
                  title: Text(
                    '${productBatches.first.name}  ×${productBatches.fold<int>(0, (total, item) => total + item.qty)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${productBatches.first.barcode} · ${productBatches.first.category} · '
                    '${productBatches.length} ${productBatches.length == 1 ? 'expiry batch' : 'expiry batches'}',
                  ),
                  children: _buildBatchRows(productBatches),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildBatchRows(List<UserItem> productBatches) {
    final batches = [...productBatches]..sort((a, b) {
        if (a.isExpired != b.isExpired) return a.isExpired ? 1 : -1;
        return a.expiry.compareTo(b.expiry);
      });
    final suggestedBatch = batches.where((item) => !item.isExpired).firstOrNull;

    return [
      for (var index = 0; index < batches.length; index++) ...[
        Builder(builder: (context) {
          final item = batches[index];
          final isSuggested = item.id == suggestedBatch?.id;
          return Padding(
            padding:
                EdgeInsets.only(bottom: index == batches.length - 1 ? 0 : 8),
            child: Material(
              color: item.statusColor.withValues(alpha: 0.07),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: item.statusColor.withValues(alpha: 0.2),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                onTap: () => _openForm(item),
                leading: Icon(Icons.event_outlined, color: item.statusColor),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Exp ${_formatDate(item.expiry)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (isSuggested)
                      const Text(
                        'Use first',
                        style: TextStyle(
                          color: kUserGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('${item.qty} in this batch'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: item.statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.statusText,
                          style: TextStyle(
                            color: item.statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: isSuggested
                          ? 'Use from soonest-expiring batch'
                          : 'Use from this batch',
                      onPressed: () => _useOne(item),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: isSuggested ? kUserGreen : Colors.grey.shade600,
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) =>
                          value == 'edit' ? _openForm(item) : _delete(item),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    ];
  }
}
