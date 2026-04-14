// تمت إزالة التعريف المؤقت واستُبدل بالتنفيذ الكامل أدناه
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class StoreAddMenuItemScreen extends StatefulWidget {
  final String restaurantId;
  final String? itemId;
  final String? initialName;
  final double? initialPrice;
  final Map<String, double>? initialSizes;
  final String? initialCategory;
  final String? initialImageUrl;
  final bool initialAvailable;

  const StoreAddMenuItemScreen({
    super.key,
    required this.restaurantId,
    this.itemId,
    this.initialName,
    this.initialPrice,
    this.initialSizes,
    this.initialCategory,
    this.initialImageUrl,
    this.initialAvailable = true,
  });

  bool get isEditing => itemId != null && itemId!.trim().isNotEmpty;

  @override
  State<StoreAddMenuItemScreen> createState() => _StoreAddMenuItemScreenState();
}

class _StoreAddMenuItemScreenState extends State<StoreAddMenuItemScreen> {
  static const List<String> _categoryOptions = [
    'وجبات رئيسية',
    'وجبات سريعة',
    'أرز وبرياني',
    'مشاوي',
    'شاورما',
    'برجر',
    'بيتزا',
    'باستا',
    'مندي',
    'مأكولات بحرية',
    'أسماك',
    'دجاج',
    'لحوم',
    'سندويتشات',
    'مقبلات',
    'شوربات',
    'سلطات',
    'فطور',
    'فطائر',
    'معجنات',
    'مناقيش',
    'كريب',
    'حلويات',
    'كيك',
    'آيس كريم',
    'عصائر',
    'سموثي',
    'قهوة',
    'مشروبات ساخنة',
    'مشروبات باردة',
    'موهيتو',
    'مشروبات غازية',
    'مياه',
    'وجبات أطفال',
    'صحي',
    'نباتي',
    'خالي من الجلوتين',
    'صوصات وإضافات',
    'أطباق جانبية',
    'عروض ووجبات كومبو',
    'رمضان',
    'مخبوزات',
    'مكسرات وتسالي',
    'مأكولات شعبية',
    'وجبات اقتصادية',
    'بوكسات عائلية',
    'صنف اليوم',
    'أخرى',
  ];

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemPriceController = TextEditingController();
  final TextEditingController _smallPriceController = TextEditingController();
  final TextEditingController _mediumPriceController = TextEditingController();
  final TextEditingController _largePriceController = TextEditingController();
  String? _selectedCategory;
  File? _imageFile;
  String? _existingImageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _itemNameController.text = widget.initialName?.trim() ?? '';
    _selectedCategory = widget.initialCategory?.trim().isNotEmpty == true
        ? widget.initialCategory!.trim()
        : null;
    _existingImageUrl = widget.initialImageUrl?.trim();

