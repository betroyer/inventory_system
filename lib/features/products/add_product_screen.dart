import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../database/database.dart';
import '../../shared/providers/app_providers.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _minStockController = TextEditingController(text: '5');

  String? _imagePath;
  int? _categoryId;
  DateTime? _expirationDate;
  bool _isSaving = false;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product != null) {
      _nameController.text = product.name;
      _quantityController.text = product.quantity.toString();
      _priceController.text = product.price.toString();
      _costController.text = product.costPrice?.toString() ?? '';
      _minStockController.text = product.minimumStock.toString();
      _imagePath = product.imagePath;
      _categoryId = product.categoryId;
      _expirationDate = product.expirationDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file != null) {
      setState(() => _imagePath = file.path);
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickExpirationDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) setState(() => _expirationDate = date);
  }

  Future<void> _showConfirmation() async {
    final name = _nameController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;

    if (name.isEmpty || quantity < 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _ProductConfirmationSheet(
        name: name,
        quantity: quantity,
        price: price,
        imagePath: _imagePath,
      ),
    );

    if (confirmed == true) await _saveProduct();
  }

  Future<void> _saveProduct() async {
    setState(() => _isSaving = true);
    final dao = ref.read(productsDaoProvider);
    final alertService = ref.read(stockAlertServiceProvider);

    final name = _nameController.text.trim();
    final quantity = int.parse(_quantityController.text.trim());
    final price = double.parse(_priceController.text.trim());
    final cost = double.tryParse(_costController.text.trim());
    final minStock = int.tryParse(_minStockController.text.trim()) ??
        AppConstants.defaultMinimumStock;

    try {
      if (isEditing) {
        final product = widget.product!;
        await dao.updateProductById(
          product.id,
          ProductsCompanion(
            name: Value(name),
            imagePath: Value(_imagePath),
            quantity: Value(quantity),
            price: Value(price),
            costPrice: Value(cost),
            minimumStock: Value(minStock),
            expirationDate: Value(_expirationDate),
            categoryId: Value(_categoryId),
            updatedAt: Value(DateTime.now()),
          ),
        );
        final updated = await dao.getProduct(product.id);
        if (updated != null) await alertService.checkProduct(updated);
      } else {
        final productId = await dao.insertProduct(
          ProductsCompanion.insert(
            name: name,
            imagePath: Value(_imagePath),
            quantity: Value(quantity),
            price: price,
            costPrice: Value(cost),
            minimumStock: Value(minStock),
            expirationDate: Value(_expirationDate),
            categoryId: Value(_categoryId),
          ),
        );

        await dao.insertStockMovement(
          StockMovementsCompanion.insert(
            productId: productId,
            type: 'restock',
            quantity: quantity,
            previousQuantity: 0,
            newQuantity: quantity,
            reason: const Value('Initial stock'),
          ),
        );

        final created = await dao.getProduct(productId);
        if (created != null) await alertService.checkProduct(created);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Product Updated Successfully.'
                  : 'Product Added Successfully.',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GestureDetector(
            onTap: _showImageOptions,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: _imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        const Text('Capture Product'),
                        const Text(
                          'Optional photo',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Product Name *'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity *'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Selling Price *'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cost Price (optional)',
              helperText: 'Used for profit calculation',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _minStockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minimum Stock'),
          ),
          const SizedBox(height: 16),
          categories.when(
            data: (items) => DropdownButtonFormField<int?>(
              key: ValueKey(_categoryId),
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...items.map(
                  (Category c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Expiration Date (optional)'),
            subtitle: Text(
              _expirationDate != null
                  ? '${_expirationDate!.year}-${_expirationDate!.month}-${_expirationDate!.day}'
                  : 'Not set',
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickExpirationDate,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _isSaving ? null : _showConfirmation,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isEditing ? 'Save Changes' : 'Continue'),
          ),
        ],
      ),
    );
  }
}

class _ProductConfirmationSheet extends StatelessWidget {
  const _ProductConfirmationSheet({
    required this.name,
    required this.quantity,
    required this.price,
    this.imagePath,
  });

  final String name;
  final int quantity;
  final double price;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Product',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          if (imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(imagePath!),
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (imagePath != null) const SizedBox(height: 16),
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Quantity: $quantity'),
          Text('Price: ${CurrencyFormatter.format(price)}'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
