import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/add_product_provider.dart';
import '../../../../core/providers/app_refresh_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/url_helper.dart';

class AddProductScreen extends StatefulWidget {
  final ProductModel? editingProduct;

  const AddProductScreen({super.key, this.editingProduct});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const Uuid _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();

  late final ApiService _api;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _productIdController = TextEditingController();
  final _gtinController = TextEditingController();
  final _productTypeController = TextEditingController();
  final _priceController = TextEditingController();
  final _offerPercentageController = TextEditingController();
  final _quantityController = TextEditingController();
  final _shippingDetailsController = TextEditingController();
  final _sizeController = TextEditingController();
  final _colorController = TextEditingController();
  final _styleController = TextEditingController();
  final _packQuantityController = TextEditingController();
  final _variationFamilyController = TextEditingController();
  final _materialController = TextEditingController();
  final _dimensionLengthController = TextEditingController();
  final _dimensionWidthController = TextEditingController();
  final _dimensionHeightController = TextEditingController();
  final _weightController = TextEditingController();
  final _itemModelNumberController = TextEditingController();
  final _countryOfOriginController = TextEditingController();
  final _searchTermsController = TextEditingController();

  final List<_EditableFieldRow> _manualSpecificationRows = [];
  final List<TextEditingController> _bulletPointControllers = [];

  final List<_QueuedProductMedia> _mediaQueue = [];
  int _mediaQueueSequence = 0;
  XFile? _specificationPdf;

  String _brandOrigin = 'own';
  String _condition = 'new';
  String _fulfillmentMethod = 'FBM';
  String _dimensionUnit = 'cm';
  bool _gtinExempt = false;
  bool _isSubmitting = false;
  int _initialStockQuantity = 0;
  String _stockAdjustmentMode = 'increment';
  bool _isPrefilling = false;
  late final String _storageProductId;