    final initialSizes = widget.initialSizes ?? const <String, double>{};
    if (initialSizes.isNotEmpty) {
      _smallPriceController.text =
          initialSizes['small']?.toStringAsFixed(2).replaceAll('.00', '') ?? '';
      _mediumPriceController.text =
          initialSizes['medium']?.toStringAsFixed(2).replaceAll('.00', '') ?? '';
      _largePriceController.text =
          initialSizes['large']?.toStringAsFixed(2).replaceAll('.00', '') ?? '';
    } else if (widget.initialPrice != null && widget.initialPrice! > 0) {
      _itemPriceController.text =
          widget.initialPrice!.toStringAsFixed(2).replaceAll('.00', '');
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemPriceController.dispose();
    _smallPriceController.dispose();
    _mediumPriceController.dispose();
    _largePriceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1400,
    );
    if (pickedImage != null) {
      setState(() => _imageFile = File(pickedImage.path));
    }
  }

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    const cloudName = 'dvnzloec6';
    const uploadPreset = 'flutter_unsigned';

    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final respData = json.decode(await response.stream.bytesToString());
      return respData['secure_url'];
    } else {
      return null;
    }
  }

  String _categoryDocId(String category) => category.replaceAll('/', '-');

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppThemeArabic.storePrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppThemeArabic.storePrimary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_imageFile == null && (_existingImageUrl == null || _existingImageUrl!.isEmpty)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار صورة للصنف')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final itemName = _itemNameController.text.trim();
    final rawPrice = _itemPriceController.text.trim().replaceAll(',', '.');
    final rawSmall = _smallPriceController.text.trim().replaceAll(',', '.');
    final rawMedium = _mediumPriceController.text.trim().replaceAll(',', '.');
    final rawLarge = _largePriceController.text.trim().replaceAll(',', '.');
    final category = _selectedCategory?.trim() ?? '';

    final hasAnySize =
        rawSmall.isNotEmpty || rawMedium.isNotEmpty || rawLarge.isNotEmpty;
    final basePrice = rawPrice.isEmpty ? null : double.tryParse(rawPrice);
    final smallPrice = rawSmall.isEmpty ? null : double.tryParse(rawSmall);
    final mediumPrice = rawMedium.isEmpty ? null : double.tryParse(rawMedium);
    final largePrice = rawLarge.isEmpty ? null : double.tryParse(rawLarge);

    if (!hasAnySize && basePrice == null) {
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال سعر صالح')),
      );
      return;
    }

    if (basePrice != null && basePrice <= 0) {
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('السعر يجب أن يكون أكبر من صفر')),
      );
      return;
    }

    if (hasAnySize) {
      if (smallPrice == null || mediumPrice == null || largePrice == null) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('عند استخدام الأحجام يجب إدخال الأسعار الثلاثة')),
        );
        return;
      }
      if (smallPrice <= 0 || mediumPrice <= 0 || largePrice <= 0) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('أسعار الأحجام يجب أن تكون أكبر من صفر')),
        );
        return;
      }
    }

    final price = basePrice ?? mediumPrice ?? smallPrice ?? largePrice!;
    final sizes = hasAnySize
        ? <String, double>{
            'small': smallPrice!,
            'medium': mediumPrice!,
            'large': largePrice!,
          }
        : <String, double>{};

    if (category.isEmpty) {
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم الفئة')),
      );
      return;
    }

    final categoryDocId = _categoryDocId(category);
    final previousCategory = widget.initialCategory?.trim() ?? '';
    final previousCategoryDocId =
        previousCategory.isEmpty ? '' : _categoryDocId(previousCategory);

    try {
      String imageUrl = _existingImageUrl?.trim() ?? '';
      if (_imageFile != null) {
        final uploadedImageUrl = await _uploadImageToCloudinary(_imageFile!);
        if (uploadedImageUrl == null) {
          setState(() => _isLoading = false);
          messenger.showSnackBar(
            const SnackBar(content: Text('فشل رفع الصورة')),
          );
          return;
        }
        imageUrl = uploadedImageUrl;
      }

      if (imageUrl.isEmpty) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('تعذر تحديد صورة الصنف')),
        );
        return;
      }

      final restaurantsRef = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId);
      final menuItemRef = restaurantsRef
          .collection('menu')
          .doc(categoryDocId)
          .collection('items')
          .doc(widget.itemId);
      final fullMenuRef = restaurantsRef
          .collection('full_menu')
          .doc(widget.itemId ?? menuItemRef.id);

      final payload = <String, dynamic>{
        'name': itemName,
        'price': price,
        'imageUrl': imageUrl,
        'category': category,
        'available': widget.isEditing ? widget.initialAvailable : true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (sizes.isNotEmpty) {
        payload['sizes'] = sizes;
      }
      if (!widget.isEditing) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      await menuItemRef.set(payload, SetOptions(merge: true));
      await fullMenuRef.set(payload, SetOptions(merge: true));

      if (widget.isEditing && sizes.isEmpty) {
        try {
          await menuItemRef.update({'sizes': FieldValue.delete()});
        } catch (_) {}
        try {
          await fullMenuRef.update({'sizes': FieldValue.delete()});
        } catch (_) {}
      }

      if (widget.isEditing &&
          previousCategory.isNotEmpty &&
          previousCategoryDocId != categoryDocId) {
        try {
          await restaurantsRef
              .collection('menu')
              .doc(previousCategoryDocId)
              .collection('items')
              .doc(widget.itemId)
              .delete();
        } catch (_) {}
      }

      String? warningMessage;

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _itemNameController.clear();
        _itemPriceController.clear();
        _smallPriceController.clear();
        _mediumPriceController.clear();
        _largePriceController.clear();
        _selectedCategory = null;
        _imageFile = null;
        _existingImageUrl = null;
      });

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(widget.isEditing ? 'تم التعديل' : 'تمت الإضافة'),
          content: Text(
            warningMessage ??
                (widget.isEditing
                    ? 'تم تعديل الصنف بنجاح ✅'
                    : 'تمت إضافة الصنف بنجاح ✅'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).maybePop(true);
              },
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = e.code == 'permission-denied'
          ? (widget.isEditing
              ? 'لا تملك صلاحية تعديل الصنف. تأكد أن المتجر معتمد وحسابك يطابق صاحب المتجر.'
              : 'لا تملك صلاحية إضافة صنف. تأكد أن المتجر معتمد وحسابك يطابق صاحب المتجر.')
          : 'تعذر ${widget.isEditing ? 'تعديل' : 'إضافة'} الصنف: ${e.message ?? e.code}';
      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(content: Text('تعذر ${widget.isEditing ? 'تعديل' : 'إضافة'} الصنف: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(
        title: Text(widget.isEditing ? "تعديل الصنف" : "إضافة صنف جديد"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppThemeArabic.storePrimary, Color(0xFF16A085)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.isEditing ? Icons.edit_note_rounded : Icons.add_box_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isEditing ? 'تحديث بيانات الصنف' : 'أضف صنفًا جديدًا للقائمة',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'يمكنك إدارة الاسم والفئة والصورة والسعر من شاشة واحدة.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildSectionCard(
                title: 'البيانات الأساسية',
                icon: Icons.inventory_2_outlined,
                children: [
                  TextFormField(
                    controller: _itemNameController,
                    decoration: const InputDecoration(labelText: 'اسم الصنف'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال اسم الصنف';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'فئة الصنف'),
                    items: _categoryOptions
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'الرجاء اختيار فئة من القائمة';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              _buildSectionCard(
                title: 'التسعير',
                icon: Icons.sell_outlined,
                children: [
                  TextFormField(
                    controller: _itemPriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'السعر الأساسي (اختياري عند إدخال الأحجام)',
                    ),
                    validator: (value) {
                      final small = _smallPriceController.text.trim();
                      final medium = _mediumPriceController.text.trim();
                      final large = _largePriceController.text.trim();
                      final hasAnySize =
                          small.isNotEmpty || medium.isNotEmpty || large.isNotEmpty;

                      if (!hasAnySize && (value == null || value.isEmpty)) {
                        return 'الرجاء إدخال السعر أو إدخال أسعار الأحجام';
                      }
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }
                      final parsed =
                          double.tryParse(value.trim().replaceAll(',', '.'));
                      if (parsed == null) {
                        return 'الرجاء إدخال سعر صالح';
                      }
                      if (parsed <= 0) {
                        return 'السعر يجب أن يكون أكبر من صفر';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _smallPriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'سعر الحجم الصغير'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _mediumPriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'سعر الحجم الوسط'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _largePriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'سعر الحجم الكبير'),
                  ),
                ],
              ),
              _buildSectionCard(
                title: 'الصورة والهوية البصرية',
                icon: Icons.image_outlined,
                children: [
                  _imageFile == null
                      ? (_existingImageUrl?.isNotEmpty == true
                          ? GFImageOverlay(
                              height: 170,
                              width: double.infinity,
                              image: NetworkImage(_existingImageUrl!),
                              boxFit: BoxFit.cover,
                            )
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppThemeArabic.storeBackground,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppThemeArabic.storePrimary.withOpacity(0.12)),
                              ),
                              child: const Text(
                                'لم يتم اختيار صورة بعد',
                                textAlign: TextAlign.center,
                              ),
                            ))
                      : GFImageOverlay(
                          height: 170,
                          width: double.infinity,
                          image: FileImage(_imageFile!),
                          boxFit: BoxFit.cover,
                        ),
                  const SizedBox(height: 10),
                  GFButton(
                    onPressed: _pickImage,
                    text: widget.isEditing ? 'تغيير الصورة' : 'اختيار صورة',
                    icon: const Icon(Icons.image),
                    fullWidthButton: true,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(widget.isEditing
                              ? 'جاري تعديل الصنف...'
                              : 'جاري إضافة الصنف...')
                        ],
                      ),
                    )
                  : GFButton(
                      onPressed: _submit,
                      text: widget.isEditing ? 'حفظ التعديلات' : 'إضافة الصنف',
                      color: GFColors.SUCCESS,
                      fullWidthButton: true,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
