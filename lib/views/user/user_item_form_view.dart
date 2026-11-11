import 'package:flutter/material.dart';

import 'user_data.dart';

/// Dialog ยืนยันลบ (หน้า 6) ใช้ได้จากทั้งหน้า list และหน้า edit
Future<bool> confirmDeleteItem(BuildContext context, UserItem item) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const CircleAvatar(
        radius: 28,
        backgroundColor: Color(0xFFFEE2E2),
        child: Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
      ),
      title: const Text('Delete Item?'),
      content: Text(
        'Are you sure you want to delete ${item.name} (${item.barcode})?\nThis action cannot be undone.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// ฟอร์มเพิ่ม (item == null) และแก้ไขสินค้า (หน้า 4 + 5 รวมกัน)
class UserItemFormView extends StatefulWidget {
  final UserItem? item;
  const UserItemFormView({super.key, this.item});

  @override
  State<UserItemFormView> createState() => _UserItemFormViewState();
}

class _UserItemFormViewState extends State<UserItemFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _barcode;
  late final TextEditingController _name;
  late String _category;
  late DateTime _expiry;
  late int _qty;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _barcode = TextEditingController(text: i?.barcode ?? '');
    _name = TextEditingController(text: i?.name ?? '');
    _category = i?.category ?? kCategories.first;
    _expiry = i?.expiry ?? DateTime.now().add(const Duration(days: 7));
    _qty = i?.qty ?? 1;
  }

  @override
  void dispose() {
    _barcode.dispose();
    _name.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _expiry,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _expiry = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final inv = UserInventory.instance;
    final oldItem = widget.item;
    final candidate = UserItem(
      id: oldItem?.id ?? inv.newId(),
      barcode: _barcode.text.trim(),
      name: _name.text.trim(),
      category: _category,
      expiry: _expiry,
      addedAt: oldItem?.addedAt,
      qty: _qty,
    );
    final matchingBatch = inv.findBatch(
      barcode: candidate.barcode,
      expiry: candidate.expiry,
      excludingId: oldItem?.id,
    );

    UserItem? mergeInto;
    if (matchingBatch != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Matching expiry batch'),
          content: Text(
            '${candidate.name} already has a batch with this barcode and expiry date '
            '(${_fmt(candidate.expiry)}), with ${matchingBatch.qty} in stock.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'separate'),
              child: const Text('Keep separate'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kUserGreen),
              onPressed: () => Navigator.pop(context, 'merge'),
              child: const Text('Add quantity'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (!mounted) return;
      if (choice == 'merge') mergeInto = matchingBatch;
    }

    inv.save(candidate, replacing: oldItem, mergeInto: mergeInto);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final item = widget.item!;
    if (await confirmDeleteItem(context, item) && mounted) {
      UserInventory.instance.remove(item.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF8FF),
      appBar: AppBar(
        backgroundColor: kUserGreen,
        foregroundColor: Colors.white,
        title: Text(_isEdit ? 'Edit Item' : 'Add Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _barcode,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Barcode *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Scan barcode',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () {}, // TODO: ต่อกล้องสแกนบาร์โค้ด
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Product Name *', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                    labelText: 'Category *', border: OutlineInputBorder()),
                items: kCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expiry date *',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(_fmt(_expiry)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Text('Quantity'),
                const Spacer(),
                IconButton(
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_qty',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => setState(() => _qty++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ]),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: _isEdit
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _delete,
                          child: const Text('Delete'),
                        )
                      : OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48)),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kUserGreen,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _save,
                    child: Text(_isEdit ? 'Save Changes' : 'Save'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
