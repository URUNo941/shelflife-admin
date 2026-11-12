import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/product_controller.dart';
import '../../models/product_model.dart';
import 'add_edit_barcode_view.dart';

class MasterCatalogView extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  /// ถ้าไม่ส่งมา ใช้ [ProductController.instance]
  final ProductController? controller;

  const MasterCatalogView({
    super.key,
    this.onBackToDashboard,
    this.controller,
  });

  @override
  State<MasterCatalogView> createState() => _MasterCatalogViewState();
}

class _MasterCatalogViewState extends State<MasterCatalogView> {
  String selectedCategory = 'All';
  String searchQuery = '';
  String sortBy = 'Barcode';

  late final ProductController _products =
      widget.controller ?? ProductController.instance;

  @override
  void initState() {
    super.initState();
    _products.addListener(_onProductsChanged);
  }

  @override
  void dispose() {
    _products.removeListener(_onProductsChanged);
    super.dispose();
  }

  void _onProductsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _addBarcode() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditBarcodeView(
          existingBarcodes:
              _products.products.map((item) => item.barcode).toSet(),
        ),
      ),
    );

    if (result != null) {
      final error = _products.add(
        barcode: result['barcode']!,
        productName: result['product_name']!,
        category: result['category']!,
        createdBy: AuthController.instance.currentUser?.userId,
      );
      _showMessage(error ?? 'Barcode added');
    }
  }

  Future<void> _editBarcode(ProductModel item) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditBarcodeView(
          initialData: {
            'barcode': item.barcode,
            'product_name': item.productName,
            'category': item.category,
          },
          existingBarcodes: _products.products
              .where((product) => product.productId != item.productId)
              .map((product) => product.barcode)
              .toSet(),
        ),
      ),
    );

    if (result != null) {
      final error = _products.update(
        item.productId,
        barcode: result['barcode']!,
        productName: result['product_name']!,
        category: result['category']!,
      );
      _showMessage(error ?? 'Barcode updated');
    }
  }

  Future<void> _deleteBarcode(ProductModel item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete barcode?'),
        content: Text(
          'Remove ${item.productName} from the catalog?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      _products.delete(item.productId);
      if (mounted) _showMessage('Barcode deleted');
    }
  }

  Future<void> _showCategoryFilter() async {
    final categories = [
      'All',
      ..._products.categories,
    ];
    final category = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Filter by category',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...categories.map(
              (category) => ListTile(
                title: Text(category),
                trailing: selectedCategory == category
                    ? const Icon(Icons.check, color: Color(0xFF0D7A53))
                    : null,
                onTap: () => Navigator.pop(context, category),
              ),
            ),
          ],
        ),
      ),
    );

    if (category != null) {
      setState(() => selectedCategory = category);
    }
  }

  Future<void> _showSortOptions() async {
    final sort = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Sort products',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final option in ProductController.sortOptions)
              ListTile(
                title: Text(option),
                trailing: sortBy == option
                    ? const Icon(Icons.check, color: Color(0xFF0D7A53))
                    : null,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );

    if (sort != null) {
      setState(() => sortBy = sort);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.search(
      query: searchQuery,
      category: selectedCategory,
      sortBy: sortBy,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: widget.onBackToDashboard,
                  ),
                  const Column(
                    children: [
                      Text(
                        'Global Product Catalog',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Manage barcode product database',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 24),
                    tooltip: 'Sort catalog',
                    onPressed: _showSortOptions,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Add Barcode Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _addBarcode,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Add Barcode',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7A53),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Search Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => searchQuery = val),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        hintText: 'Search by barcode or product name...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.tune_rounded, color: Colors.black87),
                      tooltip: 'Filter category',
                      onPressed: _showCategoryFilter,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'All',
                    ..._products.categories,
                  ].map((category) {
                    final count = _products.countInCategory(category);
                    final isSelected = selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text('$category ($count)'),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => selectedCategory = category);
                        },
                        selectedColor: const Color(0xFF0D7A53),
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide.none,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // Product List
              Expanded(
                child: filteredProducts.isEmpty
                    ? const Center(child: Text('No products found'))
                    : ListView.builder(
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final item = filteredProducts[index];
                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade100),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0D7A53)),
                              ),
                              title: Text(
                                item.barcode,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName, style: const TextStyle(fontSize: 13)),
                                  Text(
                                    item.category,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                      _editBarcode(item);
                                    } else if (val == 'delete') {
                                      _deleteBarcode(item);
                                    }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}