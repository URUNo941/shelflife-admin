import 'package:flutter/material.dart';

class AddEditBarcodeView extends StatefulWidget {
  final Map<String, String>? initialData; // ถ้าส่งข้อมูลมา = หน้า Edit, ถ้า null = หน้า Add

  const AddEditBarcodeView({super.key, this.initialData});

  @override
  State<AddEditBarcodeView> createState() => _AddEditBarcodeViewState();
}

class _AddEditBarcodeViewState extends State<AddEditBarcodeView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _barcodeController;
  late TextEditingController _nameController;
  String _selectedCategory = 'Food';

  final List<String> _categories = ['Food', 'Medicine', 'Beverage', 'Other'];

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(
      text: widget.initialData?['barcode'] ?? '',
    );
    _nameController = TextEditingController(
      text: widget.initialData?['product_name'] ?? '',
    );
    if (widget.initialData != null && widget.initialData!['category'] != null) {
      if (_categories.contains(widget.initialData!['category'])) {
        _selectedCategory = widget.initialData!['category']!;
      }
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      // ตัวอย่างเมื่อบันทึกข้อมูลเรียบร้อย
      final isEdit = widget.initialData != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Updated successfully!' : 'Added successfully!'),
          backgroundColor: const Color(0xFF0D7A53),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialData != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Master Barcode' : 'Add New Barcode'),
        backgroundColor: const Color(0xFF0D7A53),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ช่องกรอก Barcode
              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Barcode Number',
                  hintText: 'e.g. 8850123456789',
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter barcode number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ช่องกรอก Product Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Product Name',
                  hintText: 'e.g. Fresh Milk 200ml',
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter product name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // เลือก Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _categories
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // ปุ่ม Save
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7A53),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isEdit ? 'Update Barcode' : 'Save Barcode',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}