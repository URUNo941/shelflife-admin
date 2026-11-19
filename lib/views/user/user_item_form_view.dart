import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../controllers/product_controller.dart';
import '../../services/api_client.dart';
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
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isSaving = false;

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = image.name;
      });
    } catch (error) {
      if (mounted) _showError('Could not open image source: $error');
    }
  }

  Future<void> _takePicture() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) throw StateError('No camera was found.');
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final image = await Navigator.push<XFile>(
        context,
        MaterialPageRoute(
          builder: (_) => _CameraCaptureView(camera: camera),
        ),
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = image.name;
      });
    } on CameraException catch (error) {
      if (mounted) {
        _showError(error.description ?? 'Could not open camera: ${error.code}');
      }
    } catch (error) {
      if (mounted) _showError('Could not open camera: $error');
    }
  }

  Future<String> _uploadImage() async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.instance.baseUrl}/upload'),
    );
    final token = ApiClient.instance.token;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        _selectedImageBytes!,
        filename: _selectedImageName?.isNotEmpty == true
            ? _selectedImageName!
            : 'item.jpg',
      ),
    );

    final response = await request.send().timeout(const Duration(seconds: 30));
    final responseText = await response.stream.bytesToString();
    dynamic body;
    try {
      body = jsonDecode(responseText);
    } on FormatException {
      body = null;
    }
    if (response.statusCode != 200) {
      final message = body is Map && body['message'] is String
          ? body['message'] as String
          : 'Image upload failed (${response.statusCode}).';
      throw StateError(message);
    }
    if (body is! Map || body['imageUrl'] is! String) {
      throw const FormatException('The server returned an invalid image URL.');
    }
    return body['imageUrl'] as String;
  }

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
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
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
      imageUrl: oldItem?.imageUrl,
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
      if (choice == null) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }
      if (!mounted) return;
      if (choice == 'merge') mergeInto = matchingBatch;
    }

    try {
      if (_selectedImageBytes != null) {
        candidate.imageUrl = await _uploadImage();
      }
      if (!mounted) return;
      final error = await inv.saveItem(
        candidate,
        replacing: oldItem,
        mergeInto: mergeInto,
      );
      if (!mounted) return;
      if (error != null) {
        _showError(error);
        return;
      }
      Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              Center(
                child: Column(
                  children: [
                    Container(
                      height: 150,
                      width: 150,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: _selectedImageBytes == null
                          ? widget.item?.imageUrl == null
                              ? const Icon(
                                  Icons.image_outlined,
                                  size: 50,
                                  color: Colors.grey,
                                )
                              : Image.network(
                                  widget.item!.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_outlined,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                )
                          : Image.memory(_selectedImageBytes!,
                              fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Select Image'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kUserGreen,
                            side: const BorderSide(color: kUserGreen),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _takePicture,
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
                    onPressed: _isSaving ? null : _save,
                    child: Text(
                      _isSaving
                          ? 'Saving...'
                          : _isEdit
                              ? 'Save Changes'
                              : 'Save',
                    ),
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

class _CameraCaptureView extends StatefulWidget {
  final CameraDescription camera;

  const _CameraCaptureView({required this.camera});

  @override
  State<_CameraCaptureView> createState() => _CameraCaptureViewState();
}

class _CameraCaptureViewState extends State<_CameraCaptureView> {
  late final CameraController _controller;
  late final Future<void> _initializeCamera;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _initializeCamera = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_isTakingPicture || !_controller.value.isInitialized) return;
    setState(() => _isTakingPicture = true);
    try {
      final image = await _controller.takePicture();
      if (mounted) Navigator.pop(context, image);
    } on CameraException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.description ?? 'Could not take picture: ${error.code}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Picture'),
        backgroundColor: kUserGreen,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FutureBuilder<void>(
                  future: _initializeCamera,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Could not start the camera. Check camera permission '
                          'and use HTTPS or localhost in a browser.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    if (snapshot.connectionState != ConnectionState.done ||
                        !_controller.value.isInitialized) {
                      return const CircularProgressIndicator();
                    }
                    return CameraPreview(_controller);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton.icon(
                onPressed: _isTakingPicture ? null : _capture,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(_isTakingPicture ? 'Capturing...' : 'Capture'),
                style: FilledButton.styleFrom(
                  backgroundColor: kUserGreen,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