  bool get _isEditing => widget.editingProduct != null;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _storageProductId = widget.editingProduct?.id ?? _uuid.v4();
    _addManualSpecificationRow();
    _addBulletPointRow();
    _prefillFromEditingProduct();
  }

  @override
  void dispose() {
    for (final controller in [
      _titleController,
      _descriptionController,
      _categoryController,
      _brandNameController,
      _manufacturerController,
      _productIdController,
      _gtinController,
      _productTypeController,
      _priceController,
      _offerPercentageController,
      _quantityController,
      _shippingDetailsController,
      _sizeController,
      _colorController,
      _styleController,
      _packQuantityController,
      _variationFamilyController,
      _materialController,
      _dimensionLengthController,
      _dimensionWidthController,
      _dimensionHeightController,
      _weightController,
      _itemModelNumberController,
      _countryOfOriginController,
      _searchTermsController,
    ]) {
      controller.dispose();
    }
    for (final row in _manualSpecificationRows) {
      row.dispose();
    }
    for (final controller in _bulletPointControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (_isPrefilling) {
      return;
    }
    context.read<AddProductProvider>().markEdited();
  }

  String _metaString(Map<String, dynamic> metadata, String key) {
    final value = metadata[key];
    return value == null ? '' : value.toString().trim();
  }

  String _extractVariationValue(String summary, String prefix) {
    if (summary.isEmpty) {
      return '';
    }
    for (final segment in summary.split('|')) {
      final trimmed = segment.trim();
      if (trimmed.toLowerCase().startsWith(prefix.toLowerCase())) {
        return trimmed.substring(prefix.length).trim();
      }
    }
    return '';
  }

  String _formatOfferPercentage(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    if ((value * 10) == (value * 10).roundToDouble()) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(2);
  }

  void _prefillFromEditingProduct() {
    final product = widget.editingProduct;
    if (product == null) {
      return;
    }

    _isPrefilling = true;

    final metadata = product.metadata;
    final variationSummary = _metaString(metadata, 'variation_summary');
    final dimensionsRaw = metadata['dimensions'];
    final dimensions =
        dimensionsRaw is Map ? Map<String, dynamic>.from(dimensionsRaw) : null;

    _titleController.text = product.title;
    _descriptionController.text = product.description;
    _categoryController.text = product.category;
    final hasDiscount = product.compareAtPrice != null &&
        product.compareAtPrice! > product.price;
    final originalPrice = hasDiscount ? product.compareAtPrice! : product.price;

    _priceController.text = originalPrice.toStringAsFixed(2);
    _offerPercentageController.text = hasDiscount
        ? _formatOfferPercentage(
            ((originalPrice - product.price) / originalPrice) * 100,
          )
        : '';
    _quantityController.text = '0';

    _initialStockQuantity = product.stockQuantity;
    _condition = product.condition;
    _brandNameController.text = _metaString(metadata, 'brand_name');
    _brandOrigin =
        _metaString(metadata, 'brand_origin').toLowerCase() == 'other'
            ? 'other'
            : 'own';
    _manufacturerController.text = _metaString(metadata, 'manufacturer');
    _productIdController.text =
        product.sku ?? _metaString(metadata, 'product_identifier');
    _gtinController.text = _metaString(metadata, 'gtin');
    _gtinExempt = metadata['gtin_exempt'] == true;
    _productTypeController.text = _metaString(metadata, 'product_type');
    _fulfillmentMethod = _metaString(metadata, 'fulfillment_method').isEmpty
        ? 'FBM'
        : _metaString(metadata, 'fulfillment_method');
    _shippingDetailsController.text = _metaString(metadata, 'shipping_details');
    _sizeController.text = _extractVariationValue(variationSummary, 'Size:');
    _colorController.text = _extractVariationValue(variationSummary, 'Color:');
    _styleController.text = _extractVariationValue(variationSummary, 'Style:');
    _packQuantityController.text =
        _extractVariationValue(variationSummary, 'Pack quantity:');
    _variationFamilyController.text =
        _extractVariationValue(variationSummary, 'Variation family:');
    _materialController.text = _metaString(metadata, 'material');
    _dimensionLengthController.text =
        dimensions == null ? '' : (dimensions['length']?.toString() ?? '');
    _dimensionWidthController.text =
        dimensions == null ? '' : (dimensions['width']?.toString() ?? '');
    _dimensionHeightController.text =
        dimensions == null ? '' : (dimensions['height']?.toString() ?? '');
    _dimensionUnit = dimensions == null
        ? 'cm'
        : (dimensions['unit']?.toString().trim().isEmpty ?? true)
            ? 'cm'
            : dimensions['unit'].toString();
    _weightController.text = _metaString(metadata, 'weight');
    _itemModelNumberController.text =
        _metaString(metadata, 'item_model_number');
    _countryOfOriginController.text =
        _metaString(metadata, 'country_of_origin');

    final searchTerms =
        product.searchTerms.isNotEmpty ? product.searchTerms : product.tags;
    _searchTermsController.text = searchTerms.join(', ');

    for (final row in _manualSpecificationRows) {
      row.dispose();
    }
    _manualSpecificationRows.clear();
    final manualSpecs = product.manualSpecifications;
    if (manualSpecs.isEmpty) {
      _addManualSpecificationRow();
    } else {
      for (final entry in manualSpecs.entries) {
        _addManualSpecificationRow(key: entry.key, value: entry.value);
      }
    }

    for (final controller in _bulletPointControllers) {
      controller.dispose();
    }
    _bulletPointControllers.clear();
    final bulletPoints = product.bulletPoints;
    if (bulletPoints.isEmpty) {
      _addBulletPointRow();
    } else {
      for (final point in bulletPoints) {
        _addBulletPointRow(value: point);
      }
    }

    _mediaQueue.clear();
    final queue = product.mediaQueue;
    if (queue.isNotEmpty) {
      for (final item in queue) {
        final type = (item['type'] ?? '').toString().toLowerCase();
        final url = (item['url'] ?? '').toString().trim();
        if (url.isEmpty) {
          continue;
        }
        final kind =
            type == 'video' ? _QueuedMediaKind.video : _QueuedMediaKind.image;
        _mediaQueue.add(
          _QueuedProductMedia.remote(
            id: 'media-${_mediaQueueSequence++}',
            remoteUrl: url,
            kind: kind,
            displayName: (item['name'] ?? '').toString(),
          ),
        );
      }
    }

    if (_mediaQueue.isEmpty) {
      for (final url in product.images) {
        if (url.trim().isEmpty) {
          continue;
        }
        _mediaQueue.add(
          _QueuedProductMedia.remote(
            id: 'media-${_mediaQueueSequence++}',
            remoteUrl: url,
            kind: _QueuedMediaKind.image,
          ),
        );
      }
      for (final url in product.mediaVideos) {
        if (url.trim().isEmpty) {
          continue;
        }
        _mediaQueue.add(
          _QueuedProductMedia.remote(
            id: 'media-${_mediaQueueSequence++}',
            remoteUrl: url,
            kind: _QueuedMediaKind.video,
          ),
        );
      }
    }

    final specificationPdfUrl = product.specificationPdfUrl;
    if (specificationPdfUrl != null && specificationPdfUrl.trim().isNotEmpty) {
      _specificationPdf =
          XFile(specificationPdfUrl.trim(), name: 'existing-specification.pdf');
    }

    _isPrefilling = false;
  }

  void _addManualSpecificationRow({String key = '', String value = ''}) {
    final row = _EditableFieldRow(
      keyController: TextEditingController(text: key),
      valueController: TextEditingController(text: value),
    );
    row.keyController.addListener(_markDirty);
    row.valueController.addListener(_markDirty);
    _manualSpecificationRows.add(row);
  }

  void _addBulletPointRow({String value = ''}) {
    final controller = TextEditingController(text: value);
    controller.addListener(_markDirty);
    _bulletPointControllers.add(controller);
  }

  void _addMediaItems(List<XFile> files, _QueuedMediaKind kind) {
    if (files.isEmpty) {
      return;
    }

    setState(() {
      for (final file in files) {
        _mediaQueue.add(
          _QueuedProductMedia.local(
            id: 'media-${_mediaQueueSequence++}',
            file: file,
            kind: kind,
          ),
        );
      }
    });
    _markDirty();
  }

  void _shuffleMediaQueue() {
    if (_mediaQueue.length < 2) {
      return;
    }
    setState(() {
      _mediaQueue.shuffle();
    });
    _markDirty();
  }

  void _removeMediaAt(int index) {
    if (index < 0 || index >= _mediaQueue.length) {
      return;
    }
    setState(() {
      _mediaQueue.removeAt(index);
    });
    _markDirty();
  }

  void _reorderMediaQueue(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _mediaQueue.removeAt(oldIndex);
      _mediaQueue.insert(newIndex, item);
    });
    _markDirty();
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final pickedFiles = <XFile>[];
    for (final file in result.files) {
      final xFile = _toXFile(file);
      if (xFile != null) {
        pickedFiles.add(xFile);
      }
    }

    if (pickedFiles.isEmpty) {
      return;
    }

    _addMediaItems(pickedFiles, _QueuedMediaKind.image);
  }

  Future<void> _pickVideos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final pickedFiles = <XFile>[];
    for (final file in result.files) {
      final xFile = _toXFile(file);
      if (xFile != null) {
        pickedFiles.add(xFile);
      }
    }

    if (pickedFiles.isEmpty) {
      return;
    }

    _addMediaItems(pickedFiles, _QueuedMediaKind.video);
  }

  Future<void> _pickSpecificationPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final pdf = _toXFile(
      result.files.first,
      fallbackMimeType: 'application/pdf',
    );
    if (pdf == null) {
      return;
    }

    setState(() {
      _specificationPdf = pdf;
    });
    _markDirty();
  }

  XFile? _toXFile(PlatformFile file, {String? fallbackMimeType}) {
    final mimeType = fallbackMimeType ?? _guessMimeType(file.name);

    if (kIsWeb) {
      if (file.bytes == null || file.bytes!.isEmpty) {
        return null;
      }
      return XFile.fromData(
        file.bytes!,
        name: file.name,
        mimeType: mimeType,
      );
    }

    if (file.path != null && file.path!.isNotEmpty) {
      return XFile(
        file.path!,
        name: file.name,
        mimeType: mimeType,
      );
    }

    if (file.bytes != null) {
      return XFile.fromData(
        file.bytes!,
        name: file.name,
        mimeType: mimeType,
      );
    }

    return null;
  }

  String? _guessMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'pdf':
        return 'application/pdf';
      default:
        return null;
    }
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();

    if (_mediaQueue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one product photo or video.'),
        ),
      );
      return;
    }

    if (_specificationPdf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Upload the product specification PDF before publishing.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final uploadedImageUrls = <String>[];
      final uploadedVideoUrls = <String>[];
      final uploadedMediaQueue = <Map<String, dynamic>>[];

      for (final item in _mediaQueue) {
        String? url;
        if (item.isRemote) {
          url = item.remoteUrl;
        } else if (item.file != null) {
          final result = item.kind == _QueuedMediaKind.image
              ? await _api.uploadProductImage(
                  item.file!,
                  productId: _storageProductId,
                )
              : await _api.uploadVideo(
                  item.file!,
                  folder: 'product-videos',
                  productId: _storageProductId,
                );
          url = result['url'] as String?;
        }

        if (url != null && url.isNotEmpty) {
          uploadedMediaQueue.add({
            'type': item.kind.apiValue,
            'url': url,
            'name': item.displayName,
          });
          if (item.kind == _QueuedMediaKind.image) {
            uploadedImageUrls.add(url);
          } else {
            uploadedVideoUrls.add(url);
          }
        }
      }

      String? specificationPdfUrl;
      if (_specificationPdf != null) {
        if (_specificationPdf!.path.startsWith('http://') ||
            _specificationPdf!.path.startsWith('https://')) {
          specificationPdfUrl = _specificationPdf!.path;
        } else {
          final result = await _api.uploadProductDocument(
            _specificationPdf!,
            productId: _storageProductId,
          );
          specificationPdfUrl = result['url'] as String?;
        }
      }

      if (uploadedImageUrls.isEmpty) {
        throw Exception('Add at least one product photo to continue.');
      }

      final manualSpecs = <String, String>{};
      for (final row in _manualSpecificationRows) {
        final key = row.keyController.text.trim();
        final value = row.valueController.text.trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          manualSpecs[key] = value;
        }
      }

      final bulletPoints = _bulletPointControllers
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      final searchTerms = _searchTermsController.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      final sellerName = authProvider.user?.name ?? '';
      final resolvedBrandName = _brandOrigin == 'own'
          ? (sellerName.isNotEmpty
              ? sellerName
              : _brandNameController.text.trim())
          : _brandNameController.text.trim();

      final dimensions = <String, String>{};
      if (_dimensionLengthController.text.trim().isNotEmpty) {
        dimensions['length'] = _dimensionLengthController.text.trim();
      }
      if (_dimensionWidthController.text.trim().isNotEmpty) {
        dimensions['width'] = _dimensionWidthController.text.trim();
      }
      if (_dimensionHeightController.text.trim().isNotEmpty) {
        dimensions['height'] = _dimensionHeightController.text.trim();
      }
      if (dimensions.isNotEmpty) {
        dimensions['unit'] = _dimensionUnit;
      }

      final originalPrice = double.parse(_priceController.text.trim());
      final offerPercentageRaw = _offerPercentageController.text.trim();
      final offerPercentage = offerPercentageRaw.isEmpty
          ? null
          : double.tryParse(offerPercentageRaw);

      final hasValidOffer = offerPercentage != null &&
          offerPercentage > 0 &&
          offerPercentage < 100;
      final effectivePrice = hasValidOffer
          ? originalPrice - (originalPrice * offerPercentage / 100)
          : originalPrice;
      final compareAtPrice = hasValidOffer ? originalPrice : null;

      final metadata = <String, dynamic>{
        'brand_origin': _brandOrigin,
        'brand_name': resolvedBrandName,
        'manufacturer': _manufacturerController.text.trim(),
        'product_identifier': _productIdController.text.trim(),
        'gtin': _gtinExempt ? '' : _gtinController.text.trim(),
        'gtin_exempt': _gtinExempt,
        'product_type': _productTypeController.text.trim(),
        'variation_summary': [
          _sizeController.text.trim().isNotEmpty
              ? 'Size: ${_sizeController.text.trim()}'
              : null,
          _colorController.text.trim().isNotEmpty
              ? 'Color: ${_colorController.text.trim()}'
              : null,
          _styleController.text.trim().isNotEmpty
              ? 'Style: ${_styleController.text.trim()}'
              : null,
          _packQuantityController.text.trim().isNotEmpty
              ? 'Pack quantity: ${_packQuantityController.text.trim()}'
              : null,
          _variationFamilyController.text.trim().isNotEmpty
              ? 'Variation family: ${_variationFamilyController.text.trim()}'
              : null,
        ].whereType<String>().join(' | '),
        'fulfillment_method': _fulfillmentMethod,
        'shipping_details': _shippingDetailsController.text.trim(),
        'bullet_points': bulletPoints,
        'search_terms': searchTerms,
        'manual_specifications': manualSpecs,
        'material': _materialController.text.trim(),
        'dimensions': dimensions,
        'weight': _weightController.text.trim(),
        'color': _colorController.text.trim(),
        'item_model_number': _itemModelNumberController.text.trim(),
        'country_of_origin': _countryOfOriginController.text.trim(),
        if (hasValidOffer) 'offer_percentage': offerPercentage,
        'specification_pdf_url': specificationPdfUrl,
        'media_queue': uploadedMediaQueue,
        'media_videos': uploadedVideoUrls,
      }..removeWhere((key, value) {
          if (value == null) {
            return true;
          }
          if (value is String) {
            return value.trim().isEmpty;
          }
          if (value is List || value is Map) {
            return (value as dynamic).isEmpty;
          }
          return false;
        });

      if (_isEditing) {
        final editingProduct = widget.editingProduct!;
        final latest = await _api.getProduct(editingProduct.id);
        final adjustBy = int.tryParse(_quantityController.text.trim()) ?? 0;
        final updatedStock = _stockAdjustmentMode == 'decrement'
            ? (latest.stockQuantity - adjustBy).clamp(0, 1 << 31)
            : latest.stockQuantity + adjustBy;

        await _api.updateProduct(
          productId: editingProduct.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: effectivePrice,
          compareAtPrice: compareAtPrice,
          category: _categoryController.text.trim(),
          images: uploadedImageUrls,
          tags: searchTerms,
          sku: _productIdController.text.trim().isEmpty
              ? null
              : _productIdController.text.trim(),
          stockQuantity: updatedStock,
          condition: _condition,
          metadata: metadata,
        );
      } else {
        await _api.createProduct(
          id: _storageProductId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: effectivePrice,
          compareAtPrice: compareAtPrice,
          category: _categoryController.text.trim(),
          images: uploadedImageUrls,
          tags: searchTerms,
          sku: _productIdController.text.trim().isEmpty
              ? null
              : _productIdController.text.trim(),
          stockQuantity: int.tryParse(_quantityController.text.trim()),
          condition: _condition,
          metadata: metadata,
        );
      }

      var postSaveMessage = '';
      final normalizedSpecificationPdfUrl = specificationPdfUrl?.trim() ?? '';
      if (normalizedSpecificationPdfUrl.isNotEmpty) {
        postSaveMessage =
            ' Specification PDF saved for product details. Product assistant is coming soon.';
      }

      if (!mounted) {
        return;
      }

      context.read<AddProductProvider>().clearAll();
      context.read<AppRefreshProvider>().notifyProductPublished();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Product updated successfully.$postSaveMessage'
                : 'Product added to your warehouse successfully.$postSaveMessage',
          ),
        ),
      );
      if (_isEditing) {
        context.pop(true);
      } else {
        if (context.canPop()) {
          context.pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/profile');
            }
          });
        } else {
          context.go('/profile');
        }
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Failed to update product: $e'
                : 'Failed to create product: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefixText,
    String? suffixText,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        suffixText: suffixText,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: (value) {
        _markDirty();
        onChanged?.call(value);
      },
    );
  }

  String? Function(String?) _requiredValidator(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  @override
  Widget build(BuildContext context) {
    final isSeller = context.watch<AuthProvider>().isSeller;

    if (!isSeller) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seller Warehouse')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only seller accounts can add products to the warehouse.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Manage Listing' : 'Add Product to Warehouse'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitProduct,
            child: Text(
              _isEditing ? 'Update' : 'Publish',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _buildSectionCard(
              title: 'Warehouse Visibility',
              subtitle:
                  'Products added here will appear for all users on Home and Shop.',
              child: Row(
                children: [
                  const Icon(Icons.public, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Global product listing is enabled for seller products.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: '1. Basic Product Info',
              child: Column(
                children: [
                  _buildTextField(
                    controller: _titleController,
                    label: 'Product name *',
                    hint: 'Enter the product title',
                    validator: _requiredValidator('Product name is required'),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'own', label: Text('Own Brand')),
                      ButtonSegment(
                          value: 'other', label: Text('Different Brand')),
                    ],
                    selected: {_brandOrigin},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _brandOrigin = selection.first;
                      });
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _brandNameController,
                    label:
                        _brandOrigin == 'other' ? 'Brand name *' : 'Brand name',
                    hint: _brandOrigin == 'own'
                        ? 'Leave blank to use your seller name'
                        : 'Enter the brand name',
                    validator: (value) {
                      if (_brandOrigin == 'other' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Brand name is required for products from another brand';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _manufacturerController,
                    label: 'Manufacturer',
                    hint: 'Who makes this product?',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _productIdController,
                          label: 'Product ID',
                          hint: 'SKU or internal ID',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _productTypeController,
                          label: 'Product type',
                          hint: 'Example: smartphone',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _gtinExempt,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('GTIN exemption'),
                    subtitle: const Text(
                      'Use this if you do not have UPC / EAN / ISBN',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _gtinExempt = value ?? false;
                      });
                      _markDirty();
                    },
                  ),
                  if (!_gtinExempt) ...[
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _gtinController,
                      label: 'UPC / EAN / ISBN',
                      hint: 'Optional barcode identifier',
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _categoryController,
                    label: 'Category *',
                    hint: 'Example: Electronics',
                    validator: _requiredValidator('Category is required'),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description *',
                    hint:
                        'Describe the product, who it is for, and what makes it useful',
                    maxLines: 5,
                    maxLength: 1500,
                    validator: _requiredValidator('Description is required'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: '2. Variations',
              subtitle:
                  'Optional if the product has size, color, style, or pack options.',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _sizeController,
                          label: 'Size',
                          hint: 'S, M, L or 256GB',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _colorController,
                          label: 'Color',
                          hint: 'Black',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _styleController,
                          label: 'Style',
                          hint: 'Modern / Classic',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _packQuantityController,
                          label: 'Pack quantity',
                          hint: '2 pack',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _variationFamilyController,
                    label: 'Parent-child variation setup',
                    hint: 'Optional grouping note for related variants',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: '3. Offer Details',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _priceController,
                          label: 'Original price *',
                          hint: '0.00',
                          prefixText: '\$ ',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Price is required';
                            }
                            final price = double.tryParse(value.trim());
                            if (price == null || price <= 0) {
                              return 'Enter a valid price';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _quantityController,
                          label: _isEditing ? 'Adjust stock by' : 'Quantity *',
                          hint: _isEditing ? '0' : '0',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return _isEditing
                                  ? 'Enter a value (0 or more)'
                                  : 'Quantity is required';
                            }
                            final quantity = int.tryParse(value.trim());
                            if (quantity == null || quantity < 0) {
                              return 'Enter a valid quantity';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _offerPercentageController,
                          label: 'Offer % (optional)',
                          hint: '10',
                          suffixText: '%',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            final percentage = double.tryParse(value.trim());
                            if (percentage == null ||
                                percentage <= 0 ||
                                percentage >= 100) {
                              return 'Enter 0-100 (exclusive)';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final original =
                                double.tryParse(_priceController.text.trim());
                            final percentage = double.tryParse(
                              _offerPercentageController.text.trim(),
                            );
                            final hasOffer = original != null &&
                                percentage != null &&
                                percentage > 0 &&
                                percentage < 100;
                            final discounted = hasOffer
                                ? original - (original * percentage / 100)
                                : original;

                            return InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Offer price',
                                prefixText: '\$ ',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                discounted == null
                                    ? '-'
                                    : discounted.toStringAsFixed(2),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Current stock: $_initialStockQuantity',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'increment',
                          icon: Icon(Icons.add),
                          label: Text('Increment by'),
                        ),
                        ButtonSegment(
                          value: 'decrement',
                          icon: Icon(Icons.remove),
                          label: Text('Decrement by'),
                        ),
                      ],
                      selected: {_stockAdjustmentMode},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _stockAdjustmentMode = selection.first;
                        });
                        _markDirty();
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Latest stock is fetched at publish, then the chosen increment/decrement is applied.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _condition,
                    decoration: const InputDecoration(
                      labelText: 'Condition',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'new', child: Text('New')),
                      DropdownMenuItem(value: 'used', child: Text('Used')),
                      DropdownMenuItem(
                        value: 'refurbished',
                        child: Text('Refurbished'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _condition = value;
                      });
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _fulfillmentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Fulfillment method',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'FBM',
                        child: Text('FBM - Seller ships'),
                      ),
                      DropdownMenuItem(
                        value: 'FBA',
                        child: Text('FBA - Platform ships'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _fulfillmentMethod = value;
                      });
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _shippingDetailsController,
                    label: 'Shipping details',
                    hint:
                        'Delivery notes, lead time, coverage, or packaging info',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: '4. Product Description Content',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bullet points',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_bulletPointControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _bulletPointControllers[index],
                              decoration: InputDecoration(
                                labelText: 'Key feature ${index + 1}',
                                hintText:
                                    'Example: 6GB RAM for smooth performance',
                                border: const OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _bulletPointControllers.length == 1
                                ? null
                                : () {
                                    setState(() {
                                      final controller =
                                          _bulletPointControllers.removeAt(
                                        index,
                                      );
                                      controller.dispose();
                                    });
                                    _markDirty();
                                  },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _addBulletPointRow();
                      });
                      _markDirty();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add bullet point'),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _searchTermsController,
                    label: 'Search terms',
                    hint: 'Comma separated keywords for SEO',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: '5. Product Details / Specifications',
              child: Column(
                children: [
                  _buildTextField(
                    controller: _materialController,
                    label: 'Material',
                    hint: 'Example: Aluminum',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _dimensionLengthController,
                          label: 'Length',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _dimensionWidthController,
                          label: 'Width',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _dimensionHeightController,
                          label: 'Height',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _weightController,
                          label: 'Weight',
                          hint: 'Example: 1.3 kg',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _dimensionUnit,
                          decoration: const InputDecoration(
                            labelText: 'Dimension unit',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'cm', child: Text('cm')),
                            DropdownMenuItem(value: 'mm', child: Text('mm')),
                            DropdownMenuItem(
                              value: 'in',
                              child: Text('inches'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _dimensionUnit = value;
                            });
                            _markDirty();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _itemModelNumberController,
                          label: 'Item model number',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _countryOfOriginController,
                          label: 'Country of origin',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Manual key-value specifications',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_manualSpecificationRows.length, (index) {
                    final row = _manualSpecificationRows[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: row.keyController,
                              decoration: const InputDecoration(
                                labelText: 'Spec name',
                                hintText: 'RAM',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: row.valueController,
                              decoration: const InputDecoration(
                                labelText: 'Spec value',
                                hintText: '6GB',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _manualSpecificationRows.length == 1
                                ? null
                                : () {
                                    setState(() {
                                      final removed =
                                          _manualSpecificationRows.removeAt(
                                        index,
                                      );
                                      removed.dispose();
                                    });
                                    _markDirty();
                                  },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _addManualSpecificationRow();
                      });
                      _markDirty();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add specification'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Media Queue',
              subtitle:
                  'Add photos and videos, then drag to reorder or shuffle the queue before publishing.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                            'Add Photos (${_mediaQueue.where((item) => item.kind == _QueuedMediaKind.image).length})'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickVideos,
                        icon: const Icon(Icons.videocam_outlined),
                        label: Text(
                            'Add Videos (${_mediaQueue.where((item) => item.kind == _QueuedMediaKind.video).length})'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _mediaQueue.length > 1 ? _shuffleMediaQueue : null,
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Shuffle Queue'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickSpecificationPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          _specificationPdf == null
                              ? 'Upload Specs PDF *'
                              : 'Replace Specs PDF',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A specification PDF is required to publish this product.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  if (_mediaQueue.isEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('No media added yet.'),
                    ),
                  ],
                  if (_mediaQueue.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _mediaQueue.length,
                      onReorder: _reorderMediaQueue,
                      itemBuilder: (context, index) {
                        final item = _mediaQueue[index];
                        return Card(
                          key: ValueKey(item.id),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: _QueuedMediaPreview(item: item),
                            title: Text(item.displayName),
                            subtitle: Text(item.kind.label),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => _removeMediaAt(index),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(Icons.drag_handle),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  if (_specificationPdf != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                        ),
                        title: Text(_specificationPdf!.name),
                        subtitle: const Text('Specification sheet'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _specificationPdf = null;
                            });
                            _markDirty();
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitProduct,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isEditing
                      ? Icons.edit_outlined
                      : Icons.inventory_2_outlined),
              label: Text(_isSubmitting
                  ? (_isEditing ? 'Updating...' : 'Publishing...')
                  : (_isEditing ? 'Update Product' : 'Publish Product')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableFieldRow {
  final TextEditingController keyController;
  final TextEditingController valueController;

  _EditableFieldRow({
    required this.keyController,
    required this.valueController,
  });

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

enum _QueuedMediaKind { image, video }

extension on _QueuedMediaKind {
  String get label => this == _QueuedMediaKind.image ? 'Photo' : 'Video';
  String get apiValue => this == _QueuedMediaKind.image ? 'image' : 'video';
}

class _QueuedProductMedia {
  final String id;
  final XFile? file;
  final String? remoteUrl;
  final _QueuedMediaKind kind;
  final String displayName;

  bool get isRemote => remoteUrl != null;

  _QueuedProductMedia({
    required this.id,
    required this.file,
    required this.remoteUrl,
    required this.kind,
    required this.displayName,
  });

  factory _QueuedProductMedia.local({
    required String id,
    required XFile file,
    required _QueuedMediaKind kind,
  }) {
    return _QueuedProductMedia(
      id: id,
      file: file,
      remoteUrl: null,
      kind: kind,
      displayName: file.name,
    );
  }

  factory _QueuedProductMedia.remote({
    required String id,
    required String remoteUrl,
    required _QueuedMediaKind kind,
    String? displayName,
  }) {
    return _QueuedProductMedia(
      id: id,
      file: null,
      remoteUrl: remoteUrl,
      kind: kind,
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : remoteUrl.split('/').last,
    );
  }
}

class _QueuedMediaPreview extends StatelessWidget {
  final _QueuedProductMedia item;

  const _QueuedMediaPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade100,
          ),
          child: item.kind == _QueuedMediaKind.image
              ? _ImagePreview(
                  file: item.file,
                  remoteUrl: item.remoteUrl,
                )
              : item.remoteUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          UrlHelper.getPlatformUrl(item.remoteUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.videocam_outlined,
                                size: 28,
                                color: Colors.black54,
                              ),
                            );
                          },
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 32,
                        color: Colors.black54,
                      ),
                    ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final XFile? file;
  final String? remoteUrl;

  const _ImagePreview({required this.file, required this.remoteUrl});

  @override
  Widget build(BuildContext context) {
    if (remoteUrl != null && remoteUrl!.isNotEmpty) {
      return Image.network(
        UrlHelper.getPlatformUrl(remoteUrl!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.broken_image_outlined));
        },
      );
    }

    if (file == null) {
      return const Center(child: Icon(Icons.broken_image_outlined));
    }

    return FutureBuilder<Uint8List>(
      future: file!.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return const Center(child: Icon(Icons.broken_image_outlined));
        }
        return Image.memory(snapshot.data!, fit: BoxFit.cover);
      },
    );
  }
}
