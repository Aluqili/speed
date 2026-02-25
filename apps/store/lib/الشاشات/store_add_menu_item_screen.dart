// تمت إزالة التعريف المؤقت واستُبدل بالتنفيذ الكامل أدناه
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreAddMenuItemScreen extends StatefulWidget {
  final String restaurantId;
  const StoreAddMenuItemScreen({super.key, required this.restaurantId});

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
  String? _selectedCategory;
  File? _imageFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemPriceController.dispose();
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

  Future<void> _submit() async {
    if (_isLoading) return;
    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_imageFile == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار صورة للصنف')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final itemName = _itemNameController.text.trim();
    final rawPrice = _itemPriceController.text.trim().replaceAll(',', '.');
    final category = _selectedCategory?.trim() ?? '';

    final price = double.tryParse(rawPrice);
    if (price == null) {
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال سعر صالح')),
      );
      return;
    }
    if (price <= 0) {
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('السعر يجب أن يكون أكبر من صفر')),
      );
      return;
    }

    if (category.isEmpty) {
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم الفئة')),
      );
      return;
    }

    final categoryDocId = category.replaceAll('/', '-');

    try {
      final imageUrl = await _uploadImageToCloudinary(_imageFile!);
      if (imageUrl == null) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('فشل رفع الصورة')),
        );
        return;
      }

      final menuItemRef = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .collection('menu')
          .doc(categoryDocId)
          .collection('items')
          .doc();

      await menuItemRef.set({
        'name': itemName,
        'price': price,
        'imageUrl': imageUrl,
        'category': category,
        'available': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      String? warningMessage;
      try {
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(widget.restaurantId)
            .collection('full_menu')
            .doc(menuItemRef.id)
            .set({
          'name': itemName,
          'price': price,
          'imageUrl': imageUrl,
          'category': category,
          'available': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } on FirebaseException catch (e) {
        warningMessage = e.code == 'permission-denied'
            ? 'تمت إضافة الصنف لكن تعذرت مزامنته في القائمة الكاملة بسبب الصلاحيات.'
            : 'تمت إضافة الصنف لكن تعذرت مزامنته في القائمة الكاملة.';
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _itemNameController.clear();
        _itemPriceController.clear();
        _selectedCategory = null;
        _imageFile = null;
      });

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تمت الإضافة'),
          content: Text(
            warningMessage ?? 'تمت إضافة الصنف بنجاح ✅',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = e.code == 'permission-denied'
          ? 'لا تملك صلاحية إضافة صنف. تأكد أن المتجر معتمد وحسابك يطابق صاحب المتجر.'
          : 'تعذر إضافة الصنف: ${e.message ?? e.code}';
      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(content: Text('تعذر إضافة الصنف: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(
        title: const Text("إضافة صنف جديد"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
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
              TextFormField(
                controller: _itemPriceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'السعر بالجنيه'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال السعر';
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
              const SizedBox(height: 16),
              _imageFile == null
                  ? const Text('لم يتم اختيار صورة بعد')
                  : GFImageOverlay(
                      height: 150,
                      width: double.infinity,
                      image: FileImage(_imageFile!),
                      boxFit: BoxFit.cover,
                    ),
              const SizedBox(height: 8),
              GFButton(
                onPressed: _pickImage,
                text: 'اختيار صورة',
                icon: const Icon(Icons.image),
                fullWidthButton: true,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('جاري إضافة الصنف...')
                        ],
                      ),
                    )
                  : GFButton(
                      onPressed: _submit,
                      text: 'إضافة الصنف',
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
