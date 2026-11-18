import 'package:flutter/material.dart';

import 'user_data.dart';
import 'user_item_detail_view.dart';

class UserNotificationsView extends StatefulWidget {
  const UserNotificationsView({super.key});

  @override
  State<UserNotificationsView> createState() => _UserNotificationsViewState();
}

class _UserNotificationsViewState extends State<UserNotificationsView> {
  String _filter = 'All';

  List<UserItem> _notifications(List<UserItem> items) {
    final filtered = items.where((item) {
      if (_filter == 'Expired') return item.isExpired;
      if (_filter == 'Expiring soon') {
        return !item.isExpired &&
            (item.daysLeft <= 3 || item.isExpiringSoon || item.isCritical);
      }
      return item.isExpired ||
          item.daysLeft <= 3 ||
          item.isExpiringSoon ||
          item.isCritical;
    }).toList()
      ..sort((a, b) => a.expiry.compareTo(b.expiry));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final inventory = UserInventory.instance;
    return ListenableBuilder(
      listenable: inventory,
      builder: (context, _) {
        final items = _notifications(inventory.items);
        final expiredCount = inventory.items.where((item) => item.isExpired).length;
        final upcomingCount = inventory.items
            .where((item) =>
                !item.isExpired &&
                (item.daysLeft <= 3 || item.isExpiringSoon || item.isCritical))
            .length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D7A53), Color(0xFF16A36D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stay ahead of expiry',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          items.isEmpty
                              ? 'Your shelf is looking good.'
                              : 'You have ${expiredCount + upcomingCount} item alerts to review.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.white,
                    size: 34,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: ['All', 'Expiring soon', 'Expired'].map((filter) {
                final selected = _filter == filter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: selected,
                  selectedColor: kUserGreen,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : null,
                    fontWeight: FontWeight.w600,
                  ),
                  checkmarkColor: Colors.white,
                  onSelected: (_) => setState(() => _filter = filter),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              _EmptyNotifications(filter: _filter)
            else ...[
              Text(
                _filter == 'All' ? 'Needs your attention' : _filter,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (final item in items) _notificationCard(context, item),
            ],
          ],
        );
      },
    );
  }

  Widget _notificationCard(BuildContext context, UserItem item) {
    final expired = item.isExpired;
    final color = expired ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final title = expired
        ? '${item.name} has expired'
        : item.daysLeft == 0
            ? '${item.name} expires today'
            : '${item.name} is expiring soon';
    final detail = expired
        ? 'Expired ${-item.daysLeft} day${item.daysLeft == -1 ? '' : 's'} ago'
        : item.daysLeft == 0
            ? 'Use today · ${item.qty} in stock'
            : '${item.daysLeft} day${item.daysLeft == 1 ? '' : 's'} left · ${item.qty} in stock';

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserItemDetailView(item: item),
          ),
        ),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            expired ? Icons.error_outline : Icons.schedule_rounded,
            color: color,
          ),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text('$detail\n${item.category}'),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  final String filter;

  const _EmptyNotifications({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFE7F5EF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: kUserGreen,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            filter == 'All' ? 'All caught up!' : 'Nothing here',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            filter == 'Expired'
                ? 'No expired items on your shelf.'
                : filter == 'Expiring soon'
                    ? 'No items need attention soon.'
                    : 'We’ll let you know when something needs attention.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
