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
  State<StoreAddMenuItemScreen> createState() =>
      _StoreAddMenuItemScreenState();
}

class _StoreAddMenuItemScreenState
    extends State<StoreAddMenuItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemPriceController = TextEditingController();
  final TextEditingController _itemCategoryController = TextEditingController(); // حقل لإدخال الفئة
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final pickedImage =
        await ImagePicker().pickImage(source: ImageSource.gallery);
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
    if (!_formKey.currentState!.validate() || _imageFile == null) return;

    setState(() => _isLoading = true);

    double? price = double.tryParse(_itemPriceController.text.trim());
    if (price == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال سعر صالح')),
      );
      return;
    }

    final String category = _itemCategoryController.text.trim(); // الحصول على قيمة الفئة
    if (category.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم الفئة')),
      );
      return;
    }

    final imageUrl = await _uploadImageToCloudinary(_imageFile!);
    if (imageUrl == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل رفع الصورة')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .collection('menu')
        .doc(category) // استخدام اسم الفئة كمستند (يمكنك تعديل هذا الهيكل إذا أردت)
        .collection('items')
        .add({
      'name': _itemNameController.text.trim(),
      'price': price,
      'imageUrl': imageUrl,
      'category': category, // حفظ الفئة هنا
      'createdAt': FieldValue.serverTimestamp(),
    });

    // أضف أيضاً إلى القائمة الكاملة full_menu ليظهر في شاشة التفاصيل
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .collection('full_menu')
        .add({
      'name': _itemNameController.text.trim(),
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'available': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _isLoading = false;
      _itemNameController.clear();
      _itemPriceController.clear();
      _itemCategoryController.clear(); // مسح حقل الفئة
      _imageFile = null;
    });

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تمت الإضافة'),
        content: const Text('تمت إضافة الصنف بنجاح ✅'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
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
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'السعر بالجنيه'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال السعر';
                  }
                  if (double.tryParse(value) == null) {
                    return 'الرجاء إدخال سعر صالح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField( // حقل إدخال الفئة
                controller: _itemCategoryController,
                decoration: const InputDecoration(labelText: 'اسم الفئة'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال اسم الفئة';
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
                  ? const Center(child: CircularProgressIndicator())
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