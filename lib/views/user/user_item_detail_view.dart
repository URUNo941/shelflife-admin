import 'package:flutter/material.dart';

import 'user_data.dart';
import 'user_item_form_view.dart';

class UserItemDetailView extends StatefulWidget {
  final UserItem item;

  const UserItemDetailView({super.key, required this.item});

  @override
  State<UserItemDetailView> createState() => _UserItemDetailViewState();
}

class _UserItemDetailViewState extends State<UserItemDetailView> {
  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _finish(UserItem item, {required bool consumed}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(consumed ? 'Mark as consumed?' : 'Mark as discarded?'),
        content: Text(consumed
            ? 'Mark this batch of ${item.name} as consumed?'
            : 'Mark this batch of ${item.name} as discarded?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: consumed ? kUserGreen : const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(consumed ? 'Consumed' : 'Discarded'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = consumed
        ? await UserInventory.instance.markConsumed(item)
        : await UserInventory.instance.discard(item);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _delete(UserItem item) async {
    if (!await confirmDeleteItem(context, item) || !mounted) return;
    final error = await UserInventory.instance.deleteItem(item.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserInventory.instance,
      builder: (context, _) {
        final item = UserInventory.instance.items
                .where((current) => current.id == widget.item.id)
                .firstOrNull ??
            widget.item;
        return _buildPage(context, item);
      },
    );
  }

  Widget _buildPage(BuildContext context, UserItem item) {
    final statusColor = item.statusColor;
    final statusLabel = item.isExpired
        ? 'Expired'
        : item.daysLeft == 0
            ? 'Expires today'
            : item.daysLeft <= 3 || item.isExpiringSoon || item.isCritical
                ? 'Use soon'
                : 'Fresh';

    return Scaffold(
      backgroundColor: const Color(0xFFFCF8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF8FF),
        title: const Text('Item details'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'delete') _delete(item);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete item'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(item),
                  )
                : _imagePlaceholder(item),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(item.category,
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              _StatusPill(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_outlined, color: statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.isExpired
                            ? 'This batch has expired'
                            : item.daysLeft == 0
                                ? 'Use this item today'
                                : 'Expiration date',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.isExpired
                            ? '${_date(item.expiry)} · ${-item.daysLeft} day${item.daysLeft == -1 ? '' : 's'} ago'
                            : item.daysLeft == 0
                                ? '${_date(item.expiry)} · Expires today'
                                : '${_date(item.expiry)} · ${item.daysLeft} day${item.daysLeft == 1 ? '' : 's'} left',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Item information',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Quantity',
                  value: '${item.qty} ${item.qty == 1 ? 'item' : 'items'}',
                ),
                const Divider(height: 1, indent: 56),
                _InfoRow(
                  icon: Icons.qr_code_2_rounded,
                  label: 'Barcode',
                  value: item.barcode.isEmpty ? 'Not provided' : item.barcode,
                ),
                const Divider(height: 1, indent: 56),
                _InfoRow(
                  icon: Icons.add_circle_outline,
                  label: 'Added on',
                  value: _date(item.addedAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: kUserGreen,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserItemFormView(item: item),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit item'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _finish(item, consumed: true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Consumed'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB42318),
                  ),
                  onPressed: () => _finish(item, consumed: false),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Discarded'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(UserItem item) {
    final icon = item.category == 'Medicine'
        ? Icons.medication_outlined
        : Icons.restaurant_outlined;
    return Center(
      child: Icon(icon, size: 72, color: kUserGreen.withValues(alpha: 0.7)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: kUserGreen),
      title: Text(label, style: TextStyle(color: Colors.grey.shade600)),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
