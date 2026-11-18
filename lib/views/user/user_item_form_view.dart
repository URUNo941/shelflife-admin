import 'package:flutter/material.dart';

import '../../controllers/product_controller.dart';
<<<<<<< Updated upstream
=======
import '../../services/api_client.dart';
>>>>>>> Stashed changes
import 'user_data.dart';
import 'user_scan_view.dart';

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

<<<<<<< Updated upstream
=======
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = pickedFile;
        });
      }
    } catch (e) {
      if (mounted) _showError('Failed to pick image: $e');
    }
  }

>>>>>>> Stashed changes
  /// เปิดกล้องสแกน แล้วใส่ barcode ที่ได้ลงฟอร์ม
  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const UserScanView()),
    );
    if (code == null || !mounted) return;
    _barcode.text = code;
    _fillFromCatalog(code);
  }

  /// Smart Barcode Auto-Fill: ถ้า barcode อยู่ใน Master Catalog และยังไม่ได้กรอกชื่อ
  /// ให้เติมชื่อ/หมวดหมู่ให้อัตโนมัติ (ถาม backend: GET /api/products/master/:barcode)
  Future<void> _fillFromCatalog(String code) async {
    if (_name.text.trim().isNotEmpty || code.trim().isEmpty) return;
    final product = await ProductController.instance.lookup(code);
    // ผู้ใช้อาจพิมพ์ต่อระหว่างรอ: ใช้ผลเฉพาะเมื่อ barcode ยังเป็นค่าเดิม
    if (product == null || !mounted || _barcode.text.trim() != code.trim()) {
      return;
    }
    if (_name.text.trim().isNotEmpty) return;
    setState(() {
      _name.text = product.productName;
      _category = product.category;
    });
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

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
<<<<<<< Updated upstream
    final inv = UserInventory.instance;
    final oldItem = widget.item;
=======

    String? uploadedImageUrl;

    // ถ้ามีการเลือกรูปใหม่ ให้ยิง API ไปอัปโหลดที่ Backend ก่อน
    if (_selectedImage != null) {
      try {
        final uri = Uri.parse('${ApiClient.instance.baseUrl}/upload');
        final request = http.MultipartRequest('POST', uri);

        if (kIsWeb) {
          final bytes = await _selectedImage!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: _selectedImage!.name,
          ));
        } else {
          request.files.add(
              await http.MultipartFile.fromPath('image', _selectedImage!.path));
        }

        final response = await request.send();
        final responseData = await response.stream.bytesToString();
        if (!mounted) return;
        if (response.statusCode != 200) {
          var message = 'Upload failed (${response.statusCode}).';
          try {
            final body = jsonDecode(responseData);
            if (body is Map && body['message'] is String) {
              message = body['message'] as String;
            }
          } on FormatException {
            // Keep the HTTP status message when the server does not return JSON.
          }
          _showError(message);
          return;
        }
        final body = jsonDecode(responseData);
        if (body is! Map || body['imageUrl'] is! String) {
          _showError('Upload failed: the server returned an invalid response.');
          return;
        }
        uploadedImageUrl = body['imageUrl'] as String;
      } catch (e) {
        if (mounted) _showError('Error uploading image: $e');
        return;
      }
    }

    final inv = UserInventory.instance;
    final oldItem = widget.item;

>>>>>>> Stashed changes
    final candidate = UserItem(
      id: oldItem?.id ?? inv.newId(),
      barcode: _barcode.text.trim(),
      name: _name.text.trim(),
      category: _category,
      expiry: _expiry,
      addedAt: oldItem?.addedAt,
      qty: _qty,
    );
<<<<<<< Updated upstream
=======

>>>>>>> Stashed changes
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

    final error =
        await inv.saveItem(candidate, replacing: oldItem, mergeInto: mergeInto);
    if (!mounted) return;
    if (error != null) return _showError(error);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final item = widget.item!;
    if (await confirmDeleteItem(context, item) && mounted) {
      final error = await UserInventory.instance.deleteItem(item.id);
      if (!mounted) return;
      if (error != null) return _showError(error);
      Navigator.pop(context);
    }
  }

<<<<<<< Updated upstream
=======
  // --- ฟังก์ชันแสดงตัวอย่างรูปภาพ ---
  Widget _buildImagePreview() {
    if (_selectedImage == null && _isEdit && widget.item!.imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(widget.item!.imageUrl!, fit: BoxFit.cover),
      );
    }

    if (_selectedImage == null) {
      return const Icon(Icons.image_outlined, size: 50, color: Colors.grey);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: kIsWeb
          ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
          : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
    );
  }

>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
=======
              // --- UI ส่วนเลือกรูปภาพ ---
              Center(
                child: Column(
                  children: [
                    Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: _buildImagePreview(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Select Image'),
                          style: TextButton.styleFrom(
                            foregroundColor: kUserGreen,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Take Picture'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kUserGreen,
                            side: const BorderSide(color: kUserGreen),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // --- สิ้นสุด UI ส่วนรูปภาพ ---

>>>>>>> Stashed changes
              TextFormField(
                controller: _barcode,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Barcode *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Scan barcode',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                  ),
                ),
                onChanged: _fillFromCatalog,
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
                key: ValueKey(_category),
                initialValue: _category,
                decoration: const InputDecoration(
                    labelText: 'Category *', border: OutlineInputBorder()),
                // หมวดจากแคตตาล็อกอาจไม่อยู่ใน 3 หมวดหลัก (เช่น Fruit) ก็ให้เลือกได้
                items: [
                  ...kCategories,
                  if (!kCategories.contains(_category)) _category,
                ]
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
